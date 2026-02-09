-- Verification query to test the fixed RLS policy

-- 1. Check the current RLS policy definition
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE tablename = 'match_participants';

-- 2. Test query that should now work (simulates what the app does)
-- This query should return match_id values without error
SELECT match_id
FROM match_participants
WHERE user_id = '22978663-6c1a-4d48-a717-ba5f18e9a1bb'
AND is_guest = false
LIMIT 5;

-- 3. Count total participants for this user
SELECT COUNT(*) as total_matches
FROM match_participants
WHERE user_id = '22978663-6c1a-4d48-a717-ba5f18e9a1bb'
AND is_guest = false;

-- 4. Test the head-to-head query (what the app actually runs)
-- Find matches where both users participated
SELECT mp1.match_id
FROM match_participants mp1
WHERE mp1.user_id = '22978663-6c1a-4d48-a717-ba5f18e9a1bb'
AND mp1.is_guest = false
AND EXISTS (
    SELECT 1 FROM match_participants mp2
    WHERE mp2.match_id = mp1.match_id
    AND mp2.user_id = '5db0ec59-64b3-402f-9b9e-beb4b1e8e0c1'
    AND mp2.is_guest = false
)
LIMIT 10;
