-- =====================================================
-- DanDarts Database Migration 082
-- Add Database Trigger for Server-Authoritative match_players Creation
-- =====================================================
-- Purpose: Automatically create match_players rows when match completes
-- Date: 2026-03-18
-- Architecture: Move participant row creation from client to server
-- Benefits:
--   - Eliminates client RLS dependency
--   - Atomic with match completion
--   - Server-authoritative (more secure)
--   - No additional network round-trip
-- =====================================================

BEGIN;

DO $$
BEGIN
    RAISE NOTICE '=== MIGRATION 082: Add match_players Completion Trigger ===';
    RAISE NOTICE 'Current timestamp: %', now();
END $$;

-- =====================================================
-- Step 1: Create trigger function
-- =====================================================

CREATE OR REPLACE FUNCTION create_match_players_on_completion()
RETURNS TRIGGER AS $$
BEGIN
    -- Only run when match transitions to completed status
    IF NEW.remote_status = 'completed' AND (OLD.remote_status IS NULL OR OLD.remote_status != 'completed') THEN
        
        RAISE NOTICE '[Trigger] Match % completed, creating match_players rows', NEW.id;
        
        -- Insert both participants (challenger and receiver)
        -- Use ON CONFLICT DO NOTHING for idempotency (safe to run multiple times)
        INSERT INTO match_players (match_id, player_user_id, player_order)
        VALUES 
            (NEW.id, NEW.challenger_id, 0),
            (NEW.id, NEW.receiver_id, 1)
        ON CONFLICT (match_id, player_order) DO NOTHING;
        
        RAISE NOTICE '[Trigger] match_players rows created for match %', NEW.id;
        
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$ BEGIN RAISE NOTICE '✓ Created trigger function: create_match_players_on_completion()'; END $$;

-- =====================================================
-- Step 2: Create trigger on matches table
-- =====================================================

-- Drop trigger if it already exists (for idempotent migration)
DROP TRIGGER IF EXISTS match_completion_create_players ON matches;

-- Create trigger that fires AFTER UPDATE
CREATE TRIGGER match_completion_create_players
    AFTER UPDATE ON matches
    FOR EACH ROW
    EXECUTE FUNCTION create_match_players_on_completion();

DO $$ BEGIN RAISE NOTICE '✓ Created trigger: match_completion_create_players'; END $$;

-- =====================================================
-- Step 3: Verify trigger creation
-- =====================================================

SELECT 
    'Trigger Verification:' as info,
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    tgtype,
    tgenabled as enabled
FROM pg_trigger
WHERE tgname = 'match_completion_create_players';

-- =====================================================
-- Step 4: Test trigger with a sample update (optional)
-- =====================================================

DO $$
DECLARE
    test_match_id UUID;
    test_challenger_id UUID;
    test_receiver_id UUID;
    player_count INTEGER;
BEGIN
    -- Find a completed match to verify trigger worked
    SELECT id, challenger_id, receiver_id
    INTO test_match_id, test_challenger_id, test_receiver_id
    FROM matches
    WHERE remote_status = 'completed'
      AND match_mode = 'remote'
    ORDER BY ended_at DESC
    LIMIT 1;
    
    IF test_match_id IS NOT NULL THEN
        -- Check if match_players rows exist for this match
        SELECT COUNT(*)
        INTO player_count
        FROM match_players
        WHERE match_id = test_match_id;
        
        RAISE NOTICE 'Sample completed match: %', test_match_id;
        RAISE NOTICE 'match_players rows found: %', player_count;
        
        IF player_count = 2 THEN
            RAISE NOTICE '✓ Trigger appears to be working correctly';
        ELSIF player_count = 0 THEN
            RAISE NOTICE '⚠ No match_players rows - this is expected if match completed before trigger was created';
        ELSE
            RAISE NOTICE '⚠ Unexpected player count: %', player_count;
        END IF;
    ELSE
        RAISE NOTICE 'No completed remote matches found for verification';
    END IF;
END $$;

DO $$
BEGIN
    RAISE NOTICE '=== Migration 082 completed ===';
    RAISE NOTICE 'Trigger will automatically create match_players rows on match completion';
    RAISE NOTICE 'Client no longer needs to upsert match_players';
    RAISE NOTICE 'Next step: Update client code to remove match_players upsert';
END $$;

COMMIT;

-- =====================================================
-- ROLLBACK SCRIPT (if needed)
-- =====================================================
/*

BEGIN;

-- Drop the trigger
DROP TRIGGER IF EXISTS match_completion_create_players ON matches;

-- Drop the function
DROP FUNCTION IF EXISTS create_match_players_on_completion();

COMMIT;

*/

-- =====================================================
-- VERIFICATION QUERIES (run after migration)
-- =====================================================
/*

-- 1. Verify trigger exists
SELECT tgname, tgrelid::regclass, tgenabled
FROM pg_trigger
WHERE tgname = 'match_completion_create_players';

-- 2. Verify function exists
SELECT proname, prosrc
FROM pg_proc
WHERE proname = 'create_match_players_on_completion';

-- 3. Test with next completed match
-- After completing a match, check:
SELECT mp.*, u.display_name
FROM match_players mp
LEFT JOIN users u ON mp.player_user_id = u.id
WHERE mp.match_id = 'your-test-match-id'
ORDER BY mp.player_order;
-- Should return 2 rows automatically

*/
