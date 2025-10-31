-- Migration: Create match_throws table and add game_metadata column
-- Date: 2025-10-31
-- Description: Create match_throws table if not exists, add JSONB column for game-specific data

-- Create match_throws table if it doesn't exist
CREATE TABLE IF NOT EXISTS match_throws (
    id BIGSERIAL PRIMARY KEY,
    match_id UUID NOT NULL,
    player_order INTEGER NOT NULL,
    turn_index INTEGER NOT NULL,
    throws INTEGER[] NOT NULL, -- Array of dart scores
    score_before INTEGER NOT NULL,
    score_after INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Composite unique constraint
    UNIQUE(match_id, player_order, turn_index)
);

-- Add game_metadata column
ALTER TABLE match_throws 
ADD COLUMN IF NOT EXISTS game_metadata JSONB DEFAULT '{}'::jsonb;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_match_throws_match_id ON match_throws(match_id);
CREATE INDEX IF NOT EXISTS idx_match_throws_game_metadata ON match_throws USING GIN (game_metadata);

-- Add comments for documentation
COMMENT ON TABLE match_throws IS 'Stores individual turns/throws for each match';
COMMENT ON COLUMN match_throws.match_id IS 'Foreign key to matches table';
COMMENT ON COLUMN match_throws.player_order IS 'Player position in match (0-indexed)';
COMMENT ON COLUMN match_throws.turn_index IS 'Turn number for this player';
COMMENT ON COLUMN match_throws.throws IS 'Array of dart scores for this turn';
COMMENT ON COLUMN match_throws.game_metadata IS 
'Game-specific data stored as JSON. Examples:
- Halve-It: {"target_display": "D20"}
- Cricket: {"marks": {"20": 3, "19": 2}, "closed": ["20"]}
- Around the Clock: {"current_target": 5}';

-- Verify the table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'match_throws'
ORDER BY ordinal_position;
