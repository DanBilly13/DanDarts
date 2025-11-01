-- =====================================================
-- DanDarts Database Migration
-- Final fix for matches table - make old columns nullable
-- =====================================================

-- Make old columns nullable (they're being replaced by new columns)
ALTER TABLE public.matches 
ALTER COLUMN game_type DROP NOT NULL,
ALTER COLUMN game_name DROP NOT NULL,
ALTER COLUMN winner_id DROP NOT NULL,
ALTER COLUMN duration DROP NOT NULL;

-- Set defaults for old columns from new columns
UPDATE public.matches 
SET 
    game_type = COALESCE(game_type, game_id, 'unknown'),
    game_name = COALESCE(game_name, game_id, 'Unknown Game'),
    duration = COALESCE(duration, EXTRACT(EPOCH FROM (ended_at - started_at))::INTEGER, 0)
WHERE game_type IS NULL OR game_name IS NULL OR duration IS NULL;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Matches table old columns made nullable!';
END $$;
