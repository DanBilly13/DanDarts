-- Add is_bust column to match_throws table for Knockout game
-- This tracks when a player loses a life (fails to beat the score)

BEGIN;

-- Add is_bust column (defaults to false for existing data)
ALTER TABLE match_throws 
ADD COLUMN IF NOT EXISTS is_bust BOOLEAN NOT NULL DEFAULT false;

-- Create index for querying busts
CREATE INDEX IF NOT EXISTS match_throws_is_bust_idx ON match_throws(is_bust) WHERE is_bust = true;

-- Verify the change
SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'match_throws' 
AND column_name = 'is_bust';

COMMIT;

-- Expected output: is_bust column with type boolean, default false, NOT NULL
