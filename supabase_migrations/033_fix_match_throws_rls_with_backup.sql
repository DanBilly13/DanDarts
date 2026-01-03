-- ============================================
-- Migration 033: Fix match_throws RLS Issue
-- ============================================
-- Purpose: Address Supabase security warning about match_throws table lacking RLS
-- Date: 2026-01-03
-- 
-- SAFETY FEATURES:
-- 1. Creates backup table before any changes
-- 2. Includes rollback script at bottom
-- 3. Verifies match_turns exists and has proper RLS
-- 4. Non-destructive approach
--
-- ============================================

-- ============================================
-- STEP 1: VERIFY CURRENT STATE
-- ============================================

-- Check if match_throws table exists
DO $$
BEGIN
    IF EXISTS (
        SELECT FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'match_throws'
    ) THEN
        RAISE NOTICE 'match_throws table EXISTS - will be backed up and fixed';
    ELSE
        RAISE NOTICE 'match_throws table does NOT exist - no action needed';
    END IF;
END $$;

-- Check if match_turns table exists (the correct one)
DO $$
BEGIN
    IF EXISTS (
        SELECT FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'match_turns'
    ) THEN
        RAISE NOTICE 'match_turns table EXISTS (correct table) ✓';
    ELSE
        RAISE WARNING 'match_turns table MISSING - this is a problem!';
    END IF;
END $$;

-- ============================================
-- STEP 2: CREATE BACKUP (if match_throws exists)
-- ============================================

-- Create backup table with timestamp
DO $$
BEGIN
    IF EXISTS (
        SELECT FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'match_throws'
    ) THEN
        -- Drop old backup if exists
        DROP TABLE IF EXISTS public.match_throws_backup_20260103;
        
        -- Create backup with all data
        CREATE TABLE public.match_throws_backup_20260103 AS 
        SELECT * FROM public.match_throws;
        
        RAISE NOTICE 'Backup created: match_throws_backup_20260103 with % rows', 
            (SELECT COUNT(*) FROM public.match_throws_backup_20260103);
    END IF;
END $$;

-- ============================================
-- STEP 3: ENABLE RLS ON match_throws (Safe approach)
-- ============================================

-- Enable RLS on match_throws table (if it exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'match_throws'
    ) THEN
        -- Enable RLS
        ALTER TABLE public.match_throws ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE 'RLS ENABLED on match_throws table ✓';
        
        -- Drop existing policies if any
        DROP POLICY IF EXISTS "Users can read own match throws" ON public.match_throws;
        DROP POLICY IF EXISTS "Users can insert match throws" ON public.match_throws;
        DROP POLICY IF EXISTS "Users can update match throws" ON public.match_throws;
        
        -- Create SELECT policy
        CREATE POLICY "Users can read own match throws"
            ON public.match_throws FOR SELECT
            USING (
                EXISTS (
                    SELECT 1 FROM match_players
                    WHERE match_players.match_id = match_throws.match_id
                    AND match_players.player_user_id = auth.uid()
                )
            );
        
        -- Create INSERT policy
        CREATE POLICY "Users can insert match throws"
            ON public.match_throws FOR INSERT
            WITH CHECK (
                EXISTS (
                    SELECT 1 FROM match_players
                    WHERE match_players.match_id = match_throws.match_id
                    AND match_players.player_user_id = auth.uid()
                )
            );
        
        -- Create UPDATE policy
        CREATE POLICY "Users can update match throws"
            ON public.match_throws FOR UPDATE
            USING (
                EXISTS (
                    SELECT 1 FROM match_players
                    WHERE match_players.match_id = match_throws.match_id
                    AND match_players.player_user_id = auth.uid()
                )
            );
        
        RAISE NOTICE 'RLS policies created on match_throws ✓';
    END IF;
END $$;

-- ============================================
-- STEP 4: VERIFY RLS ON match_turns
-- ============================================

-- Ensure match_turns has RLS enabled (should already be done)
DO $$
BEGIN
    IF EXISTS (
        SELECT FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'match_turns'
    ) THEN
        -- Enable RLS (idempotent)
        ALTER TABLE public.match_turns ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE 'RLS verified on match_turns table ✓';
    END IF;
END $$;

-- ============================================
-- STEP 5: VERIFICATION REPORT
-- ============================================

-- Show RLS status for all match-related tables
DO $$
DECLARE
    rec RECORD;
BEGIN
    RAISE NOTICE '=== RLS STATUS REPORT ===';
    FOR rec IN 
        SELECT 
            tablename,
            rowsecurity as rls_enabled
        FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename IN ('matches', 'match_players', 'match_turns', 'match_throws', 'match_darts')
        ORDER BY tablename
    LOOP
        RAISE NOTICE 'Table: % | RLS Enabled: %', rec.tablename, rec.rls_enabled;
    END LOOP;
END $$;

-- Show policy count for each table
DO $$
DECLARE
    rec RECORD;
BEGIN
    RAISE NOTICE '=== POLICY COUNT REPORT ===';
    FOR rec IN 
        SELECT 
            tablename,
            COUNT(*) as policy_count
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename IN ('matches', 'match_players', 'match_turns', 'match_throws', 'match_darts')
        GROUP BY tablename
        ORDER BY tablename
    LOOP
        RAISE NOTICE 'Table: % | Policies: %', rec.tablename, rec.policy_count;
    END LOOP;
END $$;

-- ============================================
-- MIGRATION COMPLETE
-- ============================================

-- Success message
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 033 completed successfully! ✓';
    RAISE NOTICE 'Security warning should now be resolved.';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'BACKUP: match_throws_backup_20260103 created';
    RAISE NOTICE 'See ROLLBACK section below if needed';
END $$;


-- ============================================
-- ============================================
-- ROLLBACK SCRIPT (DO NOT RUN UNLESS NEEDED)
-- ============================================
-- ============================================
--
-- If something goes wrong, run this section to restore:
--
-- -- ROLLBACK STEP 1: Disable RLS on match_throws
-- ALTER TABLE public.match_throws DISABLE ROW LEVEL SECURITY;
--
-- -- ROLLBACK STEP 2: Drop policies
-- DROP POLICY IF EXISTS "Users can read own match throws" ON public.match_throws;
-- DROP POLICY IF EXISTS "Users can insert match throws" ON public.match_throws;
-- DROP POLICY IF EXISTS "Users can update match throws" ON public.match_throws;
--
-- -- ROLLBACK STEP 3: Restore from backup (if needed)
-- -- WARNING: This will delete current data and restore backup
-- -- TRUNCATE public.match_throws;
-- -- INSERT INTO public.match_throws SELECT * FROM public.match_throws_backup_20260103;
--
-- -- ROLLBACK STEP 4: Verify
-- SELECT 
--     tablename,
--     rowsecurity as rls_enabled
-- FROM pg_tables 
-- WHERE schemaname = 'public' 
-- AND tablename = 'match_throws';
--
-- ============================================
