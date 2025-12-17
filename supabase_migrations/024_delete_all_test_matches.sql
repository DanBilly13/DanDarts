-- Delete all test match data
-- WARNING: This will permanently delete all matches and their associated data

-- Step 1: Delete all match throws (turn-by-turn data)
DELETE FROM match_throws;

-- Step 2: Delete all match players
DELETE FROM match_players;

-- Step 3: Delete all matches
DELETE FROM matches;

-- Step 4: Verify deletion
DO $$
DECLARE
    match_count INT;
    player_count INT;
    throw_count INT;
BEGIN
    SELECT COUNT(*) INTO match_count FROM matches;
    SELECT COUNT(*) INTO player_count FROM match_players;
    SELECT COUNT(*) INTO throw_count FROM match_throws;
    
    RAISE NOTICE '✅ Deletion complete!';
    RAISE NOTICE 'Remaining matches: %', match_count;
    RAISE NOTICE 'Remaining match_players: %', player_count;
    RAISE NOTICE 'Remaining match_throws: %', throw_count;
    
    IF match_count = 0 AND player_count = 0 AND throw_count = 0 THEN
        RAISE NOTICE '✅ All match data successfully deleted';
    ELSE
        RAISE WARNING 'Some data remains - check foreign key constraints';
    END IF;
END $$;
