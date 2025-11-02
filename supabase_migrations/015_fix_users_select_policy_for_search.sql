-- =====================================================
-- DanDarts Database Migration
-- Fix SELECT policy on users table to allow friend search
-- =====================================================

-- Drop the restrictive SELECT policy
DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can view all profiles" ON public.users;

-- Create SELECT policy that allows viewing ALL profiles (required for friend search)
CREATE POLICY "Users can view all profiles"
    ON public.users
    FOR SELECT
    TO authenticated
    USING (true);

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Users table SELECT policy updated!';
    RAISE NOTICE '✅ Users can now search for and view all profiles';
END $$;
