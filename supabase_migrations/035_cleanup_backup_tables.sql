-- ============================================
-- Migration 035: Cleanup Backup Tables from Migration 034
-- ============================================
-- Purpose: Remove backup tables created during migration 034 to clear Supabase security warnings
-- Date: 2026-01-07
-- 
-- BACKGROUND:
-- Migration 034 created backup tables for safety when disabling RLS on match_throws.
-- These backup tables are now triggering Supabase security warnings because they
-- don't have RLS enabled (which is fine for backup tables).
--
-- Since the migration was successful and matches are saving correctly,
-- we can safely remove these backup tables.
--
-- ============================================

-- Drop backup tables created by migration 034
DROP TABLE IF EXISTS public.match_throws_backup_20260107;
DROP TABLE IF EXISTS public.match_throws_policies_backup_20260107;

-- Verification
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 035 completed successfully! ✓';
    RAISE NOTICE 'Backup tables removed';
    RAISE NOTICE 'Security warnings should be cleared';
    RAISE NOTICE '========================================';
END $$;
