-- =====================================================
-- DanDarts Database Migration 047
-- Remote Matches Schema - Phase 0
-- =====================================================
-- Purpose: Add remote match support to existing matches table
-- Date: 2026-02-19
-- Branch: remote-matches
-- 
-- DESIGN DECISIONS:
-- 1. Reuse existing matches/match_players/match_throws tables
-- 2. Add match_mode column to distinguish local vs remote
-- 3. Lock table prevents race conditions
-- 4. Server-authoritative via Edge Functions
-- =====================================================

BEGIN;

-- ============================================
-- STEP 1: CREATE REMOTE MATCH STATUS ENUM
-- ============================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'remote_match_status') THEN
        CREATE TYPE remote_match_status AS ENUM (
            'pending',
            'ready',
            'lobby',
            'in_progress',
            'completed',
            'expired',
            'cancelled'
        );
        RAISE NOTICE 'Created remote_match_status enum';
    ELSE
        RAISE NOTICE 'remote_match_status enum already exists - skipping';
    END IF;
END $$;

-- ============================================
-- STEP 2: EXTEND MATCHES TABLE
-- ============================================

-- Add match_mode column (local vs remote)
ALTER TABLE matches ADD COLUMN IF NOT EXISTS match_mode TEXT DEFAULT 'local';
COMMENT ON COLUMN matches.match_mode IS 'Match type: local (offline) or remote (live multiplayer)';

-- Add remote-specific columns (NULL for local matches)
ALTER TABLE matches ADD COLUMN IF NOT EXISTS challenger_id UUID;
COMMENT ON COLUMN matches.challenger_id IS 'User who sent the challenge (remote matches only)';

ALTER TABLE matches ADD COLUMN IF NOT EXISTS receiver_id UUID;
COMMENT ON COLUMN matches.receiver_id IS 'User who received the challenge (remote matches only)';

ALTER TABLE matches ADD COLUMN IF NOT EXISTS remote_status remote_match_status;
COMMENT ON COLUMN matches.remote_status IS 'Current status of remote match (NULL for local matches)';

ALTER TABLE matches ADD COLUMN IF NOT EXISTS current_player_id UUID;
COMMENT ON COLUMN matches.current_player_id IS 'Whose turn it is (remote matches only)';

ALTER TABLE matches ADD COLUMN IF NOT EXISTS join_window_expires_at TIMESTAMPTZ;
COMMENT ON COLUMN matches.join_window_expires_at IS 'When the join window expires (5 minutes after ready)';

ALTER TABLE matches ADD COLUMN IF NOT EXISTS challenge_expires_at TIMESTAMPTZ;
COMMENT ON COLUMN matches.challenge_expires_at IS 'When the challenge expires (24 hours after creation)';

ALTER TABLE matches ADD COLUMN IF NOT EXISTS last_visit_payload JSONB;
COMMENT ON COLUMN matches.last_visit_payload IS 'Last visit data for 1-2s reveal animation';

RAISE NOTICE 'Extended matches table with remote columns';

-- ============================================
-- STEP 3: CREATE INDEXES FOR REMOTE QUERIES
-- ============================================

-- Challenger queries (e.g., "show my sent challenges")
CREATE INDEX IF NOT EXISTS matches_challenger_status_idx 
    ON matches(challenger_id, remote_status) 
    WHERE match_mode = 'remote';

-- Receiver queries (e.g., "show my received challenges")
CREATE INDEX IF NOT EXISTS matches_receiver_status_idx 
    ON matches(receiver_id, remote_status) 
    WHERE match_mode = 'remote';

-- Expiration queries (cron job)
CREATE INDEX IF NOT EXISTS matches_join_window_idx 
    ON matches(join_window_expires_at) 
    WHERE match_mode = 'remote' AND join_window_expires_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS matches_challenge_expiry_idx 
    ON matches(challenge_expires_at) 
    WHERE match_mode = 'remote' AND challenge_expires_at IS NOT NULL;

-- Match mode queries
CREATE INDEX IF NOT EXISTS matches_match_mode_idx 
    ON matches(match_mode);

RAISE NOTICE 'Created indexes for remote match queries';

-- ============================================
-- STEP 4: CREATE REMOTE MATCH LOCKS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS remote_match_locks (
    user_id UUID PRIMARY KEY,
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    lock_status TEXT NOT NULL CHECK (lock_status IN ('ready', 'in_progress')),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE remote_match_locks IS 
    'Prevents users from having multiple ready/in_progress matches. One lock per user.';

COMMENT ON COLUMN remote_match_locks.user_id IS 'User who holds the lock';
COMMENT ON COLUMN remote_match_locks.match_id IS 'Match that is locked';
COMMENT ON COLUMN remote_match_locks.lock_status IS 'Type of lock: ready or in_progress';

CREATE INDEX IF NOT EXISTS remote_match_locks_match_id_idx 
    ON remote_match_locks(match_id);

-- Enable RLS
ALTER TABLE remote_match_locks ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view their own locks" ON remote_match_locks;
CREATE POLICY "Users can view their own locks"
    ON remote_match_locks
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Server can manage locks" ON remote_match_locks;
CREATE POLICY "Server can manage locks"
    ON remote_match_locks
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

GRANT ALL ON remote_match_locks TO authenticated;

RAISE NOTICE 'Created remote_match_locks table';

-- ============================================
-- STEP 5: CREATE USER PUSH TOKENS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS user_push_tokens (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    updated_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, token)
);

