-- =====================================================
-- DanDarts Database Migration 060
-- Add UPDATE Policy for Remote Matches
-- =====================================================
-- Purpose: Allow users to update matches they participate in
-- Date: 2026-02-20
-- Issue: accept-challenge was failing silently due to missing UPDATE policy
-- =====================================================

BEGIN;

-- ============================================
-- ADD UPDATE POLICY FOR MATCHES TABLE
-- ============================================

-- Allow users to update remote matches where they are challenger or receiver
DROP POLICY IF EXISTS "Users can update remote matches they participate in" ON matches;
CREATE POLICY "Users can update remote matches they participate in"
    ON matches
    FOR UPDATE
    TO authenticated
    USING (
        match_mode = 'remote' 
        AND (challenger_id = auth.uid() OR receiver_id = auth.uid())
    )
    WITH CHECK (
        match_mode = 'remote' 
        AND (challenger_id = auth.uid() OR receiver_id = auth.uid())
    );

DO $$ BEGIN RAISE NOTICE '✓ Added UPDATE policy for remote matches'; END $$;

-- ============================================
-- VERIFICATION
-- ============================================

DO $$
DECLARE
    policy_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'matches' 
        AND policyname = 'Users can update remote matches they participate in'
    ) INTO policy_exists;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 060 Verification:';
    RAISE NOTICE '  UPDATE policy exists: %', policy_exists;
    
    IF policy_exists THEN
        RAISE NOTICE '✓ Migration 060 completed successfully!';
    ELSE
        RAISE WARNING '⚠ Migration 060 incomplete - UPDATE policy not created';
    END IF;
    RAISE NOTICE '========================================';
END $$;

COMMIT;
