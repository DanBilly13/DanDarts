-- DanDarts Database Migration 095
-- Purpose: Clubs (part 3 of 6): row level security. Clients may only read clubs they belong to;
--          every write and every non-member read goes through the RPCs in 096 and 097.
-- Spec:    docs/superpowers/specs/2026-11-01-clubs-design.md
-- Safety:  Only touches the new club tables. Safe to re-run.

BEGIN;

-- Supabase grants table privileges to anon and authenticated by default. Remove them, then
-- grant back only what the client really needs.
REVOKE ALL ON public.clubs FROM anon, authenticated;
REVOKE ALL ON public.club_members FROM anon, authenticated;
REVOKE ALL ON public.club_suggestion_dismissals FROM anon, authenticated;
REVOKE ALL ON public.reports FROM anon, authenticated;
REVOKE ALL ON public.blocked_words FROM anon, authenticated;

GRANT SELECT ON public.clubs TO authenticated;
GRANT SELECT ON public.club_members TO authenticated;
GRANT SELECT, DELETE ON public.club_suggestion_dismissals TO authenticated;
GRANT INSERT ON public.reports TO authenticated;

ALTER TABLE public.clubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.club_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.club_suggestion_dismissals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_words ENABLE ROW LEVEL SECURITY;

-- Membership check used by the policies. SECURITY DEFINER so it can read club_members without
-- the policy on club_members calling itself.
CREATE OR REPLACE FUNCTION public.is_club_member(p_club_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.club_members m
    WHERE m.club_id = p_club_id AND m.user_id = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION public.is_club_member(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_club_member(UUID) TO authenticated;

DROP POLICY IF EXISTS "Members can read their clubs" ON public.clubs;
CREATE POLICY "Members can read their clubs"
  ON public.clubs
  FOR SELECT
  TO authenticated
  USING (public.is_club_member(id));

DROP POLICY IF EXISTS "Members can read fellow members" ON public.club_members;
CREATE POLICY "Members can read fellow members"
  ON public.club_members
  FOR SELECT
  TO authenticated
  USING (public.is_club_member(club_id));

DROP POLICY IF EXISTS "Users can read their dismissals" ON public.club_suggestion_dismissals;
CREATE POLICY "Users can read their dismissals"
  ON public.club_suggestion_dismissals
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can undo their dismissals" ON public.club_suggestion_dismissals;
CREATE POLICY "Users can undo their dismissals"
  ON public.club_suggestion_dismissals
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can file reports" ON public.reports;
CREATE POLICY "Users can file reports"
  ON public.reports
  FOR INSERT
  TO authenticated
  WITH CHECK (reporter_id = auth.uid());

-- blocked_words: RLS on and no policies, so clients cannot read or change it.

DO $$
BEGIN
  RAISE NOTICE 'Migration 095 complete: clubs RLS and grants';
END $$;

COMMIT;
