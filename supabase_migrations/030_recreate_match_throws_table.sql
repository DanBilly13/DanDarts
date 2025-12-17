-- Recreate match_throws table from scratch using the working test table structure
-- This will fix the PostgREST "cannot extract elements from a scalar" error

BEGIN;

-- Step 1: Rename old table as backup
ALTER TABLE match_throws RENAME TO match_throws_old_backup;

-- Step 2: Create new table with same structure as test table (which works)
CREATE TABLE match_throws (
    id BIGSERIAL PRIMARY KEY,
    match_id UUID NOT NULL,
    player_order INTEGER NOT NULL,
    turn_index INTEGER NOT NULL,
    throws INTEGER[] NOT NULL,
    score_before INTEGER NOT NULL,
    score_after INTEGER NOT NULL,
    game_metadata JSONB,  -- No default value
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(match_id, player_order, turn_index)
);

-- Step 3: Copy data from old table to new table
INSERT INTO match_throws (
    id, match_id, player_order, turn_index, throws, 
    score_before, score_after, game_metadata, created_at
)
SELECT 
    id, match_id, player_order, turn_index, throws,
    score_before, score_after, game_metadata, created_at
FROM match_throws_old_backup;

-- Step 4: Reset sequence to continue from max id
SELECT setval('match_throws_id_seq', (SELECT MAX(id) FROM match_throws));

-- Step 5: Create indexes
CREATE INDEX IF NOT EXISTS match_throws_match_id_idx ON match_throws(match_id);

-- Step 6: Grant permissions
GRANT ALL ON match_throws TO authenticated;
GRANT ALL ON match_throws TO anon;

-- Step 7: Verify the new table
SELECT 
    COUNT(*) as total_rows
FROM match_throws;

COMMIT;

-- After successful verification, you can drop the backup:
-- DROP TABLE match_throws_old_backup;
