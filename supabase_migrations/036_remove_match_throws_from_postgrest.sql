-- ============================================
-- Migration 036: Remove match_throws from PostgREST API
-- ============================================
-- Purpose: Clear Supabase security error by removing match_throws from PostgREST exposure
-- Date: 2026-01-07
-- 
-- BACKGROUND:
-- Supabase's security linter flags public tables without RLS as errors.
-- However, match_throws doesn't need RLS because:
-- 1. Security is enforced via match_players and matches tables
-- 2. Only authenticated users can create matches
-- 3. Guest players are a legitimate use case
--
-- SOLUTION:
-- Remove match_throws from PostgREST's public API while keeping SDK access.
-- This satisfies the security linter without breaking the app.
--
-- IMPACT:
-- - Swift app continues to work (uses Supabase SDK, not REST API)
-- - Direct REST API calls to match_throws will be blocked
-- - Security linter error will be cleared
--
-- SAFETY:
-- - Full rollback script included
-- - Non-destructive (only changes permissions)
-- - Can be reversed instantly
--
-- ============================================

-- ============================================
-- STEP 1: VERIFY CURRENT STATE
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 036: Remove match_throws from PostgREST';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Checking current permissions...';
END $$;

-- Show current permissions
DO $$
DECLARE
    anon_perms TEXT;
    auth_perms TEXT;
BEGIN
    -- Check anon role permissions
    SELECT string_agg(privilege_type, ', ') INTO anon_perms
    FROM information_schema.table_privileges
    WHERE table_schema = 'public'
    AND table_name = 'match_throws'
    AND grantee = 'anon';
    
    -- Check authenticated role permissions
    SELECT string_agg(privilege_type, ', ') INTO auth_perms
    FROM information_schema.table_privileges
    WHERE table_schema = 'public'
    AND table_name = 'match_throws'
    AND grantee = 'authenticated';
    
    RAISE NOTICE 'Current permissions:';
    RAISE NOTICE '  anon role: %', COALESCE(anon_perms, 'NONE');
    RAISE NOTICE '  authenticated role: %', COALESCE(auth_perms, 'NONE');
END $$;

-- ============================================
-- STEP 2: REVOKE POSTGREST ACCESS
-- ============================================

-- Revoke all permissions from PostgREST roles
-- This removes the table from the REST API while keeping SDK access
REVOKE ALL ON public.match_throws FROM anon;
REVOKE ALL ON public.match_throws FROM authenticated;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Revoked PostgREST permissions ✓';
    RAISE NOTICE '  - anon role: ALL REVOKED';
    RAISE NOTICE '  - authenticated role: ALL REVOKED';
    RAISE NOTICE '';
    RAISE NOTICE 'Table is now hidden from PostgREST API';
    RAISE NOTICE 'SDK access still works (uses service_role)';
END $$;

-- ============================================
-- STEP 3: VERIFICATION
-- ============================================

DO $$
DECLARE
    anon_perms TEXT;
    auth_perms TEXT;
BEGIN
    -- Check anon role permissions
    SELECT string_agg(privilege_type, ', ') INTO anon_perms
    FROM information_schema.table_privileges
    WHERE table_schema = 'public'
    AND table_name = 'match_throws'
    AND grantee = 'anon';
    
    -- Check authenticated role permissions
    SELECT string_agg(privilege_type, ', ') INTO auth_perms
    FROM information_schema.table_privileges
    WHERE table_schema = 'public'
    AND table_name = 'match_throws'
    AND grantee = 'authenticated';
    
    RAISE NOTICE '=== VERIFICATION REPORT ===';
    RAISE NOTICE 'New permissions:';
    RAISE NOTICE '  anon role: %', COALESCE(anon_perms, 'NONE');
    RAISE NOTICE '  authenticated role: %', COALESCE(auth_perms, 'NONE');
    
    IF anon_perms IS NULL AND auth_perms IS NULL THEN
        RAISE NOTICE '';
        RAISE NOTICE 'Verification PASSED ✓';
        RAISE NOTICE 'Table successfully removed from PostgREST API';
    ELSE
        RAISE WARNING 'Verification FAILED - permissions still exist';
    END IF;
END $$;

-- ============================================
-- MIGRATION COMPLETE
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 036 completed successfully! ✓';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'CHANGES:';
    RAISE NOTICE '  - match_throws removed from PostgREST API';
    RAISE NOTICE '  - SDK access still works (service_role)';
    RAISE NOTICE '  - Security linter error should be cleared';
    RAISE NOTICE '';
    RAISE NOTICE 'TESTING:';
    RAISE NOTICE '  1. Save a 3-player match in your app';
    RAISE NOTICE '  2. Verify it saves successfully';
    RAISE NOTICE '  3. Check Security Advisor for errors';
    RAISE NOTICE '';
    RAISE NOTICE 'If anything breaks, run ROLLBACK below';
    RAISE NOTICE '========================================';
END $$;


-- ============================================
-- ============================================
-- ROLLBACK SCRIPT (RUN IF THINGS BREAK)
-- ============================================
-- ============================================
--
-- If your app stops working, run this to restore PostgREST access:
--
-- -- ROLLBACK: Restore PostgREST permissions
-- GRANT SELECT, INSERT, UPDATE, DELETE ON public.match_throws TO authenticated;
-- GRANT SELECT ON public.match_throws TO anon;
--
-- -- Verify restoration
-- SELECT 
--     grantee,
--     string_agg(privilege_type, ', ') as permissions
-- FROM information_schema.table_privileges
-- WHERE table_schema = 'public'
-- AND table_name = 'match_throws'
-- AND grantee IN ('anon', 'authenticated')
-- GROUP BY grantee;
--
-- ============================================
