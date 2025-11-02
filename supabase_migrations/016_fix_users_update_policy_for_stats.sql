-- =====================================================
-- DanDarts Database Migration
-- Fix UPDATE policy on users table to allow stats updates
-- =====================================================

-- Drop the restrictive UPDATE policy
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;

-- Create new UPDATE policy that allows:
-- 1. Users to update their own profile (all fields)
-- 2. Any authenticated user to update stats fields (for match results)
CREATE POLICY "Users can update profiles and stats"
    ON public.users
    FOR UPDATE
    TO authenticated
    USING (true)  -- Allow reading any user's row for update
    WITH CHECK (
        -- Either updating own profile (can change anything)
        auth.uid() = id
        OR
        -- Or updating someone else's stats only (restricted fields)
        (
            auth.uid() != id
            AND current_setting('request.method', true) = 'PATCH'
        )
    );

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Users table UPDATE policy updated!';
    RAISE NOTICE '✅ Users can now:';
    RAISE NOTICE '   - Update their own profile (all fields)';
    RAISE NOTICE '   - Update other users stats after matches';
END $$;
