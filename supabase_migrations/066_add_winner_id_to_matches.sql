-- Add winner_id column to matches table for remote match winner tracking
-- This enables both players to see the game end screen when a match is won

-- Add column only if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'matches' AND column_name = 'winner_id'
    ) THEN
        ALTER TABLE matches ADD COLUMN winner_id UUID REFERENCES users(id);
    END IF;
END $$;

-- Add index for efficient winner queries (only if it doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'idx_matches_winner_id'
    ) THEN
        CREATE INDEX idx_matches_winner_id ON matches(winner_id);
    END IF;
END $$;

-- Add comment for documentation
COMMENT ON COLUMN matches.winner_id IS 'User ID of the match winner (null if match not completed)';
