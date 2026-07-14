-- =====================================================
-- DanDarts Database Migration 089
-- Anonymize match_players participation when a user is deleted
-- =====================================================
-- Date: 2026-07-14
--
-- Problem:
--   match_players has CHECK constraint match_players_user_or_guest requiring EXACTLY
--   one of (player_user_id, guest_name) to be non-null:
--       (player_user_id IS NOT NULL AND guest_name IS NULL)
--    OR (player_user_id IS NULL AND guest_name IS NOT NULL)
--   The FK match_players_player_user_id_fkey is ON DELETE SET NULL, so deleting a user
--   nulls player_user_id while guest_name stays NULL -> BOTH null -> CHECK violation ->
--   the whole DELETE FROM auth.users (and admin.deleteUser) fails with a 500.
--   This blocks account deletion for any user with match_players rows (local OR remote).
--
-- Fix:
--   A BEFORE DELETE trigger on public.users rewrites the departing user's match_players
--   rows to an anonymized GUEST row named 'Deleted User' in a single UPDATE (sets
--   player_user_id = NULL and guest_name together), which satisfies the XOR constraint.
--   Because it runs BEFORE the row is deleted, the FK SET NULL action afterwards finds
--   no matching rows. Keeps the constraint strict and needs no edge-function change.
--
-- Safety:
--   - Idempotent (CREATE OR REPLACE + DROP TRIGGER IF EXISTS).
--   - SECURITY DEFINER (owner postgres) so it can update match_players regardless of RLS,
--     consistent with the app's other maintenance functions (see migration 086).
--   - Preserves opponents' rows; only rows belonging to the deleted user are touched.
-- =====================================================

BEGIN;

DO $$
BEGIN
    RAISE NOTICE '=== MIGRATION 089: Anonymize match_players on user delete ===';
END $$;

CREATE OR REPLACE FUNCTION public.anonymize_match_players_on_user_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.match_players
    SET guest_name     = COALESCE(guest_name, 'Deleted User'),
        player_user_id = NULL
    WHERE player_user_id = OLD.id;
    RETURN OLD;
END;
$$;

ALTER FUNCTION public.anonymize_match_players_on_user_delete() OWNER TO postgres;

DROP TRIGGER IF EXISTS anonymize_match_players_before_user_delete ON public.users;
CREATE TRIGGER anonymize_match_players_before_user_delete
    BEFORE DELETE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.anonymize_match_players_on_user_delete();

DO $$
BEGIN
    RAISE NOTICE '=== Migration 089 complete: trigger installed ===';
END $$;

COMMIT;

-- =====================================================
-- VERIFICATION (optional)
-- =====================================================
-- SELECT tgname, tgenabled FROM pg_trigger
-- WHERE tgname = 'anonymize_match_players_before_user_delete';

-- =====================================================
-- ROLLBACK (run manually if needed)
-- =====================================================
/*
BEGIN;
DROP TRIGGER IF EXISTS anonymize_match_players_before_user_delete ON public.users;
DROP FUNCTION IF EXISTS public.anonymize_match_players_on_user_delete();
COMMIT;
*/
