-- Migration 070: Diagnose match_players RLS state
-- 
-- Purpose: Investigate why client-side INSERT to match_players fails with RLS error 42501
-- This is a diagnostic-only migration - it makes NO changes to the database
-- 
-- Context:
-- - Local match saves fail with: "new row violates row-level security policy for table \"match_players\""
-- - Remote match Edge Function inserts succeed
-- - Migration 012 created INSERT policy with WITH CHECK (true)
-- - Migration 039_v2 disabled RLS entirely
-- - Need to determine current state before applying fix
--
-- Date: 2026-03-11

BEGIN;

DO $$
BEGIN
    RAISE NOTICE '=== MIGRATION 070: match_players RLS Diagnostic ===';
    RAISE NOTICE 'This migration makes NO changes - diagnostic only';
    RAISE NOTICE '';
END $$;

-- ============================================================================
-- STEP 1: Check if RLS is enabled on match_players
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '--- Step 1: RLS Status ---';
END $$;

SELECT 
    'RLS Status:' as info,
    schemaname,
    tablename,
    rowsecurity as rls_enabled,
    CASE 
        WHEN rowsecurity THEN 'RLS is ENABLED - policies will be enforced'
        ELSE 'RLS is DISABLED - all operations allowed'
    END as explanation
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'match_players';

-- ============================================================================
-- STEP 2: List all policies on match_players
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '--- Step 2: Active Policies ---';
END $$;

SELECT 
    'Policy Details:' as info,
    policyname,
    cmd as command,
    permissive,
    roles,
    qual as using_expression,
    with_check as with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players'
ORDER BY cmd, policyname;

-- Count policies by type
SELECT 
    'Policy Count by Type:' as info,
    cmd as command,
    COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players'
GROUP BY cmd
ORDER BY cmd;

-- ============================================================================
-- STEP 3: Check for INSERT policy specifically
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '--- Step 3: INSERT Policy Check ---';
END $$;

SELECT 
    'INSERT Policies:' as info,
    policyname,
    permissive,
    with_check as with_check_expression,
    CASE 
        WHEN with_check = 'true' THEN 'PERMISSIVE - allows all authenticated inserts'
        WHEN with_check IS NULL THEN 'NO WITH CHECK - may block inserts'
        ELSE 'RESTRICTIVE - has conditions: ' || with_check
    END as analysis
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players'
AND cmd = 'INSERT';

-- Check if expected policy exists
DO $$
DECLARE
    policy_exists boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1 
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'match_players'
        AND policyname = 'Authenticated users can insert match_players'
    ) INTO policy_exists;
    
    IF policy_exists THEN
        RAISE NOTICE 'Expected policy "Authenticated users can insert match_players" EXISTS';
    ELSE
        RAISE NOTICE 'Expected policy "Authenticated users can insert match_players" MISSING';
    END IF;
END $$;

-- ============================================================================
-- STEP 4: Check for policy conflicts
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '--- Step 4: Policy Conflicts ---';
END $$;

-- Check for multiple INSERT policies (potential conflict)
SELECT 
    'Multiple INSERT Policies?:' as info,
    COUNT(*) as insert_policy_count,
    CASE 
        WHEN COUNT(*) > 1 THEN 'WARNING - Multiple INSERT policies may conflict'
        WHEN COUNT(*) = 1 THEN 'OK - Single INSERT policy'
        WHEN COUNT(*) = 0 THEN 'PROBLEM - No INSERT policy found'
    END as status
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players'
AND cmd = 'INSERT';

-- ============================================================================
-- STEP 5: Summary and Recommendations
-- ============================================================================

DO $$
DECLARE
    rls_enabled boolean;
    insert_policy_count integer;
    expected_policy_exists boolean;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '--- Step 5: Summary & Recommendations ---';
    
    -- Get RLS status
    SELECT rowsecurity INTO rls_enabled
    FROM pg_tables
    WHERE schemaname = 'public' AND tablename = 'match_players';
    
    -- Get INSERT policy count
    SELECT COUNT(*) INTO insert_policy_count
    FROM pg_policies
    WHERE schemaname = 'public' 
    AND tablename = 'match_players'
    AND cmd = 'INSERT';
    
    -- Check for expected policy
    SELECT EXISTS (
        SELECT 1 
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'match_players'
        AND policyname = 'Authenticated users can insert match_players'
    ) INTO expected_policy_exists;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== DIAGNOSTIC RESULTS ===';
    RAISE NOTICE 'RLS Enabled: %', rls_enabled;
    RAISE NOTICE 'INSERT Policies: %', insert_policy_count;
    RAISE NOTICE 'Expected Policy Exists: %', expected_policy_exists;
    RAISE NOTICE '';
    
    -- Provide recommendations
    IF NOT rls_enabled THEN
        RAISE NOTICE 'RECOMMENDATION: RLS is disabled - error should not occur';
        RAISE NOTICE 'ACTION: Investigate if error is coming from different source';
    ELSIF insert_policy_count = 0 THEN
        RAISE NOTICE 'RECOMMENDATION: RLS enabled but no INSERT policy';
        RAISE NOTICE 'ACTION: Create INSERT policy from migration 012';
    ELSIF insert_policy_count > 1 THEN
        RAISE NOTICE 'RECOMMENDATION: Multiple INSERT policies may conflict';
        RAISE NOTICE 'ACTION: Drop duplicate policies, keep correct one';
    ELSIF expected_policy_exists THEN
        RAISE NOTICE 'RECOMMENDATION: Policy exists - may have wrong WITH CHECK';
        RAISE NOTICE 'ACTION: Verify WITH CHECK = true in policy details above';
    ELSE
        RAISE NOTICE 'RECOMMENDATION: Policy exists but has wrong name';
        RAISE NOTICE 'ACTION: Check policy details above for restrictive conditions';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '=== END DIAGNOSTIC ===';
END $$;

COMMIT;
