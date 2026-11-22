-- DanDarts Database Migration 103
-- Purpose: Clubs: show each member's 301/501 rank on the club page, and give the club a rank of
--          its own (the average of its ranked members, worked out in the app).
-- Safety:  Replaces club_members_list with the same columns plus two at the end (DROP + CREATE,
--          because the returned columns change; older app builds ignore the extra columns).
--          The rank numbers are already public on every profile. Safe to re-run.
-- Apply:   Supabase SQL editor, after 102. First run it with the final COMMIT changed to
--          ROLLBACK to prove it applies, then run it again with COMMIT.

BEGIN;

DROP FUNCTION IF EXISTS public.club_members_list(UUID);
CREATE FUNCTION public.club_members_list(p_club_id UUID)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  nickname TEXT,
  avatar_url TEXT,
  role TEXT,
  joined_at TIMESTAMPTZ,
  relationship TEXT,
  ranked_wins_count INTEGER,
  ranked_tier_score_total INTEGER
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
    END,
    coalesce(u.ranked_wins_count_301_501, 0),
    coalesce(u.ranked_tier_score_total_301_501, 0)
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

REVOKE ALL ON FUNCTION public.club_members_list(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.club_members_list(UUID) TO authenticated;

DO $$
BEGIN
  RAISE NOTICE 'Migration 103 complete: club_members_list returns each member''s rank';
END $$;

COMMIT;
