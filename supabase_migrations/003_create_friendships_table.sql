-- =====================================================
-- DanDarts Database Migration
-- Create friendships table for managing friend relationships
-- =====================================================

-- Create friendships table
CREATE TABLE IF NOT EXISTS public.friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'rejected')) DEFAULT 'accepted',
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT unique_friendship UNIQUE (user_id, friend_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS friendships_user_id_idx ON public.friendships(user_id);
CREATE INDEX IF NOT EXISTS friendships_friend_id_idx ON public.friendships(friend_id);
CREATE INDEX IF NOT EXISTS friendships_status_idx ON public.friendships(status);

-- Enable Row Level Security
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own friendships" ON public.friendships;
DROP POLICY IF EXISTS "Users can create their own friendships" ON public.friendships;
DROP POLICY IF EXISTS "Users can update their own friendships" ON public.friendships;
DROP POLICY IF EXISTS "Users can delete their own friendships" ON public.friendships;

-- RLS Policy: Users can view their own friendships
CREATE POLICY "Users can view their own friendships"
    ON public.friendships
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- RLS Policy: Users can create their own friendships
CREATE POLICY "Users can create their own friendships"
    ON public.friendships
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- RLS Policy: Users can update their own friendships
CREATE POLICY "Users can update their own friendships"
    ON public.friendships
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id OR auth.uid() = friend_id)
    WITH CHECK (auth.uid() = user_id OR auth.uid() = friend_id);

-- RLS Policy: Users can delete their own friendships
CREATE POLICY "Users can delete their own friendships"
    ON public.friendships
    FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- Grant permissions
GRANT ALL ON public.friendships TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Friendships table created successfully!';
END $$;
