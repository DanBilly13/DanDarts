-- =====================================================
-- DanDarts Database Migration 060
-- Add Remote Gameplay Fields
-- =====================================================
-- Purpose: Add scores and turn_index_in_leg fields for remote gameplay
-- Date: 2026-02-25
-- Branch: remote-matches
-- 
-- DESIGN DECISIONS:
-- 1. scores JSONB stores current player scores: { challenger_id: score, receiver_id: score }
-- 2. turn_index_in_leg INTEGER for VISIT calculation: (turn_index_in_leg / 2) + 1
-- 3. Both fields are NULL for local matches, only used for remote matches
-- =====================================================

BEGIN;

-- Add scores column (JSONB for flexible player score storage)
ALTER TABLE matches ADD COLUMN IF NOT EXISTS scores JSONB;
COMMENT ON COLUMN matches.scores IS 'Current scores for remote matches: { challenger_id: score, receiver_id: score }';

-- Add turn_index_in_leg column (INTEGER for turn tracking)
ALTER TABLE matches ADD COLUMN IF NOT EXISTS turn_index_in_leg INTEGER DEFAULT 0;
COMMENT ON COLUMN matches.turn_index_in_leg IS 'Turn counter for VISIT calculation (visit = turn_index / 2 + 1)';

DO $$ BEGIN RAISE NOTICE 'Added scores and turn_index_in_leg columns to matches table'; END $$;

COMMIT;
