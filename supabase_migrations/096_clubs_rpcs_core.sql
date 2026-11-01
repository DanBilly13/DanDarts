-- DanDarts Database Migration 096
-- Purpose: Clubs (part 4 of 6): the core RPCs: create, search, preview, join (by id or code),
--          leave, and the caller's own club list.
-- Spec:    docs/superpowers/specs/2026-11-01-clubs-design.md
-- Safety:  Additive only. New functions. Safe to re-run (CREATE OR REPLACE).
-- Notes:   Same conventions as claim_invite (041): SECURITY DEFINER, SET search_path = public,
--          REVOKE ALL FROM PUBLIC, GRANT EXECUTE TO authenticated. Functions that change data
--          return a result code instead of raising, so the apps can show a clear message:
--            ok, not_authenticated, invalid_name, invalid_town, invalid_visibility,
--            name_not_allowed, duplicate, club_limit, not_found, already_member, invalid_code,
--            try_again (a join-code collision that survived three retries; practically never).
--          '#variable_conflict use_column' stops output column names (club_id, name, ...) from
--          clashing with table columns inside the function bodies.

BEGIN;

CREATE OR REPLACE FUNCTION public.create_club(
  p_name TEXT,
  p_town TEXT DEFAULT NULL,
  p_visibility TEXT DEFAULT 'open'
)
RETURNS TABLE (result TEXT, club_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_uid UUID := auth.uid();
  v_name TEXT;
  v_town TEXT;
  v_name_key TEXT;
  v_town_key TEXT;
  v_existing UUID;
  v_new UUID;
  v_attempt INTEGER;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT 'not_authenticated'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  IF coalesce(p_visibility, '') NOT IN ('open', 'invite') THEN
    RETURN QUERY SELECT 'invalid_visibility'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  v_name := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
  v_town := nullif(btrim(regexp_replace(coalesce(p_town, ''), '\s+', ' ', 'g')), '');
  v_name_key := public.club_normalize(v_name);
  v_town_key := nullif(public.club_normalize(v_town), '');

  IF char_length(v_name) < 3 OR char_length(v_name) > 40 OR char_length(v_name_key) < 3 THEN
    RETURN QUERY SELECT 'invalid_name'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  IF v_town IS NOT NULL AND char_length(v_town) > 40 THEN
    RETURN QUERY SELECT 'invalid_town'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  -- Whole-word match against the owner's list, so "Glasshouse" is not caught by "ass".
  IF EXISTS (
    SELECT 1 FROM public.blocked_words w
    WHERE position(' ' || w.word || ' ' IN ' ' || v_name_key || ' ') > 0
       OR (v_town_key IS NOT NULL AND position(' ' || w.word || ' ' IN ' ' || v_town_key || ' ') > 0)
  ) THEN
    RETURN QUERY SELECT 'name_not_allowed'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  IF (SELECT count(*) FROM public.club_members m WHERE m.user_id = v_uid) >= 5 THEN
    RETURN QUERY SELECT 'club_limit'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  IF p_visibility = 'open' THEN
    SELECT c.id INTO v_existing
    FROM public.clubs c
    WHERE c.visibility = 'open'
      AND c.name_key = v_name_key
      AND coalesce(c.town_key, '') = coalesce(v_town_key, '');
    IF FOUND THEN
      RETURN QUERY SELECT 'duplicate'::TEXT, v_existing;
      RETURN;
    END IF;
  END IF;

  -- A unique violation is either a racing duplicate of an Open club or (very rarely) the same
  -- random join code picked twice; tell them apart and retry with a fresh code in the second case.
  FOR v_attempt IN 1..3 LOOP
    BEGIN
      INSERT INTO public.clubs (name, name_key, town, town_key, visibility, join_code, created_by)
      VALUES (v_name, v_name_key, v_town, v_town_key, p_visibility, public.generate_club_code(), v_uid)
      RETURNING id INTO v_new;
      EXIT;
    EXCEPTION
      WHEN unique_violation THEN
        v_new := NULL;
        IF p_visibility = 'open' THEN
          SELECT c.id INTO v_existing
          FROM public.clubs c
          WHERE c.visibility = 'open'
            AND c.name_key = v_name_key
            AND coalesce(c.town_key, '') = coalesce(v_town_key, '');
          IF FOUND THEN
            RETURN QUERY SELECT 'duplicate'::TEXT, v_existing;
            RETURN;
          END IF;
        END IF;
    END;
  END LOOP;

  IF v_new IS NULL THEN
    RETURN QUERY SELECT 'try_again'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  INSERT INTO public.club_members (club_id, user_id, role) VALUES (v_new, v_uid, 'admin');

  RETURN QUERY SELECT 'ok'::TEXT, v_new;
END;
$$;

-- Open clubs only. Name or town contains the search text (2+ characters). Up to three avatars
-- of members who have not switched off "let club members find me".
CREATE OR REPLACE FUNCTION public.search_clubs(p_query TEXT)
RETURNS TABLE (
  club_id UUID,
  name TEXT,
  town TEXT,
  member_count INTEGER,
  avatars TEXT[],
  is_member BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_uid UUID := auth.uid();
  v_q TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;

  v_q := public.club_normalize(p_query);
  IF char_length(v_q) < 2 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.name,
    c.town,
    c.member_count,
    coalesce((
      SELECT array_agg(a.avatar_url)
      FROM (
        SELECT u.avatar_url
        FROM public.club_members m
        JOIN public.users u ON u.id = m.user_id
        WHERE m.club_id = c.id AND u.club_discoverable AND u.avatar_url IS NOT NULL
        ORDER BY m.joined_at, m.user_id
        LIMIT 3
      ) a
    ), ARRAY[]::TEXT[]),
    EXISTS (SELECT 1 FROM public.club_members mm WHERE mm.club_id = c.id AND mm.user_id = v_uid)
  FROM public.clubs c
  WHERE c.visibility = 'open'
    AND (c.name_key LIKE '%' || v_q || '%' OR coalesce(c.town_key, '') LIKE '%' || v_q || '%')
  ORDER BY c.member_count DESC, c.name
  LIMIT 20;
END;
$$;

-- What a non-member may see of an Open club, or what a member sees of their own club.
-- Invite-only clubs return nothing to non-members.
CREATE OR REPLACE FUNCTION public.get_club_preview(p_club_id UUID)
RETURNS TABLE (
  club_id UUID,
  name TEXT,
  town TEXT,
  visibility TEXT,
  member_count INTEGER,
  avatars TEXT[],
  is_member BOOLEAN
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
  IF v_uid IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.name,
    c.town,
    c.visibility,
    c.member_count,
    coalesce((
      SELECT array_agg(a.avatar_url)
      FROM (
        SELECT u.avatar_url
        FROM public.club_members m
        JOIN public.users u ON u.id = m.user_id
        WHERE m.club_id = c.id AND u.club_discoverable AND u.avatar_url IS NOT NULL
        ORDER BY m.joined_at, m.user_id
        LIMIT 3
      ) a
    ), ARRAY[]::TEXT[]),
    EXISTS (SELECT 1 FROM public.club_members mm WHERE mm.club_id = c.id AND mm.user_id = v_uid)
  FROM public.clubs c
  WHERE c.id = p_club_id
    AND (
      c.visibility = 'open'
      OR EXISTS (SELECT 1 FROM public.club_members mm WHERE mm.club_id = c.id AND mm.user_id = v_uid)
    );
END;
$$;

-- One-tap join for Open clubs.
CREATE OR REPLACE FUNCTION public.join_club(p_club_id UUID)
RETURNS TABLE (result TEXT, club_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_uid UUID := auth.uid();
  v_visibility TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT 'not_authenticated'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  SELECT c.visibility INTO v_visibility FROM public.clubs c WHERE c.id = p_club_id;
  IF NOT FOUND OR v_visibility <> 'open' THEN
    RETURN QUERY SELECT 'not_found'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM public.club_members m WHERE m.club_id = p_club_id AND m.user_id = v_uid) THEN
    RETURN QUERY SELECT 'already_member'::TEXT, p_club_id;
    RETURN;
  END IF;

  IF (SELECT count(*) FROM public.club_members m WHERE m.user_id = v_uid) >= 5 THEN
    RETURN QUERY SELECT 'club_limit'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  BEGIN
    INSERT INTO public.club_members (club_id, user_id, role) VALUES (p_club_id, v_uid, 'member');
  EXCEPTION
    WHEN unique_violation THEN
      RETURN QUERY SELECT 'already_member'::TEXT, p_club_id;
      RETURN;
    WHEN raise_exception THEN
      RETURN QUERY SELECT 'club_limit'::TEXT, NULL::UUID;
      RETURN;
  END;

  RETURN QUERY SELECT 'ok'::TEXT, p_club_id;
END;
$$;

-- Join any club, Open or Invite-only, with its code. Spaces and dashes in the code are ignored.
CREATE OR REPLACE FUNCTION public.join_club_by_code(p_code TEXT)
RETURNS TABLE (result TEXT, club_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_uid UUID := auth.uid();
  v_code TEXT;
  v_club UUID;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT 'not_authenticated'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  v_code := regexp_replace(upper(coalesce(p_code, '')), '[^A-Z0-9]', '', 'g');
  SELECT c.id INTO v_club FROM public.clubs c WHERE c.join_code = v_code;
  IF NOT FOUND THEN
    RETURN QUERY SELECT 'invalid_code'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM public.club_members m WHERE m.club_id = v_club AND m.user_id = v_uid) THEN
    RETURN QUERY SELECT 'already_member'::TEXT, v_club;
    RETURN;
  END IF;

  IF (SELECT count(*) FROM public.club_members m WHERE m.user_id = v_uid) >= 5 THEN
    RETURN QUERY SELECT 'club_limit'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  BEGIN
    INSERT INTO public.club_members (club_id, user_id, role) VALUES (v_club, v_uid, 'member');
  EXCEPTION
    WHEN unique_violation THEN
      RETURN QUERY SELECT 'already_member'::TEXT, v_club;
      RETURN;
    WHEN raise_exception THEN
      RETURN QUERY SELECT 'club_limit'::TEXT, NULL::UUID;
      RETURN;
  END;

  RETURN QUERY SELECT 'ok'::TEXT, v_club;
END;
$$;

-- The triggers from 094 hand the club to the next member or delete it when empty.
CREATE OR REPLACE FUNCTION public.leave_club(p_club_id UUID)
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

  DELETE FROM public.club_members m WHERE m.club_id = p_club_id AND m.user_id = v_uid;
  IF NOT FOUND THEN
    RETURN 'not_found';
  END IF;

  RETURN 'ok';
END;
$$;

-- The caller's own clubs, with their role and the join code (members can already read both
-- through RLS; this saves a join in the apps).
CREATE OR REPLACE FUNCTION public.my_clubs()
RETURNS TABLE (
  club_id UUID,
  name TEXT,
  town TEXT,
  visibility TEXT,
  member_count INTEGER,
  join_code TEXT,
  role TEXT,
  joined_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT c.id, c.name, c.town, c.visibility, c.member_count, c.join_code, m.role, m.joined_at
  FROM public.club_members m
  JOIN public.clubs c ON c.id = m.club_id
  WHERE m.user_id = auth.uid()
  ORDER BY m.joined_at, c.name;
END;
$$;

REVOKE ALL ON FUNCTION public.create_club(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.search_clubs(TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_club_preview(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.join_club(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.join_club_by_code(TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.leave_club(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.my_clubs() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_club(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_clubs(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_club_preview(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_club(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_club_by_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_club(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_clubs() TO authenticated;

DO $$
BEGIN
  RAISE NOTICE 'Migration 096 complete: core club RPCs';
END $$;

COMMIT;
