-- =====================================================
-- DanDarts Database Migration 081
-- Restore match_players RLS State (Re-apply Migration 039)
-- =====================================================
-- Purpose: Fix production drift - disable RLS on match_players
-- Date: 2026-03-18
-- Issue: RLS is blocking challenger from inserting receiver's match_players row
--        Error: "new row violates row-level security policy (USING expression)"
-- Solution: Re-apply migration 039 intent - disable RLS entirely
-- =====================================================

BEGIN;

DO $$
BEGIN
    RAISE NOTICE '=== MIGRATION 081: Restore match_players RLS State ===';
    RAISE NOTICE 'Current timestamp: %', now();
    RAISE NOTICE 'Re-applying migration 039 intent';
END $$;

-- Step 1: Check current state
SELECT 
    'BEFORE - RLS Status:' as info,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'match_players';

SELECT 
    'BEFORE - Policy Count:' as info,
    COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'match_players';

-- Step 2: Drop all existing policies on match_players
-- Drop the policies that actually exist in production right now
DROP POLICY IF EXISTS "Authenticated users can insert match_players" ON public.match_players;
DROP POLICY IF EXISTS match_players_select_participants ON public.match_players;

-- Also clean up older/historical names in case they exist in another environment
DROP POLICY IF EXISTS "Users can view match_players for their matches" ON public.match_players;
DROP POLICY IF EXISTS match_players_select_participant ON public.match_players;
DROP POLICY IF EXISTS "Users can insert match_players for their matches" ON public.match_players;
DROP POLICY IF EXISTS "Users can update match_players for their matches" ON public.match_players;
DROP POLICY IF EXISTS "Users can delete match_players for their matches" ON public.match_players;

DO $$ BEGIN RAISE NOTICE '✓ Dropped all policies on match_players'; END $$;

-- Step 3: Disable RLS on match_players
ALTER TABLE public.match_players DISABLE ROW LEVEL SECURITY;

DO $$ BEGIN RAISE NOTICE '✓ Disabled RLS on match_players'; END $$;

-- Step 4: Verify changes
SELECT 
    'AFTER - RLS Status:' as info,
    tablename,
    rowsecurity as rls_enabled,
    CASE 
        WHEN rowsecurity THEN '❌ FAILED - RLS still enabled'
        ELSE '✅ SUCCESS - RLS disabled'
    END as status
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'match_players';

SELECT 
    'AFTER - Policy Count:' as info,
    COUNT(*) as policy_count,
    CASE 
        WHEN COUNT(*) > 0 THEN '❌ FAILED - Policies still exist'
        ELSE '✅ SUCCESS - No policies'
    END as status
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'match_players';

DO $$
BEGIN
    RAISE NOTICE '=== Migration 081 completed ===';
    RAISE NOTICE 'RLS disabled on match_players';
    RAISE NOTICE 'All policies dropped';
    RAISE NOTICE 'Security enforced via matches table RLS';
    RAISE NOTICE 'Challenger can now insert receiver match_players row';
END $$;

COMMIT;

-- =====================================================
-- VERIFICATION QUERY (run after migration):
-- =====================================================
/*
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'match_players';
-- Expected: rowsecurity = false

SELECT COUNT(*) as policy_count
FROM pg_policies 
WHERE tablename = 'match_players';
-- Expected: 0
*/
