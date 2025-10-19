-- =====================================================
-- DanDarts Database Migration
-- Create users table and related policies
-- =====================================================

-- Create users table
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    nickname TEXT UNIQUE NOT NULL,
    handle TEXT UNIQUE,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    last_seen_at TIMESTAMP WITH TIME ZONE,
    total_wins INTEGER DEFAULT 0,
    total_losses INTEGER DEFAULT 0
);

-- Create indexes for performance
CREATE UNIQUE INDEX IF NOT EXISTS users_nickname_idx ON public.users(nickname);
CREATE INDEX IF NOT EXISTS users_display_name_idx ON public.users(display_name);

-- Enable Row Level Security
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for re-running migration)
DROP POLICY IF EXISTS "Users can view all profiles" ON public.users;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;

-- RLS Policy: Allow users to read all profiles (for friend search)
CREATE POLICY "Users can view all profiles"
    ON public.users
    FOR SELECT
    USING (true);

-- RLS Policy: Allow users to insert their own profile
CREATE POLICY "Users can insert own profile"
    ON public.users
    FOR INSERT
    WITH CHECK (auth.uid() = id);

-- RLS Policy: Allow users to update their own profile
CREATE POLICY "Users can update own profile"
    ON public.users
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Users table created successfully!';
END $$;
