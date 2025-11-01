-- =====================================================
-- DanDarts Database Migration
-- Add started_at and ended_at columns to matches table
-- =====================================================

-- Add new timestamp columns
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS ended_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS game_id TEXT;

-- Migrate existing data: copy timestamp to both started_at and ended_at
UPDATE public.matches 
SET 
    started_at = timestamp,
    ended_at = timestamp,
    game_id = game_type
WHERE started_at IS NULL;

-- Make started_at and ended_at NOT NULL after migration
ALTER TABLE public.matches 
ALTER COLUMN started_at SET NOT NULL,
ALTER COLUMN ended_at SET NOT NULL;

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS matches_started_at_idx ON public.matches(started_at DESC);
CREATE INDEX IF NOT EXISTS matches_ended_at_idx ON public.matches(ended_at DESC);
CREATE INDEX IF NOT EXISTS matches_game_id_idx ON public.matches(game_id);

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Match timestamp columns added successfully!';
END $$;