COMMENT ON TABLE user_push_tokens IS 
    'Stores device push notification tokens for APNs/FCM';

COMMENT ON COLUMN user_push_tokens.user_id IS 'User who owns the device';
COMMENT ON COLUMN user_push_tokens.token IS 'APNs/FCM device token';
COMMENT ON COLUMN user_push_tokens.platform IS 'Platform: ios or android';

CREATE INDEX IF NOT EXISTS user_push_tokens_user_id_idx 
    ON user_push_tokens(user_id);

-- Enable RLS
ALTER TABLE user_push_tokens ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can manage their own tokens" ON user_push_tokens;
CREATE POLICY "Users can manage their own tokens"
    ON user_push_tokens
    FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

GRANT ALL ON user_push_tokens TO authenticated;

RAISE NOTICE 'Created user_push_tokens table';

-- ============================================
-- STEP 6: UPDATE RLS POLICIES FOR MATCHES
-- ============================================

-- Add policy for remote match visibility
DROP POLICY IF EXISTS "Users can view remote matches they participate in" ON matches;
CREATE POLICY "Users can view remote matches they participate in"
    ON matches
    FOR SELECT
    TO authenticated
    USING (
        match_mode = 'remote' 
        AND (challenger_id = auth.uid() OR receiver_id = auth.uid())
    );

RAISE NOTICE 'Updated RLS policies for remote matches';

-- ============================================
-- STEP 7: VERIFICATION
-- ============================================

DO $$
DECLARE
    match_mode_exists BOOLEAN;
    challenger_id_exists BOOLEAN;
    locks_table_exists BOOLEAN;
    tokens_table_exists BOOLEAN;
BEGIN
    -- Check matches table columns
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'matches' AND column_name = 'match_mode'
    ) INTO match_mode_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'matches' AND column_name = 'challenger_id'
    ) INTO challenger_id_exists;
    
    -- Check new tables
    SELECT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'public' AND tablename = 'remote_match_locks'
    ) INTO locks_table_exists;
    
    SELECT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'public' AND tablename = 'user_push_tokens'
    ) INTO tokens_table_exists;
    
    -- Report results
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 047 Verification:';
    RAISE NOTICE '  matches.match_mode: %', match_mode_exists;
    RAISE NOTICE '  matches.challenger_id: %', challenger_id_exists;
    RAISE NOTICE '  remote_match_locks table: %', locks_table_exists;
    RAISE NOTICE '  user_push_tokens table: %', tokens_table_exists;
    
    IF match_mode_exists AND challenger_id_exists AND locks_table_exists AND tokens_table_exists THEN
        RAISE NOTICE '✓ Migration 047 completed successfully!';
    ELSE
        RAISE WARNING '⚠ Migration 047 incomplete - check logs above';
    END IF;
    RAISE NOTICE '========================================';
END $$;

COMMIT;

-- ============================================
-- CONFIGURATION CONSTANTS (DOCUMENTATION)
-- ============================================
-- Challenge Expiry: 24 hours (86400 seconds)
-- Join Window: 5 minutes (300 seconds)
-- Expiration Check: Every 1 minute (pg_cron)
-- ============================================

-- ============================================
-- ROLLBACK SCRIPT (DO NOT RUN UNLESS NEEDED)
-- ============================================
--
-- If something goes wrong, run this to rollback:
--
-- BEGIN;
-- DROP INDEX IF EXISTS matches_challenger_status_idx;
-- DROP INDEX IF EXISTS matches_receiver_status_idx;
-- DROP INDEX IF EXISTS matches_join_window_idx;
-- DROP INDEX IF EXISTS matches_challenge_expiry_idx;
-- DROP INDEX IF EXISTS matches_match_mode_idx;
-- DROP TABLE IF EXISTS user_push_tokens;
-- DROP TABLE IF EXISTS remote_match_locks;
-- ALTER TABLE matches DROP COLUMN IF EXISTS last_visit_payload;
-- ALTER TABLE matches DROP COLUMN IF EXISTS challenge_expires_at;
-- ALTER TABLE matches DROP COLUMN IF EXISTS join_window_expires_at;
-- ALTER TABLE matches DROP COLUMN IF EXISTS current_player_id;
-- ALTER TABLE matches DROP COLUMN IF EXISTS remote_status;
-- ALTER TABLE matches DROP COLUMN IF EXISTS receiver_id;
-- ALTER TABLE matches DROP COLUMN IF EXISTS challenger_id;
-- ALTER TABLE matches DROP COLUMN IF EXISTS match_mode;
-- DROP TYPE IF EXISTS remote_match_status;
-- COMMIT;
--
-- ============================================
