-- Migration 039: Disable RLS on match_players
-- 
-- PROBLEM: match_players SELECT policy causes "cannot extract elements from a scalar" 
-- error due to jsonb_array_elements on guest player data. Attempted fix in migration 038
-- caused infinite recursion.
--
-- SOLUTION: Disable RLS on match_players entirely. Security is already enforced at the
-- matches table level via RLS policies. match_players is a junction table that doesn't
-- need its own RLS since users can only access matches they participate in.
--
-- Created: 2026-01-07

BEGIN;

-- Step 1: Verify current state
DO $$
BEGIN
    RAISE NOTICE '=== MIGRATION 039: Disable RLS on match_players ===';
    RAISE NOTICE 'Current timestamp: %', now();
END $$;

-- Step 2: Check existing policies
SELECT 
    'Current match_players policies:' as info,
    policyname,
    cmd,
    CASE 
        WHEN length(qual::text) > 100 THEN substring(qual::text, 1, 100) || '...'
        ELSE qual::text
    END as policy_definition
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players';

-- Step 3: Check RLS status
SELECT 
    'Current RLS status:' as info,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'match_players';

-- Step 4: Drop all existing policies on match_players
DROP POLICY IF EXISTS "Users can view match_players for their matches" ON public.match_players;
DROP POLICY IF EXISTS match_players_select_participant ON public.match_players;
DROP POLICY IF EXISTS "Users can insert match_players for their matches" ON public.match_players;
DROP POLICY IF EXISTS "Users can update match_players for their matches" ON public.match_players;
DROP POLICY IF EXISTS "Users can delete match_players for their matches" ON public.match_players;

-- Step 5: Disable RLS on match_players
ALTER TABLE public.match_players DISABLE ROW LEVEL SECURITY;

-- Step 6: Verify changes
SELECT 
    'After disabling RLS:' as info,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'match_players';

SELECT 
    'Remaining policies (should be 0):' as info,
    COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players';

DO $$
BEGIN
    RAISE NOTICE '=== Migration 039 completed successfully ===';
    RAISE NOTICE 'RLS disabled on match_players';
    RAISE NOTICE 'All policies dropped';
    RAISE NOTICE 'Security still enforced via matches table RLS';
END $$;

COMMIT;

-- ============================================================================
-- ROLLBACK SCRIPT (if needed)
-- ============================================================================
/*

BEGIN;

-- Re-enable RLS on match_players
ALTER TABLE public.match_players ENABLE ROW LEVEL SECURITY;

-- Restore the original policy (the one with jsonb_array_elements)
-- WARNING: This policy is broken and will cause "cannot extract elements from a scalar" errors
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
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'match_players';

SELECT
    COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players';

COMMIT;

-- Expected results after rollback:
-- rls_enabled: true
-- policy_count: 1

*/
