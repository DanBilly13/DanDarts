-- Delete all test matches from Supabase
-- Run this in Supabase SQL Editor to clean up old matches with incorrect player IDs

-- First, delete all match throws (child records)
DELETE FROM match_throws;

-- Then delete all matches
DELETE FROM matches;

-- Verify deletion
SELECT COUNT(*) as remaining_matches FROM matches;
SELECT COUNT(*) as remaining_throws FROM match_throws;
