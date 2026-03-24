-- =====================================================
-- DanDarts Database Migration 083
-- Add Replay Columns to Matches Table
-- =====================================================
-- Purpose: Add columns to distinguish replay/rematch requests from regular challenges
-- Date: 2026-03-23
-- Phase: Phase 16 - Remote Match Replay
-- =====================================================

BEGIN;

-- ============================================
-- STEP 1: ADD REPLAY COLUMNS
-- ============================================

-- Mark if this match is a replay request
ALTER TABLE matches ADD COLUMN IF NOT EXISTS is_replay BOOLEAN NOT NULL DEFAULT false;
COMMENT ON COLUMN matches.is_replay IS 'True if this is a replay/rematch request';

-- Reference to the original match being replayed
ALTER TABLE matches ADD COLUMN IF NOT EXISTS replay_source_match_id UUID;
COMMENT ON COLUMN matches.replay_source_match_id IS 'ID of the completed match this is a replay of (NULL if not a replay)';

DO $$ BEGIN RAISE NOTICE 'Added replay columns to matches table'; END $$;

-- ============================================
-- STEP 2: ADD FOREIGN KEY CONSTRAINT
-- ============================================

-- Add foreign key constraint (with ON DELETE SET NULL for safety)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_replay_source_match'
    ) THEN
        ALTER TABLE matches 
        ADD CONSTRAINT fk_replay_source_match 
        FOREIGN KEY (replay_source_match_id) 
        REFERENCES matches(id) 
        ON DELETE SET NULL;
        
        RAISE NOTICE 'Added foreign key constraint fk_replay_source_match';
    ELSE
        RAISE NOTICE 'Foreign key constraint fk_replay_source_match already exists';
    END IF;
END $$;

-- ============================================
-- STEP 3: CREATE INDEX FOR REPLAY QUERIES
-- ============================================

-- Create index for efficient replay queries
CREATE INDEX IF NOT EXISTS matches_replay_source_idx 
    ON matches(replay_source_match_id) 
    WHERE is_replay = true;

DO $$ BEGIN RAISE NOTICE 'Created index matches_replay_source_idx'; END $$;

-- ============================================
-- VERIFICATION
-- ============================================

DO $$
DECLARE
    is_replay_exists BOOLEAN;
    replay_source_exists BOOLEAN;
    fk_exists BOOLEAN;
    index_exists BOOLEAN;
BEGIN
    -- Check is_replay column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'matches' AND column_name = 'is_replay'
    ) INTO is_replay_exists;
    
    -- Check replay_source_match_id column
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'matches' AND column_name = 'replay_source_match_id'
    ) INTO replay_source_exists;
    
    -- Check foreign key constraint
    SELECT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'fk_replay_source_match'
    ) INTO fk_exists;
    
    -- Check index
    SELECT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'matches_replay_source_idx'
    ) INTO index_exists;
    
    -- Report results
    RAISE NOTICE '=== Migration 083 Verification ===';
    RAISE NOTICE 'is_replay column exists: %', is_replay_exists;
    RAISE NOTICE 'replay_source_match_id column exists: %', replay_source_exists;
    RAISE NOTICE 'Foreign key constraint exists: %', fk_exists;
    RAISE NOTICE 'Index exists: %', index_exists;
    
    IF is_replay_exists AND replay_source_exists AND fk_exists AND index_exists THEN
        RAISE NOTICE '✅ Migration 083 completed successfully!';
    ELSE
        RAISE EXCEPTION 'Migration 083 verification failed!';
    END IF;
END $$;

COMMIT;
