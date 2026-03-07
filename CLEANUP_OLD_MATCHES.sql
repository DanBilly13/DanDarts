-- SQL Query to Delete All But Last 20 Matches for User
-- Run this in Supabase SQL Editor
-- User ID: 22978663-6c1a-4d48-a717-ba5f18e9a1bb

-- Step 1: View how many matches you have (optional check)
SELECT COUNT(*) as total_matches
FROM matches
WHERE challenger_id = '22978663-6c1a-4d48-a717-ba5f18e9a1bb'
   OR receiver_id = '22978663-6c1a-4d48-a717-ba5f18e9a1bb';

-- Step 2: Delete all but the last 20 matches
-- This keeps the 20 most recent matches based on created_at timestamp
WITH user_matches AS (
  SELECT id, created_at,
         ROW_NUMBER() OVER (ORDER BY created_at DESC) as row_num
  FROM matches
  WHERE challenger_id = '22978663-6c1a-4d48-a717-ba5f18e9a1bb'
     OR receiver_id = '22978663-6c1a-4d48-a717-ba5f18e9a1bb'
)
DELETE FROM matches
WHERE id IN (
  SELECT id FROM user_matches WHERE row_num > 20
);

-- Step 3: Verify the cleanup (optional check)
SELECT COUNT(*) as remaining_matches
FROM matches
WHERE challenger_id = '22978663-6c1a-4d48-a717-ba5f18e9a1bb'
   OR receiver_id = '22978663-6c1a-4d48-a717-ba5f18e9a1bb';

-- Alternative: Delete ALL matches for testing (use with caution!)
-- Uncomment the following lines if you want to delete everything:
/*
DELETE FROM matches
WHERE challenger_id = '22978663-6c1a-4d48-a717-ba5f18e9a1bb'
   OR receiver_id = '22978663-6c1a-4d48-a717-ba5f18e9a1bb';
*/
