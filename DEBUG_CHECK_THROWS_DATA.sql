-- Check what's actually stored in the throws column
-- Run this in Supabase SQL Editor to see the data format

SELECT 
    id,
    match_id,
    player_order,
    turn_index,
    throws,
    pg_typeof(throws) as throws_type,
    score_before,
    score_after
FROM match_throws
WHERE match_id = 'DF62F810-EA47-43BC-9FC2-0711A635CC10'
ORDER BY player_order, turn_index;

-- Also check if throws is stored as text or array
SELECT 
    column_name,
    data_type,
    udt_name
FROM information_schema.columns
WHERE table_name = 'match_throws' 
  AND column_name = 'throws';
