-- Migration: Add 301/501 Ranking Fields to Users Table
-- V1: Minimal storage - count and total only, derive average/label in code

-- Add ranking aggregate fields
ALTER TABLE users
ADD COLUMN IF NOT EXISTS ranked_wins_count_301_501 INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS ranked_tier_score_total_301_501 INTEGER DEFAULT 0;

-- Add comments for documentation
COMMENT ON COLUMN users.ranked_wins_count_301_501 IS 'Count of qualifying 301/501 wins for ranking (local + remote)';
COMMENT ON COLUMN users.ranked_tier_score_total_301_501 IS 'Sum of tier scores from all qualifying 301/501 wins';

-- Create index for ranking queries (optional, for future leaderboards)
CREATE INDEX IF NOT EXISTS users_ranked_wins_count_idx ON users(ranked_wins_count_301_501 DESC);

-- Verify the migration
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users'
        AND column_name = 'ranked_wins_count_301_501'
    ) THEN
        RAISE NOTICE '✅ ranked_wins_count_301_501 column added successfully';
    ELSE
        RAISE EXCEPTION '❌ ranked_wins_count_301_501 column not found';
    END IF;

    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users'
        AND column_name = 'ranked_tier_score_total_301_501'
    ) THEN
        RAISE NOTICE '✅ ranked_tier_score_total_301_501 column added successfully';
    ELSE
        RAISE EXCEPTION '❌ ranked_tier_score_total_301_501 column not found';
    END IF;
END $$;
