-- Debug the new matches that are failing
-- Check what's actually in the database

-- Check the Halve-It match
SELECT 
    id,
    match_id,
    player_order,
    turn_index,
    throws,
    pg_typeof(throws) as throws_type,
    score_before,
    score_after,
    game_metadata
FROM match_throws
WHERE match_id = '694e15f5-84a3-436e-9737-88f45c943dd6'
ORDER BY player_order, turn_index
LIMIT 5;

-- Check the Knockout match
SELECT 
    id,
    match_id,
    player_order,
    turn_index,
    throws,
    pg_typeof(throws) as throws_type,
    score_before,
    score_after,
    game_metadata
FROM match_throws
WHERE match_id = '8eed10b7-d901-4776-99d3-ae18527b0191'
ORDER BY player_order, turn_index
LIMIT 5;

-- Check the column type
SELECT column_name, data_type, udt_name
FROM information_schema.columns
WHERE table_name = 'match_throws' AND column_name = 'throws';
