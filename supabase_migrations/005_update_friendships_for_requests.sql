-- =====================================================
-- DanDarts Database Migration
-- Update friendships table for friend request system
-- Task 300: Update Database Schema for Friend Requests
-- =====================================================

-- Step 1: Add updated_at column
ALTER TABLE public.friendships 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Step 2: Add requester_id and addressee_id columns
ALTER TABLE public.friendships 
ADD COLUMN IF NOT EXISTS requester_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS addressee_id UUID REFERENCES public.users(id) ON DELETE CASCADE;

-- Step 3: Update status enum to include 'blocked'
-- First, drop the existing constraint
ALTER TABLE public.friendships 
DROP CONSTRAINT IF EXISTS friendships_status_check;

-- Add new constraint with 'blocked' status
ALTER TABLE public.friendships 
ADD CONSTRAINT friendships_status_check 
CHECK (status IN ('pending', 'accepted', 'rejected', 'blocked'));

-- Step 4: Migrate existing data
-- For existing friendships, set requester_id = user_id and addressee_id = friend_id
UPDATE public.friendships 
SET 
    requester_id = user_id,
    addressee_id = friend_id,
    updated_at = created_at
WHERE requester_id IS NULL OR addressee_id IS NULL;

-- Step 5: Make requester_id and addressee_id NOT NULL after migration
ALTER TABLE public.friendships 
ALTER COLUMN requester_id SET NOT NULL,
ALTER COLUMN addressee_id SET NOT NULL;

-- Step 6: Create indexes for new columns
CREATE INDEX IF NOT EXISTS friendships_requester_id_idx ON public.friendships(requester_id);
CREATE INDEX IF NOT EXISTS friendships_addressee_id_idx ON public.friendships(addressee_id);
CREATE INDEX IF NOT EXISTS friendships_updated_at_idx ON public.friendships(updated_at);

-- Step 7: Create trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_friendships_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS friendships_updated_at_trigger ON public.friendships;

CREATE TRIGGER friendships_updated_at_trigger
    BEFORE UPDATE ON public.friendships
    FOR EACH ROW
    EXECUTE FUNCTION update_friendships_updated_at();

-- Step 8: Update RLS policies for pending requests
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
    USING (
        auth.uid() = requester_id OR 
        auth.uid() = addressee_id OR
        auth.uid() = user_id OR 
        auth.uid() = friend_id
    );

-- RLS Policy: Users can create friendships where they are the requester
CREATE POLICY "Users can create their own friendships"
    ON public.friendships
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = requester_id);

-- RLS Policy: Users can update friendships where they are requester or addressee
-- (e.g., addressee can accept/reject, requester can withdraw)
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

-- Step 9: Add unique constraint on (requester_id, addressee_id)
-- This prevents duplicate requests in the same direction
CREATE UNIQUE INDEX IF NOT EXISTS friendships_requester_addressee_unique 
ON public.friendships(requester_id, addressee_id);

-- Step 10: Add comment to table for documentation
COMMENT ON TABLE public.friendships IS 'Manages friend relationships including pending requests, accepted friendships, and blocked users';
COMMENT ON COLUMN public.friendships.requester_id IS 'User who initiated the friend request';
COMMENT ON COLUMN public.friendships.addressee_id IS 'User who received the friend request';
COMMENT ON COLUMN public.friendships.status IS 'Status: pending (awaiting response), accepted (friends), rejected (declined), blocked (user blocked)';
COMMENT ON COLUMN public.friendships.created_at IS 'When the friendship/request was created';
COMMENT ON COLUMN public.friendships.updated_at IS 'When the friendship/request was last updated';

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Friendships table updated successfully for friend request system!';
    RAISE NOTICE 'New fields: requester_id, addressee_id, updated_at';
    RAISE NOTICE 'Updated status enum to include: pending, accepted, rejected, blocked';
    RAISE NOTICE 'RLS policies updated for request workflow';
END $$;
