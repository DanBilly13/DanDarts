-- =====================================================
-- DanDarts Database Migration 080
-- Add UNIQUE constraint for (match_id, player_user_id)
-- =====================================================
-- Purpose: Fix enter-lobby edge function upsert operation
-- Date: 2026-03-18
-- Issue: Edge function uses onConflict: 'match_id,player_user_id' but constraint doesn't exist
--        This causes database error 42P10 and ~10 second delays
-- =====================================================

BEGIN;

-- Add UNIQUE constraint for match_id + player_user_id
-- This allows upsert operations to work correctly in enter-lobby edge function
-- Note: This constraint allows the same user to appear in a match only once
ALTER TABLE public.match_players
ADD CONSTRAINT match_players_match_user_unique UNIQUE (match_id, player_user_id);

DO $$ BEGIN RAISE NOTICE '✓ Added UNIQUE constraint (match_id, player_user_id) to match_players'; END $$;

-- Verification
DO $$
DECLARE
    constraint_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'match_players_match_user_unique'
        AND conrelid = 'public.match_players'::regclass
    ) INTO constraint_exists;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 080 Verification:';
    RAISE NOTICE '  Constraint exists: %', constraint_exists;
    
    IF constraint_exists THEN
        RAISE NOTICE '✓ Migration 080 completed successfully!';
    ELSE
        RAISE WARNING '⚠ Migration 080 incomplete - constraint not created';
    END IF;
    RAISE NOTICE '========================================';
END $$;

COMMIT;
