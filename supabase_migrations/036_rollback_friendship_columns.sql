-- =====================================================
-- DanDarts Database Migration ROLLBACK
-- Restore old friendship columns (user_id, friend_id)
-- Migration 036 Rollback: Restore Previous State
-- =====================================================

-- WARNING: This rollback script restores the old columns
-- Only run this if migration 036 caused issues

-- Step 1: Add back old columns
ALTER TABLE public.friendships 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS friend_id UUID REFERENCES public.users(id) ON DELETE CASCADE;

DO $$
BEGIN
    RAISE NOTICE '✅ Old columns (user_id, friend_id) restored';
END $$;

-- Step 2: Copy data from new columns to old columns
UPDATE public.friendships 
SET 
    user_id = requester_id,
    friend_id = addressee_id
WHERE user_id IS NULL OR friend_id IS NULL;

DO $$
BEGIN
    RAISE NOTICE '✅ Data copied from requester_id/addressee_id to user_id/friend_id';
END $$;

-- Step 3: Restore old indexes
CREATE INDEX IF NOT EXISTS friendships_user_id_idx ON public.friendships(user_id);
CREATE INDEX IF NOT EXISTS friendships_friend_id_idx ON public.friendships(friend_id);

DO $$
BEGIN
    RAISE NOTICE '✅ Old indexes restored';
END $$;

-- Step 4: Restore old unique constraint
CREATE UNIQUE INDEX IF NOT EXISTS unique_friendship 
ON public.friendships(user_id, friend_id);

DO $$
BEGIN
    RAISE NOTICE '✅ Old unique constraint restored';
END $$;

-- Step 5: Update RLS policies to include both old and new columns
-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own friendships" ON public.friendships;
DROP POLICY IF EXISTS "Users can create their own friendships" ON public.friendships;
DROP POLICY IF EXISTS "Users can update their own friendships" ON public.friendships;
DROP POLICY IF EXISTS "Users can delete their own friendships" ON public.friendships;

-- RLS Policy: Users can view friendships (supports both old and new columns)
CREATE POLICY "Users can view their own friendships"
    ON public.friendships
    FOR SELECT
    TO authenticated
    USING (
        auth.uid() = requester_id OR 
        auth.uid() = addressee_id OR
        auth.uid() = user_id OR 
        auth.uid() = friend_id
    );

-- RLS Policy: Users can create friendships (supports both old and new columns)
CREATE POLICY "Users can create their own friendships"
    ON public.friendships
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = requester_id OR auth.uid() = user_id);

-- RLS Policy: Users can update friendships (supports both old and new columns)
CREATE POLICY "Users can update their own friendships"
    ON public.friendships
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id OR auth.uid() = user_id OR auth.uid() = friend_id)
    WITH CHECK (auth.uid() = requester_id OR auth.uid() = addressee_id OR auth.uid() = user_id OR auth.uid() = friend_id);

-- RLS Policy: Users can delete friendships (supports both old and new columns)
CREATE POLICY "Users can delete their own friendships"
    ON public.friendships
    FOR DELETE
    TO authenticated
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id OR auth.uid() = user_id);

DO $$
BEGIN
    RAISE NOTICE '✅ RLS policies restored to support both old and new columns';
END $$;

-- VERIFICATION: Print final row count
DO $$
DECLARE
    row_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO row_count FROM public.friendships;
    RAISE NOTICE '📊 Final friendships count: %', row_count;
    RAISE NOTICE '✅ Rollback completed successfully!';
    RAISE NOTICE '⚠️  Old columns restored, but realtime may still have issues';
END $$;
