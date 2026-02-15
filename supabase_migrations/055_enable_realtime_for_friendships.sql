-- =====================================================
-- Enable Realtime for Friendships Table
-- =====================================================
-- This migration enables proper Supabase Realtime functionality
-- for the friendships table by setting REPLICA IDENTITY FULL
-- 
-- Without this, realtime callbacks don't receive full row data
-- and may not trigger properly for INSERT/UPDATE/DELETE events
-- =====================================================

-- Enable REPLICA IDENTITY FULL for friendships table
-- This ensures realtime callbacks receive complete row data
ALTER TABLE public.friendships REPLICA IDENTITY FULL;

-- Note: friendships table is already in supabase_realtime publication
-- We only need to set REPLICA IDENTITY FULL for callbacks to work properly

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Realtime enabled for friendships table with REPLICA IDENTITY FULL';
    RAISE NOTICE '✅ Table was already in supabase_realtime publication';
END $$;
