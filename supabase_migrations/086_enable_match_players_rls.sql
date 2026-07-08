-- =====================================================
-- DanDarts Database Migration 086
-- Enable RLS on match_players (participant read, scoped writes) + hardened
-- completion trigger + backfill
-- =====================================================
-- Date: 2026-07-08
--
-- Background:
--   match_players previously had RLS DISABLED (migrations 039/081) because the
--   old creator/JSONB-based policies were broken and blocked legitimate writes.
--   This migration re-enables RLS with a correct, recursion-safe policy set and
--   ensures server-authoritative completion writes bypass RLS.
--
-- What this migration does:
--   1. Adds matches.created_by (nullable, default auth.uid()) as a local-match
--      ownership anchor. NOT backfilled and NOT NOT-NULL on purpose:
--        - Migrations run without a JWT, so a backfill would set NULL and a
--          NOT NULL constraint would then fail.
--        - Remote matches are created server-side; forcing NOT NULL would break
--          those inserts.
--   2. Adds is_match_participant(uuid) as a SECURITY DEFINER helper (owner
--      postgres, row_security=off) so the SELECT policy can check membership by
--      reading match_players without recursing into its own RLS.
--   3. Enables RLS on match_players and installs:
--        - SELECT: any participant of the match (is_match_participant)
--        - INSERT: match creator (local bulk insert incl. guest NULL rows) OR a
--                  participant inserting their OWN row (remote self-join via
--                  enter-lobby / join-match)
--        - DELETE: match creator only (local re-save delete-by-match_id)
--   4. Hardens create_match_players_on_completion() (SECURITY DEFINER,
--      row_security=off, owner postgres) and (re)attaches the completion trigger
--      so remote completion writes both participant rows regardless of who
--      completes the match.
--   5. One-time backfill of match_players for already-completed remote matches
--      that predate the trigger/policies.
--
-- Notes:
--   - Remote writes are authorized via challenger_id/receiver_id, NOT created_by,
--     because remote matches may have a NULL/other created_by.
--   - This file reflects the final live state applied via the Supabase SQL editor
--     on 2026-07-08.
-- =====================================================

BEGIN;

-- -----------------------------------------------------
-- 1) Ownership anchor for local matches (nullable + default; no backfill)
-- -----------------------------------------------------
ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS created_by uuid DEFAULT auth.uid();

-- -----------------------------------------------------
-- 2) Recursion-safe participant check (SECURITY DEFINER, bypasses RLS)
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_match_participant(_match_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.match_players
    WHERE match_id = _match_id AND player_user_id = auth.uid()
  );
$$;
ALTER FUNCTION public.is_match_participant(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.is_match_participant(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.is_match_participant(uuid) TO authenticated;

-- -----------------------------------------------------
-- 3) Enable RLS + policies on match_players
-- -----------------------------------------------------
-- Drop any historical/leftover policy names first (idempotent).
DROP POLICY IF EXISTS "Users can view match_players for their matches" ON public.match_players;
DROP POLICY IF EXISTS match_players_select_participant ON public.match_players;
DROP POLICY IF EXISTS match_players_select_participants ON public.match_players;   -- from 067
DROP POLICY IF EXISTS "Authenticated users can insert match_players" ON public.match_players;  -- from 071
DROP POLICY IF EXISTS match_players_select ON public.match_players;
DROP POLICY IF EXISTS match_players_insert ON public.match_players;
DROP POLICY IF EXISTS match_players_delete ON public.match_players;

ALTER TABLE public.match_players ENABLE ROW LEVEL SECURITY;

-- SELECT: any participant of the match may read all of its rows.
CREATE POLICY match_players_select ON public.match_players
  FOR SELECT TO authenticated
  USING (public.is_match_participant(match_id));

-- INSERT: match creator (local, incl. guest NULL rows) OR participant self-insert (remote).
CREATE POLICY match_players_insert ON public.match_players
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.matches m
      WHERE m.id = match_players.match_id
        AND (
          m.created_by = auth.uid()
          OR (
            match_players.player_user_id = auth.uid()
            AND (m.challenger_id = auth.uid() OR m.receiver_id = auth.uid())
          )
        )
    )
  );

-- DELETE: match creator only (covers local re-save bulk delete by match_id).
CREATE POLICY match_players_delete ON public.match_players
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.matches m
      WHERE m.id = match_players.match_id AND m.created_by = auth.uid()
    )
  );

-- -----------------------------------------------------
-- 4) Harden completion trigger so remote writes bypass RLS, and (re)attach it
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_match_players_on_completion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  IF NEW.remote_status = 'completed'
     AND (OLD.remote_status IS NULL OR OLD.remote_status <> 'completed') THEN
    INSERT INTO public.match_players (match_id, player_user_id, player_order)
    VALUES (NEW.id, NEW.challenger_id, 0), (NEW.id, NEW.receiver_id, 1)
    ON CONFLICT (match_id, player_order) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;
ALTER FUNCTION public.create_match_players_on_completion() OWNER TO postgres;

DROP TRIGGER IF EXISTS match_completion_create_players ON public.matches;
CREATE TRIGGER match_completion_create_players
  AFTER UPDATE ON public.matches
  FOR EACH ROW
  EXECUTE FUNCTION public.create_match_players_on_completion();

-- -----------------------------------------------------
-- 5) One-time backfill for completed remote matches missing player rows
-- -----------------------------------------------------
INSERT INTO public.match_players (match_id, player_user_id, player_order)
SELECT m.id, m.challenger_id, 0
FROM public.matches m
WHERE m.match_mode = 'remote'
  AND m.remote_status = 'completed'
  AND m.challenger_id IS NOT NULL
ON CONFLICT (match_id, player_order) DO NOTHING;

INSERT INTO public.match_players (match_id, player_user_id, player_order)
SELECT m.id, m.receiver_id, 1
FROM public.matches m
WHERE m.match_mode = 'remote'
  AND m.remote_status = 'completed'
  AND m.receiver_id IS NOT NULL
ON CONFLICT (match_id, player_order) DO NOTHING;

COMMIT;

-- =====================================================
-- ROLLBACK (restores prior state: RLS disabled on match_players,
-- trigger back to SECURITY INVOKER form). created_by column is left in place
-- (harmless). Run manually if needed.
-- =====================================================
/*
BEGIN;

DROP POLICY IF EXISTS match_players_select ON public.match_players;
DROP POLICY IF EXISTS match_players_insert ON public.match_players;
DROP POLICY IF EXISTS match_players_delete ON public.match_players;
ALTER TABLE public.match_players DISABLE ROW LEVEL SECURITY;

DROP FUNCTION IF EXISTS public.is_match_participant(uuid);

-- Restore original (pre-086) trigger function form.
CREATE OR REPLACE FUNCTION public.create_match_players_on_completion()
RETURNS trigger AS $$
BEGIN
  IF NEW.remote_status = 'completed'
     AND (OLD.remote_status IS NULL OR OLD.remote_status <> 'completed') THEN
    INSERT INTO match_players (match_id, player_user_id, player_order)
    VALUES (NEW.id, NEW.challenger_id, 0), (NEW.id, NEW.receiver_id, 1)
    ON CONFLICT (match_id, player_order) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT;
*/
