-- =====================================================
-- DanDarts Database Migration
-- Force fix RLS policies on users table for sign-up
-- =====================================================

-- First, let's see what policies exist (for debugging)
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    RAISE NOTICE 'Current policies on users table:';
    FOR policy_record IN 
        SELECT policyname, cmd 
        FROM pg_policies 
        WHERE tablename = 'users' AND schemaname = 'public'
    LOOP
        RAISE NOTICE '  - Policy: %, Command: %', policy_record.policyname, policy_record.cmd;
    END LOOP;
END $$;

-- Drop ALL existing policies on users table
DO $$
DECLARE
    policy_record RECORD;
BEGIN
    FOR policy_record IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'users' AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.users', policy_record.policyname);
        RAISE NOTICE 'Dropped policy: %', policy_record.policyname;
    END LOOP;
END $$;

-- Create fresh RLS policies for users table

-- 1. SELECT: Users can view their own profile
CREATE POLICY "Users can view their own profile"
    ON public.users
    FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

-- 2. INSERT: Users can create their own profile (critical for sign-up)
CREATE POLICY "Users can insert their own profile"
    ON public.users
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

-- 3. UPDATE: Users can update their own profile
CREATE POLICY "Users can update their own profile"
    ON public.users
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- 4. DELETE: Users can delete their own profile
CREATE POLICY "Users can delete their own profile"
    ON public.users
    FOR DELETE
    TO authenticated
    USING (auth.uid() = id);

-- Verify RLS is enabled
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Users table RLS policies completely reset!';
    RAISE NOTICE '✅ Users can now:';
    RAISE NOTICE '   - Create their own profile during sign-up';
    RAISE NOTICE '   - View their own profile';
    RAISE NOTICE '   - Update their own profile';
    RAISE NOTICE '   - Delete their own profile';
END $$;
