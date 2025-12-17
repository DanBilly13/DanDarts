-- Check what the actual data looks like in the new matches
SELECT 
    id,
    match_id,
    player_order,
    turn_index,
    throws,
    jsonb_typeof(throws) as jsonb_type,
    jsonb_array_length(throws) as array_length
FROM match_throws
WHERE match_id IN ('694e15f5-84a3-436e-9737-88f45c943dd6', '8eed10b7-d901-4776-99d3-ae18527b0191')
ORDER BY match_id, player_order, turn_index
LIMIT 10;
