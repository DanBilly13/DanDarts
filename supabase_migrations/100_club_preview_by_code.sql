-- DanDarts Database Migration 100
-- Purpose: Clubs: look a club up by its join code, so the app can say "Join The Crown, Leeds?"
--          before someone joins from a link or a typed code.
-- Spec:    docs/superpowers/specs/2026-11-01-clubs-design.md (Links)
-- Safety:  Additive only. One new function. Safe to re-run (CREATE OR REPLACE).
-- Notes:   Works for Open and Invite-only clubs, because holding the code is what lets someone
--          join (join_club_by_code needs nothing more). It returns only the name, town, the
--          member count and whether the caller is already in. Never the member list or avatars.
--          Same conventions as 096: SECURITY DEFINER, SET search_path = public,
--          REVOKE ALL FROM PUBLIC, anon; GRANT EXECUTE TO authenticated.
--          An unknown code returns no rows. Code format matches join_club_by_code: spaces,
--          dashes and case are ignored.

BEGIN;

CREATE OR REPLACE FUNCTION public.preview_club_by_code(p_code TEXT)
RETURNS TABLE (
  club_id UUID,
  name TEXT,
  town TEXT,
  visibility TEXT,
  member_count INTEGER,
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
  v_code TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;

  v_code := regexp_replace(upper(coalesce(p_code, '')), '[^A-Z0-9]', '', 'g');

  RETURN QUERY
  SELECT
    c.id,
    c.name,
    c.town,
    c.visibility,
    c.member_count,
    EXISTS (SELECT 1 FROM public.club_members m WHERE m.club_id = c.id AND m.user_id = v_uid)
  FROM public.clubs c
  WHERE c.join_code = v_code;
END;
$$;

REVOKE ALL ON FUNCTION public.preview_club_by_code(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.preview_club_by_code(TEXT) TO authenticated;

DO $$
BEGIN
  RAISE NOTICE 'Migration 100 complete: preview_club_by_code';
END $$;

COMMIT;
