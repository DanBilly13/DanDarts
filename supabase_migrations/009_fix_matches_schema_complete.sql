-- =====================================================
-- DanDarts Database Migration
-- Complete fix for matches table schema
-- =====================================================

-- First, drop the NOT NULL constraints temporarily
ALTER TABLE public.matches 
ALTER COLUMN started_at DROP NOT NULL,
ALTER COLUMN ended_at DROP NOT NULL;

-- Add metadata column if it doesn't exist
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS metadata JSONB;

-- Ensure all columns exist
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS ended_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS game_id TEXT;

-- Migrate existing data
UPDATE public.matches 
SET 
    started_at = COALESCE(started_at, timestamp, now()),
    ended_at = COALESCE(ended_at, timestamp, now()),
    game_id = COALESCE(game_id, game_type),
    metadata = COALESCE(metadata, '{}'::jsonb)
WHERE started_at IS NULL OR ended_at IS NULL OR game_id IS NULL OR metadata IS NULL;

-- Now make them NOT NULL
ALTER TABLE public.matches 
ALTER COLUMN started_at SET NOT NULL,
ALTER COLUMN ended_at SET NOT NULL,
ALTER COLUMN game_id SET NOT NULL;

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS matches_started_at_idx ON public.matches(started_at DESC);
CREATE INDEX IF NOT EXISTS matches_ended_at_idx ON public.matches(ended_at DESC);
CREATE INDEX IF NOT EXISTS matches_game_id_idx ON public.matches(game_id);
CREATE INDEX IF NOT EXISTS matches_metadata_idx ON public.matches USING GIN (metadata);

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Matches table schema fixed successfully!';
END $$;
