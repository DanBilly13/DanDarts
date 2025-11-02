-- =====================================================
-- Fix RLS Policy for Matches Table
-- Resolves "cannot extract elements from a scalar" error
-- =====================================================

-- Drop the existing problematic policy
DROP POLICY IF EXISTS "Users can view their own matches" ON public.matches;

-- Create a new policy that safely handles the players JSONB field
-- This version checks if the user is the winner OR uses a safer JSONB check
CREATE POLICY "Users can view their own matches"
    ON public.matches
    FOR SELECT
    TO authenticated
    USING (
        -- Check if user is the winner
        winner_id = auth.uid()
        OR
        -- Safely check if user is in the players array
        -- Using jsonb_path_exists which is more robust
        jsonb_path_exists(
            players,
            '$[*].id ? (@ == $user_id)',
            jsonb_build_object('user_id', auth.uid()::text)
        )
    );

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'RLS policy fixed successfully!';
    RAISE NOTICE 'Users can now view matches where they are winner or participant';
END $$;
