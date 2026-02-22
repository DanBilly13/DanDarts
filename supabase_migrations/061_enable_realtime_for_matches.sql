-- =====================================================
-- Enable Realtime for Matches Table
-- =====================================================
-- This migration enables proper Supabase Realtime functionality
-- for the matches table by:
-- 1. Adding it to the supabase_realtime publication
-- 2. Setting REPLICA IDENTITY FULL
-- 
-- Without these, realtime subscriptions will immediately unsubscribe
-- and callbacks won't receive full row data
-- =====================================================

-- Add matches table to supabase_realtime publication
-- This is CRITICAL - without this, the channel immediately unsubscribes
ALTER PUBLICATION supabase_realtime ADD TABLE public.matches;

-- Enable REPLICA IDENTITY FULL for matches table
-- This ensures realtime callbacks receive complete row data
ALTER TABLE public.matches REPLICA IDENTITY FULL;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Realtime enabled for matches table';
    RAISE NOTICE '✅ Added to supabase_realtime publication';
    RAISE NOTICE '✅ Set REPLICA IDENTITY FULL';
END $$;
