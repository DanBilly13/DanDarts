-- Migration 038: Fix broken match_players SELECT policy
-- Root cause: jsonb_array_elements(m.players) fails on scalar/NULL values in guest matches
-- This policy was poisoning all queries touching match_players, causing "cannot extract elements from a scalar" errors
-- Date: 2026-01-07

-- ============================================================================
-- VERIFICATION: Check current state
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '=== Pre-Migration State ===';
    RAISE NOTICE 'Checking current match_players policies...';
END $$;

-- Show current policies on match_players
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players';

-- ============================================================================
-- MIGRATION: Replace broken policy with safe relational check
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '=== Starting Migration ===';
    RAISE NOTICE 'Dropping broken policy that uses jsonb_array_elements...';
END $$;

-- Step 1: Drop the broken policy
DROP POLICY IF EXISTS "Users can view match_players for their matches" ON public.match_players;

-- Step 2: Create safe policy using relational membership check
-- This policy:
-- - Avoids JSON traversal entirely
-- - Ignores guests (NULL player_user_id)
-- - Uses simple EXISTS check on match_players itself
-- - Is indexable and performant
CREATE POLICY match_players_select_participant ON public.match_players
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.match_players mp2
            WHERE mp2.match_id = match_players.match_id
            AND mp2.player_user_id = auth.uid()
        )
    );

-- ============================================================================
-- VERIFICATION: Check new state
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '=== Post-Migration State ===';
    RAISE NOTICE 'Verifying new policy...';
END $$;

-- Verify new policy exists
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players';

-- Verify RLS is still enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'match_players';

DO $$
BEGIN
    RAISE NOTICE '=== Migration Complete ===';
    RAISE NOTICE 'Broken jsonb_array_elements policy removed';
    RAISE NOTICE 'New relational membership policy created';
    RAISE NOTICE 'Guest players: Handled correctly (NULL player_user_id ignored)';
    RAISE NOTICE 'This should fix "cannot extract elements from a scalar" errors';
END $$;

-- ============================================================================
-- ROLLBACK SCRIPT (if needed)
-- ============================================================================

/*

-- ROLLBACK: Restore original policy

BEGIN;

-- Drop the new policy
DROP POLICY IF EXISTS match_players_select_participant ON public.match_players;

-- Restore original policy (WARNING: This policy is broken with guest players!)
CREATE POLICY "Users can view match_players for their matches" ON public.match_players
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM matches m
            CROSS JOIN LATERAL jsonb_array_elements(m.players) player(value)
            WHERE m.id = match_players.match_id
            AND ((m.winner_id = auth.uid()) OR (player.value->>'id')::uuid = auth.uid())
        )
    );

-- Verify rollback
SELECT 
    policyname,
    cmd
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players';

COMMIT;

-- NOTE: The original policy will cause "cannot extract elements from a scalar" errors
-- with guest matches. Only rollback if absolutely necessary for debugging.

*/
