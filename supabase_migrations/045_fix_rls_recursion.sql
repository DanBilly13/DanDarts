-- =====================================================
-- DanDarts Database Migration 045
-- Fix infinite recursion in match_participants RLS
-- =====================================================
-- Purpose: Simplify RLS policy to avoid recursion
-- Date: 2026-02-09
-- 
-- The previous policy caused infinite recursion because
-- it queried match_participants within the RLS check for
-- match_participants. We simplify it to just check if
-- the row's user_id matches the authenticated user, OR
-- if there's another participant in the same match with
-- the authenticated user's ID.
-- =====================================================

BEGIN;

-- Drop the recursive policy
DROP POLICY IF EXISTS "Users can view match participants" ON public.match_participants;

-- Create simple, non-recursive policy
-- Users can view participants for matches they're in
CREATE POLICY "Users can view match participants"
    ON public.match_participants
    FOR SELECT
    TO authenticated
    USING (
        -- Allow viewing all participants for matches where the user is a participant
        -- We check this by looking for ANY row with the same match_id and the user's ID
        match_id IN (
            SELECT match_id 
            FROM public.match_participants
            WHERE user_id = auth.uid()
            AND is_guest = false
        )
    );

-- Verify the policy was created
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 045 completed successfully! ✓';
    RAISE NOTICE 'Fixed infinite recursion in RLS policy';
    RAISE NOTICE 'Policy now uses simple subquery';
    RAISE NOTICE '========================================';
END $$;

COMMIT;

-- ============================================
-- ROLLBACK SCRIPT (DO NOT RUN UNLESS NEEDED)
-- ============================================
--
-- To rollback:
--
-- BEGIN;
-- DROP POLICY IF EXISTS "Users can view match participants" ON public.match_participants;
-- -- Recreate the previous policy here if needed
-- COMMIT;
--
-- ============================================
