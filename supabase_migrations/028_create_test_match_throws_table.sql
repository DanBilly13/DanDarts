-- Create a test table to verify INTEGER[] arrays work with PostgREST
-- This is a parallel table to test without affecting existing data

CREATE TABLE IF NOT EXISTS match_throws_test (
    id BIGSERIAL PRIMARY KEY,
    match_id UUID NOT NULL,
    player_order INTEGER NOT NULL,
    turn_index INTEGER NOT NULL,
    throws INTEGER[] NOT NULL,  -- Native PostgreSQL array
    score_before INTEGER NOT NULL,
    score_after INTEGER NOT NULL,
    game_metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(match_id, player_order, turn_index)
);

-- Create index
CREATE INDEX IF NOT EXISTS match_throws_test_match_id_idx ON match_throws_test(match_id);

-- Grant permissions
GRANT ALL ON match_throws_test TO authenticated;
GRANT ALL ON match_throws_test TO anon;

-- Insert a test row
INSERT INTO match_throws_test (
    match_id,
    player_order,
    turn_index,
    throws,
    score_before,
    score_after,
    game_metadata
) VALUES (
    gen_random_uuid(),
    0,
    1,
    ARRAY[5, 0, 0],  -- Native array syntax
    301,
    296,
    '{"target_display": "5"}'::jsonb
);

-- Verify the test data
SELECT 
    id,
    match_id,
    throws,
    pg_typeof(throws) as throws_type,
    game_metadata
FROM match_throws_test;

-- Expected output: throws = {5,0,0}, throws_type = integer[]
