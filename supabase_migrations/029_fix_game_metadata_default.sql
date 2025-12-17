-- Fix: Remove the default value from game_metadata column
-- This default value is causing PostgREST to fail with "cannot extract elements from a scalar"

BEGIN;

-- Remove the default value from game_metadata
ALTER TABLE match_throws 
ALTER COLUMN game_metadata DROP DEFAULT;

-- Verify the change
SELECT 
    column_name,
    data_type,
    column_default
FROM information_schema.columns
WHERE table_name = 'match_throws' 
AND column_name = 'game_metadata';

COMMIT;

-- Expected output: column_default should be NULL (not '{}'::jsonb)
