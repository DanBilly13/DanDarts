-- =====================================================
-- DanDarts Database Migration
-- Drop old friendship columns (user_id, friend_id)
-- Migration 036: Fix Realtime Subscriptions
-- =====================================================

-- SAFETY CHECK: Verify data exists in new columns before dropping old ones
DO $$
DECLARE
    null_count INTEGER;
BEGIN
    -- Check if any rows have NULL in new columns
    SELECT COUNT(*) INTO null_count
    FROM public.friendships
    WHERE requester_id IS NULL OR addressee_id IS NULL;
    
    IF null_count > 0 THEN
        RAISE EXCEPTION 'MIGRATION ABORTED: Found % rows with NULL in requester_id or addressee_id. Run migration 005 first.', null_count;
    END IF;
    
    RAISE NOTICE '✅ Safety check passed: All rows have requester_id and addressee_id populated';
END $$;

-- BACKUP INFO: Print current row count for verification
DO $$
DECLARE
    row_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO row_count FROM public.friendships;
    RAISE NOTICE '📊 Current friendships count: %', row_count;
END $$;

-- Step 1: Update RLS policies to remove references to old columns
-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own friendships" ON public.friendships;
DROP POLICY IF EXISTS "Users can create their own friendships" ON public.friendships;
DROP POLICY IF EXISTS "Users can update their own friendships" ON public.friendships;
DROP POLICY IF EXISTS "Users can delete their own friendships" ON public.friendships;

-- RLS Policy: Users can view friendships where they are requester or addressee
CREATE POLICY "Users can view their own friendships"
    ON public.friendships
    FOR SELECT
    TO authenticated
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- RLS Policy: Users can create friendships where they are the requester
CREATE POLICY "Users can create their own friendships"
    ON public.friendships
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = requester_id);

-- RLS Policy: Users can update friendships where they are requester or addressee
CREATE POLICY "Users can update their own friendships"
    ON public.friendships
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id)
    WITH CHECK (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- RLS Policy: Users can delete friendships where they are requester or addressee
CREATE POLICY "Users can delete their own friendships"
    ON public.friendships
    FOR DELETE
    TO authenticated
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

DO $$
BEGIN
    RAISE NOTICE '✅ RLS policies updated to use only requester_id and addressee_id';
END $$;

-- Step 2: Drop old indexes
DROP INDEX IF EXISTS public.friendships_user_id_idx;
DROP INDEX IF EXISTS public.friendships_friend_id_idx;

DO $$
BEGIN
    RAISE NOTICE '✅ Old indexes dropped';
END $$;

-- Step 3: Drop old unique constraint
ALTER TABLE public.friendships 
DROP CONSTRAINT IF EXISTS unique_friendship;

DO $$
BEGIN
    RAISE NOTICE '✅ Old unique constraint dropped';
END $$;

-- Step 4: Drop old columns
ALTER TABLE public.friendships 
DROP COLUMN IF EXISTS user_id,
DROP COLUMN IF EXISTS friend_id;

DO $$
BEGIN
    RAISE NOTICE '✅ Old columns (user_id, friend_id) dropped';
END $$;

-- Step 5: Verify new indexes exist
CREATE INDEX IF NOT EXISTS friendships_requester_id_idx ON public.friendships(requester_id);
CREATE INDEX IF NOT EXISTS friendships_addressee_id_idx ON public.friendships(addressee_id);
CREATE INDEX IF NOT EXISTS friendships_status_idx ON public.friendships(status);
CREATE INDEX IF NOT EXISTS friendships_updated_at_idx ON public.friendships(updated_at);

DO $$
BEGIN
    RAISE NOTICE '✅ Verified indexes on new columns';
END $$;

-- Step 6: Verify unique constraint exists
CREATE UNIQUE INDEX IF NOT EXISTS friendships_requester_addressee_unique 
ON public.friendships(requester_id, addressee_id);

DO $$
BEGIN
    RAISE NOTICE '✅ Verified unique constraint on (requester_id, addressee_id)';
END $$;

-- VERIFICATION: Print final row count
DO $$
DECLARE
    row_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO row_count FROM public.friendships;
    RAISE NOTICE '📊 Final friendships count: %', row_count;
    RAISE NOTICE '✅ Migration 036 completed successfully!';
    RAISE NOTICE '🔔 Realtime subscriptions should now work with requester_id/addressee_id filters';
END $$;
