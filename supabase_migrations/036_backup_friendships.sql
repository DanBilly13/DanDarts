-- =====================================================
-- DanDarts Database Backup
-- Export friendships table data before migration 036
-- =====================================================

-- Run this query in Supabase SQL Editor and save the results
-- This creates a backup of your friendships data

SELECT 
    id,
    requester_id,
    addressee_id,
    user_id,
    friend_id,
    status,
    created_at,
    updated_at
FROM public.friendships
ORDER BY created_at DESC;

-- Copy the results and save them somewhere safe before running migration 036
