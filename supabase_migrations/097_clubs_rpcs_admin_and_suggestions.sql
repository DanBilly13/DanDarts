-- DanDarts Database Migration 097
-- Purpose: Clubs (part 5 of 6): admin actions, member list, friend suggestions, dismissals, reports.
-- Spec:    docs/superpowers/specs/2026-11-01-clubs-design.md
-- Safety:  Additive only. New functions. Safe to re-run (CREATE OR REPLACE).
-- Notes:   Result codes: ok, not_authenticated, not_admin, not_found, not_member, duplicate,
--          invalid_visibility, invalid_type, use_leave.
--          Friendship states in club_members_list: self, friend, request_sent, request_received,
--          blocked, none. A request that was rejected shows as request_sent to the requester
--          (the unique index on friendships would reject a second request anyway).

BEGIN;

CREATE OR REPLACE FUNCTION public.is_club_admin(p_club_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.club_members m
    WHERE m.club_id = p_club_id AND m.user_id = auth.uid() AND m.role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.set_club_visibility(p_club_id UUID, p_visibility TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_name_key TEXT;
  v_town_key TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN 'not_authenticated';
  END IF;
  IF coalesce(p_visibility, '') NOT IN ('open', 'invite') THEN
    RETURN 'invalid_visibility';
  END IF;
  IF NOT public.is_club_admin(p_club_id) THEN
    RETURN 'not_admin';
  END IF;

  IF p_visibility = 'open' THEN
    SELECT c.name_key, c.town_key INTO v_name_key, v_town_key FROM public.clubs c WHERE c.id = p_club_id;
    IF EXISTS (
      SELECT 1 FROM public.clubs o
      WHERE o.visibility = 'open'
        AND o.id <> p_club_id
        AND o.name_key = v_name_key
        AND coalesce(o.town_key, '') = coalesce(v_town_key, '')
    ) THEN
      RETURN 'duplicate';
    END IF;
  END IF;

  BEGIN
    UPDATE public.clubs c SET visibility = p_visibility WHERE c.id = p_club_id;
  EXCEPTION
    WHEN unique_violation THEN
      RETURN 'duplicate';
  END;

  RETURN 'ok';
END;
$$;

-- The old code stops working immediately.
CREATE OR REPLACE FUNCTION public.regenerate_club_code(p_club_id UUID)
RETURNS TABLE (result TEXT, join_code TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_uid UUID := auth.uid();
  v_new TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT 'not_authenticated'::TEXT, NULL::TEXT;
    RETURN;
  END IF;
  IF NOT public.is_club_admin(p_club_id) THEN
    RETURN QUERY SELECT 'not_admin'::TEXT, NULL::TEXT;
    RETURN;
  END IF;

  UPDATE public.clubs c SET join_code = public.generate_club_code()
  WHERE c.id = p_club_id
  RETURNING c.join_code INTO v_new;

  RETURN QUERY SELECT 'ok'::TEXT, v_new;
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_club_member(p_club_id UUID, p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN 'not_authenticated';
  END IF;
  IF NOT public.is_club_admin(p_club_id) THEN
    RETURN 'not_admin';
  END IF;
  IF p_user_id = v_uid THEN
    RETURN 'use_leave';
  END IF;

  DELETE FROM public.club_members m WHERE m.club_id = p_club_id AND m.user_id = p_user_id;
  IF NOT FOUND THEN
    RETURN 'not_member';
  END IF;

  RETURN 'ok';
END;
$$;

-- Members only. Each row carries the caller's friendship state with that person, so the apps can
-- show Add, Request sent or Friend without a second query.
CREATE OR REPLACE FUNCTION public.club_members_list(p_club_id UUID)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  nickname TEXT,
  avatar_url TEXT,
  role TEXT,
  joined_at TIMESTAMPTZ,
  relationship TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL OR NOT public.is_club_member(p_club_id) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    u.display_name,
    u.nickname,
    u.avatar_url,
    m.role,
    m.joined_at,
    CASE
      WHEN u.id = v_uid THEN 'self'
      WHEN f.status = 'accepted' THEN 'friend'
      WHEN f.status = 'blocked' THEN 'blocked'
      WHEN f.status = 'pending' AND f.requester_id = v_uid THEN 'request_sent'
      WHEN f.status = 'pending' THEN 'request_received'
      WHEN f.status = 'rejected' AND f.requester_id = v_uid THEN 'request_sent'
      ELSE 'none'
    END
  FROM public.club_members m
  JOIN public.users u ON u.id = m.user_id
  LEFT JOIN LATERAL (
    SELECT ff.status, ff.requester_id
    FROM public.friendships ff
    WHERE (ff.requester_id = v_uid AND ff.addressee_id = u.id)
       OR (ff.requester_id = u.id AND ff.addressee_id = v_uid)
    ORDER BY ff.created_at DESC
    LIMIT 1
  ) f ON TRUE
  WHERE m.club_id = p_club_id
  ORDER BY (m.role = 'admin') DESC, m.joined_at, u.display_name;
END;
$$;

-- People who share at least one club with the caller. Left out: the caller, anyone the caller has
-- any friendship row with (accepted, pending, rejected or blocked, either direction), anyone who
-- switched off "let club members find me", and anyone the caller dismissed.
CREATE OR REPLACE FUNCTION public.club_suggestions(p_limit INTEGER DEFAULT 20)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  nickname TEXT,
  avatar_url TEXT,
  club_name TEXT,
  shared_count INTEGER
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_uid UUID := auth.uid();
  v_limit INTEGER := least(greatest(coalesce(p_limit, 20), 1), 50);
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    u.display_name,
    u.nickname,
    u.avatar_url,
    sc.name,
    s.shared::INTEGER
  FROM (
    SELECT m.user_id, count(*) AS shared, max(m.joined_at) AS last_join
    FROM public.club_members m
    WHERE m.club_id IN (SELECT mine.club_id FROM public.club_members mine WHERE mine.user_id = v_uid)
      AND m.user_id <> v_uid
    GROUP BY m.user_id
  ) s
  JOIN public.users u ON u.id = s.user_id
  LEFT JOIN LATERAL (
    SELECT c.name
    FROM public.club_members theirs
    JOIN public.club_members mine ON mine.club_id = theirs.club_id AND mine.user_id = v_uid
    JOIN public.clubs c ON c.id = theirs.club_id
    WHERE theirs.user_id = u.id
    ORDER BY mine.joined_at, c.name
    LIMIT 1
  ) sc ON TRUE
  WHERE u.club_discoverable
    AND NOT EXISTS (
      SELECT 1 FROM public.friendships f
      WHERE (f.requester_id = v_uid AND f.addressee_id = u.id)
         OR (f.requester_id = u.id AND f.addressee_id = v_uid)
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.club_suggestion_dismissals d
      WHERE d.user_id = v_uid AND d.suggested_user_id = u.id
    )
  ORDER BY s.shared DESC, s.last_join DESC, u.display_name
  LIMIT v_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.dismiss_club_suggestion(p_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN 'not_authenticated';
  END IF;
  IF p_user_id IS NULL OR p_user_id = v_uid THEN
    RETURN 'not_found';
  END IF;

  INSERT INTO public.club_suggestion_dismissals (user_id, suggested_user_id)
  VALUES (v_uid, p_user_id)
  ON CONFLICT DO NOTHING;

  RETURN 'ok';
END;
$$;

CREATE OR REPLACE FUNCTION public.report_content(p_target_type TEXT, p_target_id UUID, p_reason TEXT DEFAULT NULL)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_reason TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN 'not_authenticated';
  END IF;
  IF coalesce(p_target_type, '') NOT IN ('club', 'user') THEN
    RETURN 'invalid_type';
  END IF;

  IF p_target_type = 'club' AND NOT EXISTS (SELECT 1 FROM public.clubs c WHERE c.id = p_target_id) THEN
    RETURN 'not_found';
  END IF;
  IF p_target_type = 'user' AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = p_target_id) THEN
    RETURN 'not_found';
  END IF;

  v_reason := nullif(left(btrim(coalesce(p_reason, '')), 500), '');

  INSERT INTO public.reports (reporter_id, target_type, target_id, reason)
  VALUES (v_uid, p_target_type, p_target_id, v_reason);

  RETURN 'ok';
END;
$$;

REVOKE ALL ON FUNCTION public.is_club_admin(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_club_visibility(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.regenerate_club_code(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.remove_club_member(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.club_members_list(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.club_suggestions(INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.dismiss_club_suggestion(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.report_content(TEXT, UUID, TEXT) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.is_club_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_club_visibility(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.regenerate_club_code(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_club_member(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_members_list(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_suggestions(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dismiss_club_suggestion(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.report_content(TEXT, UUID, TEXT) TO authenticated;

DO $$
BEGIN
  RAISE NOTICE 'Migration 097 complete: club admin RPCs, member list, suggestions, dismissals, reports';
END $$;

COMMIT;
