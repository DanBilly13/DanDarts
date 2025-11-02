-- =====================================================
-- DanDarts Database Migration
-- Fix matches table columns to be nullable
-- =====================================================

-- Make the new columns nullable so old code can still insert matches
ALTER TABLE public.matches
    ALTER COLUMN started_at DROP NOT NULL,
    ALTER COLUMN ended_at DROP NOT NULL,
    ALTER COLUMN game_id DROP NOT NULL;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Matches table columns are now nullable!';
    RAISE NOTICE '✅ Old and new code can both insert matches';
END $$;
