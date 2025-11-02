-- =====================================================
-- DanDarts Database Migration
-- Delete all test matches (clean slate for new schema)
-- =====================================================

-- Delete all matches (cascades to match_players and match_throws if they exist)
DELETE FROM public.matches;

-- Reset sequences if needed
-- (Not necessary for UUID primary keys, but good practice)

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ All test matches deleted!';
    RAISE NOTICE '✅ Database is now clean for production matches';
    RAISE NOTICE '✅ New matches will use the updated schema';
END $$;
