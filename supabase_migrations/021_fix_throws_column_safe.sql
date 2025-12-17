-- Safe migration to fix throws column type
-- Handles both INTEGER[] and JSONB cases

-- Check if throws column is already JSONB
DO $$
DECLARE
    column_type TEXT;
BEGIN
    -- Get the current data type of the throws column
    SELECT data_type INTO column_type
    FROM information_schema.columns
    WHERE table_name = 'match_throws' 
    AND column_name = 'throws';
    
    -- If it's already jsonb, we're done
    IF column_type = 'jsonb' THEN
        RAISE NOTICE '✅ throws column is already JSONB - no migration needed';
    
    -- If it's an array, convert it
    ELSIF column_type = 'ARRAY' THEN
        RAISE NOTICE '🔄 Converting throws column from INTEGER[] to JSONB...';
        
        -- Step 1: Add new column with JSONB type
        ALTER TABLE match_throws ADD COLUMN throws_jsonb JSONB;
        
        -- Step 2: Migrate existing data
        UPDATE match_throws 
        SET throws_jsonb = to_jsonb(throws)
        WHERE throws IS NOT NULL 
          AND array_length(throws, 1) IS NOT NULL;
        
        -- Step 3: Drop old column
        ALTER TABLE match_throws DROP COLUMN throws;
        
        -- Step 4: Rename new column to throws
        ALTER TABLE match_throws RENAME COLUMN throws_jsonb TO throws;
        
        -- Step 5: Add NOT NULL constraint
        ALTER TABLE match_throws ALTER COLUMN throws SET NOT NULL;
        
        -- Step 6: Create GIN index for JSONB queries
        CREATE INDEX IF NOT EXISTS match_throws_throws_idx ON match_throws USING GIN (throws);
        
        RAISE NOTICE '✅ throws column converted from INTEGER[] to JSONB';
    
    ELSE
        RAISE EXCEPTION 'Unexpected column type: %', column_type;
    END IF;
END $$;
