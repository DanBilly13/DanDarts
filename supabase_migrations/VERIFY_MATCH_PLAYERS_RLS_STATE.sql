-- =====================================================
-- Verification Script: match_players RLS State
-- =====================================================
-- Purpose: Check current RLS status and policies on match_players table
-- Run this in Supabase SQL Editor to verify production state
-- =====================================================

-- 1. Check if RLS is enabled on match_players
SELECT 
    '=== RLS STATUS ===' as section,
    tablename,
    rowsecurity as rls_enabled,
    CASE 
        WHEN rowsecurity THEN '❌ RLS IS ENABLED (SHOULD BE DISABLED)'
        ELSE '✅ RLS IS DISABLED (CORRECT)'
    END as status
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'match_players';

-- 2. Check for existing policies on match_players
SELECT 
    '=== EXISTING POLICIES ===' as section,
    policyname,
    cmd as command,
    CASE 
        WHEN length(qual::text) > 100 THEN substring(qual::text, 1, 100) || '...'
        ELSE qual::text
    END as policy_definition
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'match_players';

-- 3. Count policies (should be 0)
SELECT 
    '=== POLICY COUNT ===' as section,
    COUNT(*) as policy_count,
    CASE 
        WHEN COUNT(*) > 0 THEN '❌ POLICIES EXIST (SHOULD BE 0)'
        ELSE '✅ NO POLICIES (CORRECT)'
    END as status
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'match_players';

-- 4. Check table owner and permissions
SELECT 
    '=== TABLE INFO ===' as section,
    schemaname,
    tablename,
    tableowner,
    hasindexes,
    hastriggers
FROM pg_tables
WHERE tablename = 'match_players';

-- =====================================================
-- EXPECTED RESULTS (if migration 039 applied correctly):
-- =====================================================
-- RLS STATUS: rls_enabled = false
-- EXISTING POLICIES: 0 rows
-- POLICY COUNT: 0
-- =====================================================

-- =====================================================
-- IF DRIFT DETECTED (RLS enabled or policies exist):
-- Run the fix script: 081_restore_match_players_rls_state.sql
-- =====================================================
