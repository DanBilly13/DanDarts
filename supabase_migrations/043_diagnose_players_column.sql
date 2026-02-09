-- Diagnostic script to understand the players column structure

-- Check the actual column type
SELECT 
    column_name,
    data_type,
    udt_name
FROM information_schema.columns
WHERE table_name = 'matches' 
AND column_name = 'players';

-- Sample a few rows to see the actual data
SELECT 
    id,
    game_name,
    players,
    pg_typeof(players) as players_type
FROM public.matches
LIMIT 5;

-- Try to see if it's stored as TEXT
SELECT 
    id,
    game_name,
    length(players::text) as players_length,
    left(players::text, 100) as players_sample
FROM public.matches
LIMIT 3;
