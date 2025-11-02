-- =====================================================
-- DanDarts Database Migration
-- Fix RLS policy on users table to allow sign-up
-- =====================================================

-- Drop existing INSERT policy
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
DROP POLICY IF EXISTS "Authenticated users can insert their profile" ON public.users;

-- Create new INSERT policy that allows users to create their own profile during sign-up
-- This checks that the user_id in the row matches the authenticated user's ID
CREATE POLICY "Users can insert their own profile"
    ON public.users
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Users table RLS policy updated for sign-up!';
    RAISE NOTICE 'Users can now create their own profile during sign-up';
END $$;
