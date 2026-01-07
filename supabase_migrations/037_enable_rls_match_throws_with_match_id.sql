-- Migration 037: Enable RLS on match_throws using match_id membership policy
-- This resolves the Supabase RLS error while maintaining multi-guest support
-- Date: 2026-01-07

-- ============================================================================
-- VERIFICATION: Check current state
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '=== Pre-Migration State ===';
    RAISE NOTICE 'Checking match_throws table structure...';
END $$;

-- Verify match_id column exists
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'match_throws'
AND column_name = 'match_id';

-- Check current RLS status
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'match_throws';

-- Count existing throws
SELECT COUNT(*) as total_throws FROM match_throws;

-- ============================================================================
-- MIGRATION: Enable RLS with membership-based policy
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '=== Starting Migration ===';
    RAISE NOTICE 'Enabling RLS on match_throws...';
END $$;

-- Step 1: Enable Row Level Security
ALTER TABLE public.match_throws ENABLE ROW LEVEL SECURITY;

-- Step 2: Create membership-based policy
-- Users can access throw data if they are a player in that match
CREATE POLICY match_throws_membership_policy ON public.match_throws
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 
            FROM match_players
            WHERE match_players.match_id = match_throws.match_id
            AND match_players.player_user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 
            FROM match_players
            WHERE match_players.match_id = match_throws.match_id
            AND match_players.player_user_id = auth.uid()
        )
    );

-- Step 3: Ensure index exists for policy performance
CREATE INDEX IF NOT EXISTS idx_match_throws_match_id ON match_throws(match_id);

-- Step 4: Ensure permissions are granted
GRANT SELECT, INSERT, UPDATE, DELETE ON public.match_throws TO authenticated;
GRANT SELECT ON public.match_throws TO anon;

-- ============================================================================
-- VERIFICATION: Check new state
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '=== Post-Migration State ===';
    RAISE NOTICE 'Verifying RLS and policies...';
END $$;

-- Verify RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'match_throws';

-- Verify policy exists
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_throws';

-- Verify index exists
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
AND tablename = 'match_throws'
AND indexname = 'idx_match_throws_match_id';

-- Verify permissions
SELECT 
    grantee,
    string_agg(privilege_type, ', ') as permissions
FROM information_schema.table_privileges
WHERE table_schema = 'public'
AND table_name = 'match_throws'
AND grantee IN ('anon', 'authenticated')
GROUP BY grantee;

DO $$
BEGIN
    RAISE NOTICE '=== Migration Complete ===';
    RAISE NOTICE 'RLS enabled with membership-based policy';
    RAISE NOTICE 'Policy: Users can access throws if they are players in the match';
    RAISE NOTICE 'Guest players: Handled correctly (no player_user_id check on guests)';
END $$;

-- ============================================================================
-- ROLLBACK SCRIPT (if needed)
-- ============================================================================

/*

-- ROLLBACK: Disable RLS and remove policy

BEGIN;

-- Drop the policy
DROP POLICY IF EXISTS match_throws_membership_policy ON public.match_throws;

-- Disable RLS
ALTER TABLE public.match_throws DISABLE ROW LEVEL SECURITY;

-- Verify rollback
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'match_throws';

SELECT 
    COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'match_throws';

COMMIT;

-- Expected results after rollback:
-- rls_enabled: false
-- policy_count: 0

*/
