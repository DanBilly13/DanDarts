-- Create a PostgreSQL function to fetch match throws
-- This bypasses PostgREST's query builder which is causing the array operator error

CREATE OR REPLACE FUNCTION get_match_throws(match_uuid UUID)
RETURNS TABLE (
    id BIGINT,
    match_id UUID,
    player_order INTEGER,
    turn_index INTEGER,
    throws INTEGER[],
    score_before INTEGER,
    score_after INTEGER,
    game_metadata JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        mt.id,
        mt.match_id,
        mt.player_order,
        mt.turn_index,
        mt.throws,
        mt.score_before,
        mt.score_after,
        mt.game_metadata
    FROM match_throws mt
    WHERE mt.match_id = match_uuid
    ORDER BY mt.player_order, mt.turn_index;
END;
$$ LANGUAGE plpgsql STABLE;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_match_throws(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_match_throws(UUID) TO anon;

-- Test the function
SELECT * FROM get_match_throws('694e15f5-84a3-436e-9737-88f45c943dd6'::UUID) LIMIT 3;
