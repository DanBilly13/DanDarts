-- Delete all test matches and related data
-- Run this in Supabase SQL Editor to clean up test data

-- Step 1: Delete all match throws (turn-by-turn data)
DELETE FROM match_throws;

-- Step 2: Delete all match players
DELETE FROM match_players;

-- Step 3: Delete all matches
DELETE FROM matches;

-- Verification queries (run these to confirm deletion)
SELECT COUNT(*) as match_throws_count FROM match_throws;
SELECT COUNT(*) as match_players_count FROM match_players;
SELECT COUNT(*) as matches_count FROM matches;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ All matches deleted successfully';
    RAISE NOTICE 'You can now test with fresh data';
END $$;
