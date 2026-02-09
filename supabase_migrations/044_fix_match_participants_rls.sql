-- =====================================================
-- DanDarts Database Migration 044
-- Fix match_participants RLS policy
-- =====================================================
-- Purpose: Remove dependency on matches.players JSONB column
-- Date: 2026-02-09
-- 
-- The current RLS policy tries to parse matches.players which
-- is double-encoded JSON and causes "cannot extract elements 
-- from a scalar" error. We fix this by using match_participants
-- table itself for the RLS check.
-- =====================================================

BEGIN;

-- Drop the problematic policy
DROP POLICY IF EXISTS "Users can view match participants" ON public.match_participants;

-- Create new policy that uses match_participants table itself
CREATE POLICY "Users can view match participants"
    ON public.match_participants
    FOR SELECT
    TO authenticated
    USING (
        -- Users can see participants for matches they're in
        -- Check if current user is also a participant in this match
        EXISTS (
            SELECT 1 FROM public.match_participants mp
            WHERE mp.match_id = match_participants.match_id
            AND mp.user_id = auth.uid()
            AND mp.is_guest = false
        )
    );

-- Verify the policy was created
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 044 completed successfully! ✓';
    RAISE NOTICE 'Fixed RLS policy on match_participants';
    RAISE NOTICE 'No longer depends on matches.players column';
    RAISE NOTICE '========================================';
END $$;

COMMIT;

-- ============================================
-- ROLLBACK SCRIPT (DO NOT RUN UNLESS NEEDED)
-- ============================================
--
-- To rollback to the old policy:
--
-- BEGIN;
-- DROP POLICY IF EXISTS "Users can view match participants" ON public.match_participants;
-- CREATE POLICY "Users can view match participants"
--     ON public.match_participants
--     FOR SELECT
--     TO authenticated
--     USING (
--         EXISTS (
--             SELECT 1 FROM public.matches m
--             WHERE m.id = match_id
--             AND (
--                 EXISTS (
--                     SELECT 1 FROM jsonb_array_elements(m.players) AS player
--                     WHERE (player->>'id')::uuid = auth.uid()
--                 )
--             )
--         )
--     );
-- COMMIT;
--
-- ============================================
