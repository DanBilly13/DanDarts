-- Check if the actual data format is different between tables

-- Check main table data
SELECT 
    'match_throws' as table_name,
    id,
    throws,
    pg_typeof(throws) as throws_type,
    array_length(throws, 1) as array_length,
    game_metadata,
    pg_typeof(game_metadata) as metadata_type
FROM match_throws
LIMIT 3;

-- Check test table data
SELECT 
    'match_throws_test' as table_name,
    id,
    throws,
    pg_typeof(throws) as throws_type,
    game_metadata,
    pg_typeof(game_metadata) as metadata_type
FROM match_throws_test
LIMIT 3;
