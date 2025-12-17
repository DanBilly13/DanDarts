-- Diagnostic query to check the actual column type
SELECT 
    column_name,
    data_type,
    udt_name,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'match_throws' 
AND column_name = 'throws';

-- Also check a sample of actual data
SELECT 
    id,
    match_id,
    player_order,
    turn_index,
    pg_typeof(throws) as throws_type,
    throws
FROM match_throws
LIMIT 5;
