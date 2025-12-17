-- Fix throws column to use JSONB instead of INTEGER[]
-- This is more compatible with Supabase's REST API encoding

-- Step 1: Add new column with JSONB type
ALTER TABLE match_throws 
ADD COLUMN throws_jsonb JSONB;

-- Step 2: Migrate existing data (if any valid data exists)
-- Convert INTEGER[] to JSONB array
UPDATE match_throws 
SET throws_jsonb = to_jsonb(throws)
WHERE throws IS NOT NULL 
  AND array_length(throws, 1) IS NOT NULL;

-- Step 3: Drop old column
ALTER TABLE match_throws 
DROP COLUMN throws;

-- Step 4: Rename new column to throws
ALTER TABLE match_throws 
RENAME COLUMN throws_jsonb TO throws;

-- Step 5: Add NOT NULL constraint
ALTER TABLE match_throws 
ALTER COLUMN throws SET NOT NULL;

-- Step 6: Create GIN index for JSONB queries (optional but recommended)
CREATE INDEX IF NOT EXISTS match_throws_throws_idx ON match_throws USING GIN (throws);

-- Verification
DO $$
BEGIN
    RAISE NOTICE '✅ throws column converted from INTEGER[] to JSONB';
    RAISE NOTICE 'This is more compatible with Supabase REST API';
END $$;
