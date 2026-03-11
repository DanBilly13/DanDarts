-- Migration 072: Create missing match_throws INSERT policy
-- 
-- Purpose: Restore INSERT policy for match_throws table
-- 
-- Context:
-- - After fixing match_players INSERT policy (migration 071), match save now fails on match_throws
-- - Error: "new row violates row-level security policy for table \"match_throws\""
-- - Same root cause: RLS enabled but no INSERT policy exists
-- - This restores client-side INSERT capability for turn-by-turn throw data
--
-- Date: 2026-03-11

BEGIN;

DO $$
BEGIN
    RAISE NOTICE '=== MIGRATION 072: Create match_throws INSERT Policy ===';
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
AND tablename = 'match_throws';

-- Show current INSERT policies (likely 0)
SELECT 
    'Current INSERT Policies:' as info,
    COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_throws'
AND cmd = 'INSERT';

-- ============================================================================
-- STEP 2: Drop existing policy (defensive)
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '--- Step 2: Drop Existing Policy (if any) ---';
END $$;

DROP POLICY IF EXISTS "Authenticated users can insert match_throws" ON public.match_throws;

DO $$
BEGIN
    RAISE NOTICE 'Dropped policy "Authenticated users can insert match_throws" (if it existed)';
END $$;

-- ============================================================================
-- STEP 3: Create new INSERT policy
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '--- Step 3: Create INSERT Policy ---';
END $$;

CREATE POLICY "Authenticated users can insert match_throws"
    ON public.match_throws
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

DO $$
BEGIN
    RAISE NOTICE 'Created policy: "Authenticated users can insert match_throws"';
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
AND tablename = 'match_throws'
AND policyname = 'Authenticated users can insert match_throws';

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
AND tablename = 'match_throws'
AND cmd = 'INSERT';

-- Show all policies on match_throws (for reference)
SELECT 
    'All Policies on match_throws:' as info,
    policyname,
    cmd as command
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_throws'
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
        AND tablename = 'match_throws'
        AND policyname = 'Authenticated users can insert match_throws'
    ) INTO policy_exists;
    
    -- Get INSERT policy count
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public' 
    AND tablename = 'match_throws'
    AND cmd = 'INSERT';
    
    RAISE NOTICE '';
    RAISE NOTICE '=== MIGRATION 072 COMPLETE ===';
    RAISE NOTICE 'Policy Exists: %', policy_exists;
    RAISE NOTICE 'INSERT Policy Count: %', policy_count;
    
    IF policy_exists AND policy_count = 1 THEN
        RAISE NOTICE 'STATUS: SUCCESS';
        RAISE NOTICE '';
        RAISE NOTICE 'Next Steps:';
        RAISE NOTICE '1. Test local match save in app';
        RAISE NOTICE '2. Verify console shows no 42501 error';
        RAISE NOTICE '3. Check match_throws records inserted successfully';
        RAISE NOTICE '4. Verify player/friend stats update correctly';
    ELSE
        RAISE NOTICE 'STATUS: ERROR - Policy creation failed';
        RAISE NOTICE 'Review output above for details';
    END IF;
    
    RAISE NOTICE '';
END $$;

COMMIT;
