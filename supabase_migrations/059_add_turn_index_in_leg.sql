-- Migration: Add turn_index_in_leg to matches table
-- Purpose: Track current visit/turn number in a leg for remote matches
-- This enables server-authoritative VISIT counter display on both devices

-- Add turn_index_in_leg column (0-indexed, increments with each saved visit)
ALTER TABLE public.matches
ADD COLUMN IF NOT EXISTS turn_index_in_leg INTEGER DEFAULT 0;

-- Add comment
COMMENT ON COLUMN public.matches.turn_index_in_leg IS 
'Current turn index within the leg (0-indexed). Increments with each saved visit. Used for VISIT counter in UI (display as turn_index_in_leg + 1).';

-- Create index for efficient queries
CREATE INDEX IF NOT EXISTS idx_matches_turn_index_in_leg 
ON public.matches(turn_index_in_leg) 
WHERE remote_status = 'in_progress';

-- Backfill existing remote matches to 0 (if any exist without this field)
UPDATE public.matches
SET turn_index_in_leg = 0
WHERE turn_index_in_leg IS NULL 
  AND match_mode = 'remote';
