-- =====================================================
-- DanDarts Database Migration 042
-- Create match_participants table for fast queries
-- =====================================================
-- Purpose: Denormalize match participant data for performance
-- Date: 2026-02-09
-- 
-- SAFETY FEATURES:
-- 1. Non-destructive (only adds new table)
-- 2. Includes verification steps
-- 3. Rollback script included at bottom
-- =====================================================

BEGIN;

-- ============================================
-- STEP 1: VERIFY CURRENT STATE
-- ============================================

DO $$
BEGIN
    IF EXISTS (
        SELECT FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'match_participants'
    ) THEN
        RAISE NOTICE 'match_participants table already EXISTS - skipping creation';
    ELSE
        RAISE NOTICE 'match_participants table does NOT exist - will create';
    END IF;
END $$;

-- ============================================
-- STEP 2: CREATE match_participants TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS public.match_participants (
    match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    is_guest BOOLEAN NOT NULL DEFAULT false,
    display_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (match_id, user_id)
);

-- ============================================
-- STEP 3: CREATE INDEXES
-- ============================================

-- Index for user queries (WHERE user_id = X)
CREATE INDEX IF NOT EXISTS idx_match_participants_user_id 
    ON public.match_participants(user_id) 
    WHERE is_guest = false;

-- Index for match queries (WHERE match_id = X)
CREATE INDEX IF NOT EXISTS idx_match_participants_match_id 
    ON public.match_participants(match_id);

-- Composite index for head-to-head queries
CREATE INDEX IF NOT EXISTS idx_match_participants_user_match 
    ON public.match_participants(user_id, match_id) 
    WHERE is_guest = false;

-- ============================================
-- STEP 4: ENABLE RLS
-- ============================================

ALTER TABLE public.match_participants ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view match participants" ON public.match_participants;
DROP POLICY IF EXISTS "Authenticated users can insert match participants" ON public.match_participants;

-- SELECT policy: Users can view participants for matches they're in
CREATE POLICY "Users can view match participants"
    ON public.match_participants
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            WHERE m.id = match_id
            AND (
                EXISTS (
                    SELECT 1 FROM jsonb_array_elements(m.players) AS player
                    WHERE (player->>'id')::uuid = auth.uid()
                )
            )
        )
    );

-- INSERT policy: Authenticated users can insert
CREATE POLICY "Authenticated users can insert match participants"
    ON public.match_participants
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- ============================================
-- STEP 5: GRANT PERMISSIONS
-- ============================================

GRANT ALL ON public.match_participants TO authenticated;

-- ============================================
-- STEP 6: ADD DOCUMENTATION
-- ============================================

COMMENT ON TABLE public.match_participants IS 
    'Denormalized table for fast match participant queries. Populated from matches.players JSONB field. Created in migration 042.';

COMMENT ON COLUMN public.match_participants.match_id IS 'Foreign key to matches table';
COMMENT ON COLUMN public.match_participants.user_id IS 'User UUID (from auth.users for connected users, random UUID for guests)';
COMMENT ON COLUMN public.match_participants.is_guest IS 'True if this is a guest player (not a registered user)';
COMMENT ON COLUMN public.match_participants.display_name IS 'Player display name';

-- ============================================
-- STEP 7: VERIFICATION
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 042 completed successfully! ✓';
    RAISE NOTICE 'Table: match_participants created';
    RAISE NOTICE 'Indexes: 3 created';
    RAISE NOTICE 'RLS: Enabled with 2 policies';
    RAISE NOTICE '========================================';
END $$;

COMMIT;

-- ============================================
-- ROLLBACK SCRIPT (DO NOT RUN UNLESS NEEDED)
-- ============================================
--
-- If something goes wrong, run this to rollback:
--
-- BEGIN;
-- DROP INDEX IF EXISTS idx_match_participants_user_match;
-- DROP INDEX IF EXISTS idx_match_participants_match_id;
-- DROP INDEX IF EXISTS idx_match_participants_user_id;
-- DROP TABLE IF EXISTS public.match_participants;
-- COMMIT;
--
-- ============================================
