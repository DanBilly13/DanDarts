-- Migration 071: Create missing match_players INSERT policy
-- 
-- Purpose: Restore INSERT policy that was lost when RLS was re-enabled
-- 
-- Context:
-- - Diagnostic 070 confirmed: RLS enabled + 0 INSERT policies = 42501 error
-- - Migration 012 originally created this policy
-- - Migration 039_v2 disabled RLS (to fix SELECT issues)
-- - A subsequent migration re-enabled RLS without recreating INSERT policy
-- - This restores the previous intended client-side local save behavior
--
-- Date: 2026-03-11

BEGIN;

DO $$
BEGIN
    RAISE NOTICE '=== MIGRATION 071: Create match_players INSERT Policy ===';
    RAISE NOTICE 'Restoring missing INSERT policy for authenticated users';
    RAISE NOTICE '';
END $$;

-- ============================================================================
-- STEP 1: Verify current state
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '--- Step 1: Pre-Migration State ---';
END $$;

-- Show current RLS status
SELECT 
    'Current RLS Status:' as info,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'match_players';

-- Show current INSERT policies (should be 0)
SELECT 
    'Current INSERT Policies:' as info,
    COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players'
AND cmd = 'INSERT';

-- ============================================================================
-- STEP 2: Drop existing policy (defensive - if it somehow exists)
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '--- Step 2: Drop Existing Policy (if any) ---';
END $$;

DROP POLICY IF EXISTS "Authenticated users can insert match_players" ON public.match_players;

DO $$
BEGIN
    RAISE NOTICE 'Dropped policy "Authenticated users can insert match_players" (if it existed)';
END $$;

-- ============================================================================
-- STEP 3: Create new INSERT policy
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '--- Step 3: Create INSERT Policy ---';
END $$;

CREATE POLICY "Authenticated users can insert match_players"
    ON public.match_players
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

DO $$
BEGIN
    RAISE NOTICE 'Created policy: "Authenticated users can insert match_players"';
    RAISE NOTICE 'Scope: FOR INSERT TO authenticated';
    RAISE NOTICE 'Condition: WITH CHECK (true) - allows all authenticated inserts';
END $$;

-- ============================================================================
-- STEP 4: Verify policy was created successfully
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '--- Step 4: Post-Migration Verification ---';
END $$;

-- Verify policy exists
SELECT 
    'Policy Created:' as info,
    policyname,
    cmd as command,
    permissive,
    with_check as with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players'
AND policyname = 'Authenticated users can insert match_players';

-- Count total INSERT policies (should be 1)
SELECT 
    'Total INSERT Policies:' as info,
    COUNT(*) as policy_count,
    CASE 
        WHEN COUNT(*) = 1 THEN 'SUCCESS - Exactly 1 INSERT policy'
        WHEN COUNT(*) = 0 THEN 'ERROR - No INSERT policy found'
        ELSE 'WARNING - Multiple INSERT policies'
    END as status
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players'
AND cmd = 'INSERT';

-- Show all policies on match_players (for reference)
SELECT 
    'All Policies on match_players:' as info,
    policyname,
    cmd as command
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_players'
ORDER BY cmd, policyname;

-- ============================================================================
-- STEP 5: Final verification and summary
-- ============================================================================

DO $$
DECLARE
    policy_exists boolean;
    policy_count integer;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '--- Step 5: Final Summary ---';
    
    -- Check if policy exists
    SELECT EXISTS (
        SELECT 1 
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'match_players'
        AND policyname = 'Authenticated users can insert match_players'
    ) INTO policy_exists;
    
    -- Get INSERT policy count
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public' 
    AND tablename = 'match_players'
    AND cmd = 'INSERT';
    
    RAISE NOTICE '';
    RAISE NOTICE '=== MIGRATION 071 COMPLETE ===';
    RAISE NOTICE 'Policy Exists: %', policy_exists;
    RAISE NOTICE 'INSERT Policy Count: %', policy_count;
    
    IF policy_exists AND policy_count = 1 THEN
        RAISE NOTICE 'STATUS: SUCCESS';
        RAISE NOTICE '';
        RAISE NOTICE 'Next Steps:';
        RAISE NOTICE '1. Test local match save in app';
        RAISE NOTICE '2. Verify console shows no 42501 error';
        RAISE NOTICE '3. Check player/friend stats update correctly';
    ELSE
        RAISE NOTICE 'STATUS: ERROR - Policy creation failed';
        RAISE NOTICE 'Review output above for details';
    END IF;
    
    RAISE NOTICE '';
END $$;

COMMIT;
