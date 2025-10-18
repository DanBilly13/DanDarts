-- DanDarts Row Level Security (RLS) Policies
-- Run this AFTER creating tables (supabase_schema.sql)
-- Created: 2025-10-18

-- ============================================
-- ENABLE RLS ON ALL TABLES
-- ============================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE friends ENABLE ROW LEVEL SECURITY;
ALTER TABLE games ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_turns ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_darts ENABLE ROW LEVEL SECURITY;

-- ============================================
-- USERS TABLE POLICIES
-- ============================================

-- Anyone can read all user profiles (for finding friends, viewing opponents)
CREATE POLICY "Users can read all profiles"
    ON users FOR SELECT
    USING (true);

-- Users can update only their own profile
CREATE POLICY "Users can update own profile"
    ON users FOR UPDATE
    USING (auth.uid() = id);

-- Users can insert their own profile (during signup)
CREATE POLICY "Users can insert own profile"
    ON users FOR INSERT
    WITH CHECK (auth.uid() = id);

-- ============================================
-- PLAYER_STATS TABLE POLICIES
-- ============================================

-- Anyone can read all player stats (for leaderboards, comparisons)
CREATE POLICY "Anyone can read player stats"
    ON player_stats FOR SELECT
    USING (true);

-- Only system can update stats (via triggers)
-- Users cannot directly modify stats
CREATE POLICY "System can update player stats"
    ON player_stats FOR UPDATE
    USING (false);

-- System can insert stats for new users
CREATE POLICY "System can insert player stats"
    ON player_stats FOR INSERT
    WITH CHECK (true);

-- ============================================
-- FRIENDS TABLE POLICIES
-- ============================================

-- Users can read friendships where they are involved
CREATE POLICY "Users can read own friendships"
    ON friends FOR SELECT
    USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- Users can send friend requests (insert)
CREATE POLICY "Users can send friend requests"
    ON friends FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update friend requests they received (accept/reject)
CREATE POLICY "Users can update received friend requests"
    ON friends FOR UPDATE
    USING (auth.uid() = friend_id);

-- Users can delete their own friend requests or friendships
CREATE POLICY "Users can delete own friendships"
    ON friends FOR DELETE
    USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- ============================================
-- GAMES TABLE POLICIES
-- ============================================

-- Everyone can read game definitions
CREATE POLICY "Anyone can read games"
    ON games FOR SELECT
    USING (true);

-- Only admins can modify games (no policy = no access)
-- Games are managed by database admins only

-- ============================================
-- MATCHES TABLE POLICIES
-- ============================================

-- Users can read matches they participated in
CREATE POLICY "Users can read own matches"
    ON matches FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM match_players
            WHERE match_players.match_id = matches.id
            AND match_players.player_user_id = auth.uid()
        )
    );

-- Users can insert matches (when creating a game)
CREATE POLICY "Users can insert matches"
    ON matches FOR INSERT
    WITH CHECK (
        -- Match must have at least one player who is the authenticated user
        EXISTS (
            SELECT 1 FROM match_players
            WHERE match_players.match_id = matches.id
            AND match_players.player_user_id = auth.uid()
        )
    );

-- Users can update matches they're in (to set winner, end time)
CREATE POLICY "Users can update own matches"
    ON matches FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM match_players
            WHERE match_players.match_id = matches.id
            AND match_players.player_user_id = auth.uid()
        )
    );

-- ============================================
-- MATCH_PLAYERS TABLE POLICIES
-- ============================================

-- Users can read match_players for matches they're in
CREATE POLICY "Users can read match players"
    ON match_players FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM match_players mp
            WHERE mp.match_id = match_players.match_id
            AND mp.player_user_id = auth.uid()
        )
    );

-- Users can insert match_players when creating a match
CREATE POLICY "Users can insert match players"
    ON match_players FOR INSERT
    WITH CHECK (
        -- Either inserting themselves or a guest player
        player_user_id = auth.uid() OR player_user_id IS NULL
    );

-- ============================================
-- MATCH_TURNS TABLE POLICIES
-- ============================================

-- Users can read turns for matches they're in
CREATE POLICY "Users can read match turns"
    ON match_turns FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM match_players
            WHERE match_players.match_id = match_turns.match_id
            AND match_players.player_user_id = auth.uid()
        )
    );

-- Users can insert turns for matches they're in
CREATE POLICY "Users can insert match turns"
    ON match_turns FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM match_players
            WHERE match_players.match_id = match_turns.match_id
            AND match_players.player_user_id = auth.uid()
        )
    );

-- Users can update turns for matches they're in (for corrections)
CREATE POLICY "Users can update match turns"
    ON match_turns FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM match_players
            WHERE match_players.match_id = match_turns.match_id
            AND match_players.player_user_id = auth.uid()
        )
    );

-- ============================================
-- MATCH_DARTS TABLE POLICIES
-- ============================================

-- Users can read darts for matches they're in
CREATE POLICY "Users can read match darts"
    ON match_darts FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM match_turns mt
            JOIN match_players mp ON mp.match_id = mt.match_id
            WHERE mt.id = match_darts.turn_id
            AND mp.player_user_id = auth.uid()
        )
    );

-- Users can insert darts for matches they're in
CREATE POLICY "Users can insert match darts"
    ON match_darts FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM match_turns mt
            JOIN match_players mp ON mp.match_id = mt.match_id
            WHERE mt.id = match_darts.turn_id
            AND mp.player_user_id = auth.uid()
        )
    );

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check that RLS is enabled on all tables:
-- SELECT tablename, rowsecurity 
-- FROM pg_tables 
-- WHERE schemaname = 'public' 
-- ORDER BY tablename;

-- View all policies:
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
-- FROM pg_policies 
-- WHERE schemaname = 'public'
-- ORDER BY tablename, policyname;

-- ============================================
-- TESTING NOTES
-- ============================================

-- To test RLS policies:
-- 1. Create test users via Supabase Auth
-- 2. Use Supabase client with different auth tokens
-- 3. Try to read/write data that should be restricted
-- 4. Verify unauthorized access is blocked
-- 5. Verify authorized access works

-- Example test scenarios:
-- ✓ User A can read User B's profile
-- ✓ User A cannot update User B's profile
-- ✓ User A can only see friendships involving User A
-- ✓ User A can only see matches User A played in
-- ✓ User A cannot see User B's private matches
