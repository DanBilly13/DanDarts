-- DanDarts Database Schema
-- Run this in Supabase SQL Editor to create all tables
-- Created: 2025-10-18

-- ============================================
-- 1. USERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    display_name TEXT NOT NULL,
    nickname TEXT UNIQUE NOT NULL,
    handle TEXT UNIQUE,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    last_seen_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for users table
CREATE INDEX IF NOT EXISTS idx_users_nickname ON users(nickname);
CREATE INDEX IF NOT EXISTS idx_users_display_name ON users(display_name);
CREATE INDEX IF NOT EXISTS idx_users_handle ON users(handle) WHERE handle IS NOT NULL;

-- ============================================
-- 2. PLAYER STATS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS player_stats (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    games_played INTEGER DEFAULT 0,
    wins INTEGER DEFAULT 0,
    losses INTEGER DEFAULT 0,
    total_180s INTEGER DEFAULT 0,
    highest_checkout INTEGER DEFAULT 0,
    average_score DECIMAL(5,2) DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- ============================================
-- 3. FRIENDS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS friends (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(user_id, friend_id)
);

-- Indexes for friends table
CREATE INDEX IF NOT EXISTS idx_friends_user_id ON friends(user_id);
CREATE INDEX IF NOT EXISTS idx_friends_friend_id ON friends(friend_id);
CREATE INDEX IF NOT EXISTS idx_friends_status ON friends(status);

-- ============================================
-- 4. GAMES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS games (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    rules JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Insert default games
INSERT INTO games (id, name, rules) VALUES
    ('301', '301', '{"startingScore": 301, "mustDoubleOut": true}'::jsonb),
    ('501', '501', '{"startingScore": 501, "mustDoubleOut": true}'::jsonb),
    ('halve_it', 'Halve-It', '{"rounds": 7}'::jsonb),
    ('knockout', 'Knockout', '{"startingLives": 3}'::jsonb),
    ('sudden_death', 'Sudden Death', '{"startingScore": 301}'::jsonb),
    ('cricket', 'English Cricket', '{"targets": [20, 19, 18, 17, 16, 15, 25]}'::jsonb),
    ('killer', 'Killer', '{"startingLives": 3}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- 5. MATCHES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id TEXT NOT NULL REFERENCES games(id),
    started_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    ended_at TIMESTAMP WITH TIME ZONE,
    winner_id UUID REFERENCES users(id),
    host_device_id TEXT,
    duration_seconds INTEGER,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Indexes for matches table
CREATE INDEX IF NOT EXISTS idx_matches_game_id ON matches(game_id);
CREATE INDEX IF NOT EXISTS idx_matches_winner_id ON matches(winner_id);
CREATE INDEX IF NOT EXISTS idx_matches_started_at ON matches(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_matches_host_device_id ON matches(host_device_id) WHERE host_device_id IS NOT NULL;

-- ============================================
-- 6. MATCH PLAYERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS match_players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    player_user_id UUID REFERENCES users(id),
    guest_name TEXT,
    player_order INTEGER NOT NULL,
    starting_score INTEGER NOT NULL,
    final_score INTEGER NOT NULL,
    total_darts_thrown INTEGER DEFAULT 0,
    average_score DECIMAL(5,2) DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(match_id, player_order),
    CHECK (player_user_id IS NOT NULL OR guest_name IS NOT NULL)
);

-- Indexes for match_players table
CREATE INDEX IF NOT EXISTS idx_match_players_match_id ON match_players(match_id);
CREATE INDEX IF NOT EXISTS idx_match_players_user_id ON match_players(player_user_id) WHERE player_user_id IS NOT NULL;

-- ============================================
-- 7. MATCH TURNS TABLE (formerly match_throws)
-- ============================================
CREATE TABLE IF NOT EXISTS match_turns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    player_order INTEGER NOT NULL,
    turn_index INTEGER NOT NULL,
    darts JSONB NOT NULL,
    score_before INTEGER NOT NULL,
    score_after INTEGER NOT NULL,
    is_bust BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(match_id, player_order, turn_index)
);

-- Indexes for match_turns table
CREATE INDEX IF NOT EXISTS idx_match_turns_match_id ON match_turns(match_id);
CREATE INDEX IF NOT EXISTS idx_match_turns_player_order ON match_turns(match_id, player_order);

-- ============================================
-- 8. MATCH DARTS TABLE (detailed dart data)
-- ============================================
CREATE TABLE IF NOT EXISTS match_darts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    turn_id UUID NOT NULL REFERENCES match_turns(id) ON DELETE CASCADE,
    dart_index INTEGER NOT NULL,
    base_value INTEGER NOT NULL,
    multiplier INTEGER NOT NULL,
    total_value INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    UNIQUE(turn_id, dart_index)
);

-- Indexes for match_darts table
CREATE INDEX IF NOT EXISTS idx_match_darts_turn_id ON match_darts(turn_id);

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Function to update player stats after match
CREATE OR REPLACE FUNCTION update_player_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Update stats for all players in the completed match
    WITH match_data AS (
        SELECT 
            mp.player_user_id,
            CASE WHEN NEW.winner_id = mp.player_user_id THEN 1 ELSE 0 END as is_win
        FROM match_players mp
        WHERE mp.match_id = NEW.id
        AND mp.player_user_id IS NOT NULL
    )
    UPDATE player_stats ps
    SET 
        games_played = games_played + 1,
        wins = wins + md.is_win,
        losses = losses + (1 - md.is_win),
        updated_at = now()
    FROM match_data md
    WHERE ps.user_id = md.player_user_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update stats when match ends
CREATE TRIGGER trigger_update_player_stats
    AFTER UPDATE OF ended_at ON matches
    FOR EACH ROW
    WHEN (NEW.ended_at IS NOT NULL AND OLD.ended_at IS NULL)
    EXECUTE FUNCTION update_player_stats();

-- Function to auto-create player_stats for new users
CREATE OR REPLACE FUNCTION create_player_stats()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO player_stats (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to create stats when user is created
CREATE TRIGGER trigger_create_player_stats
    AFTER INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION create_player_stats();

-- ============================================
-- COMMENTS
-- ============================================

COMMENT ON TABLE users IS 'User accounts and profiles';
COMMENT ON TABLE player_stats IS 'Aggregated statistics for each player';
COMMENT ON TABLE friends IS 'Friend relationships between users';
COMMENT ON TABLE games IS 'Available dart game types';
COMMENT ON TABLE matches IS 'Completed or in-progress matches';
COMMENT ON TABLE match_players IS 'Players participating in each match';
COMMENT ON TABLE match_turns IS 'Turn-by-turn data for each match';
COMMENT ON TABLE match_darts IS 'Individual dart throws within each turn';

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Run these to verify tables were created:
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;
-- SELECT * FROM games;
