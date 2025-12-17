-- Force conversion of throws column to JSONB
-- This handles the case where the column might be in an inconsistent state

-- Step 1: Check current state and drop any existing throws_jsonb column
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'match_throws' AND column_name = 'throws_jsonb'
    ) THEN
        ALTER TABLE match_throws DROP COLUMN throws_jsonb;
        RAISE NOTICE 'Dropped existing throws_jsonb column';
    END IF;
END $$;

-- Step 2: Add new JSONB column
ALTER TABLE match_throws ADD COLUMN throws_jsonb JSONB;

-- Step 3: Migrate data based on current type
DO $$
DECLARE
    current_type TEXT;
BEGIN
    -- Get the actual UDT name (underlying data type)
    SELECT udt_name INTO current_type
    FROM information_schema.columns
    WHERE table_name = 'match_throws' AND column_name = 'throws';
    
    RAISE NOTICE 'Current throws column type: %', current_type;
    
    -- If it's an integer array (_int4 is the UDT name for integer[])
    IF current_type = '_int4' THEN
        RAISE NOTICE 'Converting from INTEGER[] to JSONB...';
        UPDATE match_throws 
        SET throws_jsonb = to_jsonb(throws)
        WHERE throws IS NOT NULL;
    
    -- If it's already jsonb
    ELSIF current_type = 'jsonb' THEN
        RAISE NOTICE 'Already JSONB, copying data...';
        UPDATE match_throws 
        SET throws_jsonb = throws;
    
    -- Unknown type
    ELSE
        RAISE EXCEPTION 'Unexpected column type: %', current_type;
    END IF;
END $$;

-- Step 4: Drop old column
ALTER TABLE match_throws DROP COLUMN throws;

-- Step 5: Rename new column
ALTER TABLE match_throws RENAME COLUMN throws_jsonb TO throws;

-- Step 6: Add NOT NULL constraint
ALTER TABLE match_throws ALTER COLUMN throws SET NOT NULL;

-- Step 7: Create GIN index
DROP INDEX IF EXISTS match_throws_throws_idx;
CREATE INDEX match_throws_throws_idx ON match_throws USING GIN (throws);

-- Step 8: Verify final state
DO $$
DECLARE
    final_type TEXT;
BEGIN
    SELECT udt_name INTO final_type
    FROM information_schema.columns
    WHERE table_name = 'match_throws' AND column_name = 'throws';
    
    RAISE NOTICE '✅ Migration complete! Final type: %', final_type;
    
    IF final_type != 'jsonb' THEN
        RAISE EXCEPTION 'Migration failed - column is not JSONB!';
    END IF;
END $$;
