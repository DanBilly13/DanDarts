-- =====================================================
-- DanDarts Database Migration 043 (v2)
-- Populate match_participants from existing matches
-- =====================================================
-- Purpose: Migrate existing match data to new table
-- Date: 2026-02-09
-- 
-- HANDLES: Double-encoded JSON in players column
-- =====================================================

BEGIN;

-- ============================================
-- STEP 1: VERIFY PREREQUISITES
-- ============================================

DO $$
BEGIN
    -- Check match_participants exists
    IF NOT EXISTS (
        SELECT FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'match_participants'
    ) THEN
        RAISE EXCEPTION 'match_participants table does not exist! Run migration 042 first.';
    END IF;
    
    -- Check if already populated
    IF (SELECT COUNT(*) FROM public.match_participants) > 0 THEN
        RAISE NOTICE 'match_participants already has % rows - will add missing only', 
            (SELECT COUNT(*) FROM public.match_participants);
    ELSE
        RAISE NOTICE 'match_participants is empty - will populate from matches';
    END IF;
END $$;

-- ============================================
-- STEP 2: POPULATE match_participants
-- ============================================

-- Handle the double-encoded JSON by converting to TEXT, then parsing
INSERT INTO public.match_participants (match_id, user_id, is_guest, display_name)
SELECT 
    m.id as match_id,
    (player->>'id')::UUID as user_id,
    CASE 
        WHEN (player->>'isGuest') = 'true' THEN true
        WHEN (player->>'isGuest') = 'false' THEN false
        ELSE false
    END as is_guest,
    player->>'displayName' as display_name
FROM 
    public.matches m,
    LATERAL (
        SELECT jsonb_array_elements(
            -- Convert the JSONB to text, parse as JSON to strip quotes, then back to JSONB
            CASE 
                WHEN jsonb_typeof(m.players) = 'string' THEN (m.players#>>'{}')::jsonb
                ELSE m.players
            END
        ) as player
    ) players
ON CONFLICT (match_id, user_id) DO NOTHING;

-- ============================================
-- STEP 3: VERIFICATION
-- ============================================

DO $$
DECLARE
    total_participants INTEGER;
    connected_users INTEGER;
    guest_players INTEGER;
    total_matches INTEGER;
BEGIN
    -- Count matches
    SELECT COUNT(*) INTO total_matches FROM public.matches;
    
    -- Count participants in new table
    SELECT COUNT(*) INTO total_participants 
    FROM public.match_participants;
    
    -- Count connected vs guest
    SELECT COUNT(*) INTO connected_users 
    FROM public.match_participants WHERE is_guest = false;
    
    SELECT COUNT(*) INTO guest_players 
    FROM public.match_participants WHERE is_guest = true;
    
    -- Report
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VERIFICATION REPORT:';
    RAISE NOTICE 'Total matches: %', total_matches;
    RAISE NOTICE 'Participants migrated: %', total_participants;
    RAISE NOTICE 'Connected users: %', connected_users;
    RAISE NOTICE 'Guest players: %', guest_players;
    RAISE NOTICE '========================================';
    
    -- Check for NULL values
    IF EXISTS (SELECT 1 FROM public.match_participants WHERE user_id IS NULL OR display_name IS NULL) THEN
        RAISE EXCEPTION 'MIGRATION FAILED: NULL values found in required fields';
    END IF;
    
    -- Basic sanity check: should have at least as many participants as matches
    IF total_participants < total_matches THEN
        RAISE WARNING 'Unexpected: fewer participants (%) than matches (%)', total_participants, total_matches;
    END IF;
    
    RAISE NOTICE 'Migration 043 completed successfully! ✓';
END $$;

COMMIT;

-- ============================================
-- ROLLBACK SCRIPT (DO NOT RUN UNLESS NEEDED)
-- ============================================
--
-- To rollback and clear the table:
--
-- BEGIN;
-- TRUNCATE public.match_participants;
-- COMMIT;
--
-- ============================================
