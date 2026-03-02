-- =====================================================
-- DanDarts Database Migration 058
-- Add player_scores field to matches table
-- =====================================================
-- Purpose: Store current player scores for remote matches
-- Date: 2026-03-01
-- 
-- RATIONALE:
-- Remote matches need server-authoritative scores that both
-- clients can read in real-time. This field stores the current
-- score for each player (challenger and receiver).
-- =====================================================

BEGIN;

-- Add player_scores column (JSONB object with player_id -> score mapping)
ALTER TABLE matches ADD COLUMN IF NOT EXISTS player_scores JSONB;
COMMENT ON COLUMN matches.player_scores IS 'Current scores for each player {player_id: score} (remote matches only)';

-- Create GIN index for JSONB queries
CREATE INDEX IF NOT EXISTS matches_player_scores_idx ON matches USING GIN (player_scores);

DO $$ BEGIN RAISE NOTICE '✅ Added player_scores column to matches table'; END $$;

COMMIT;
