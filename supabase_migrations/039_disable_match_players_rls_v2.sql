-- Migration 039 v2: Disable RLS on match_players (more aggressive)
-- 
-- PROBLEM: Previous attempt left 1 policy remaining
-- SOLUTION: Query all policies dynamically and drop them, then disable RLS
--
-- Created: 2026-01-07

BEGIN;

-- Step 1: Find and display all existing policies
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    RAISE NOTICE '=== MIGRATION 039 v2: Aggressive RLS Disable ===';
    RAISE NOTICE 'Finding all policies on match_players...';
    
    FOR policy_record IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'match_players'
    LOOP
        RAISE NOTICE 'Found policy: %', policy_record.policyname;
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.match_players', policy_record.policyname);
        RAISE NOTICE 'Dropped policy: %', policy_record.policyname;
    END LOOP;
END $$;

-- Step 2: Disable RLS
ALTER TABLE public.match_players DISABLE ROW LEVEL SECURITY;

-- Step 3: Verify - should show 0 policies and RLS disabled
SELECT 
    'Final verification:' as info,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'match_players';

SELECT 
    'Policy count (should be 0):' as info,
    COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players';

-- Step 4: Show any remaining policies (for debugging)
SELECT 
    'Any remaining policies:' as info,
    policyname,
    cmd
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players';

DO $$
BEGIN
    RAISE NOTICE '=== Migration 039 v2 completed ===';
    RAISE NOTICE 'All policies dropped dynamically';
    RAISE NOTICE 'RLS disabled on match_players';
END $$;

COMMIT;
