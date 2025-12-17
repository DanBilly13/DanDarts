-- Delete ALL matches to start fresh
-- This will remove all match data including throws, players, and match records

BEGIN;

-- Count before deletion
SELECT 
    (SELECT COUNT(*) FROM matches) as total_matches,
    (SELECT COUNT(*) FROM match_players) as total_match_players,
    (SELECT COUNT(*) FROM match_throws) as total_match_throws;

-- Delete all match throws
DELETE FROM match_throws;

-- Delete all match players
DELETE FROM match_players;

-- Delete all matches
DELETE FROM matches;

-- Verify deletion
SELECT 
    (SELECT COUNT(*) FROM matches) as remaining_matches,
    (SELECT COUNT(*) FROM match_players) as remaining_match_players,
    (SELECT COUNT(*) FROM match_throws) as remaining_match_throws;

COMMIT;

-- Expected output: All counts should be 0
-- ✅ All match data successfully deleted
