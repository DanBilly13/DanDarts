-- Migration: Add Lobby Presence Tracking
-- Adds lobby presence timestamps and countdown tracking to matches table
-- for deterministic staged remote match flow

-- Add lobby presence columns
ALTER TABLE matches
ADD COLUMN IF NOT EXISTS challenger_lobby_joined_at TIMESTAMPTZ NULL,
ADD COLUMN IF NOT EXISTS receiver_lobby_joined_at TIMESTAMPTZ NULL,
ADD COLUMN IF NOT EXISTS lobby_countdown_started_at TIMESTAMPTZ NULL,
ADD COLUMN IF NOT EXISTS lobby_countdown_seconds INT NOT NULL DEFAULT 5;

-- Add comments for documentation
COMMENT ON COLUMN matches.challenger_lobby_joined_at IS 'Timestamp when challenger entered the lobby';
COMMENT ON COLUMN matches.receiver_lobby_joined_at IS 'Timestamp when receiver entered the lobby';
COMMENT ON COLUMN matches.lobby_countdown_started_at IS 'Timestamp when countdown started (both players present)';
COMMENT ON COLUMN matches.lobby_countdown_seconds IS 'Duration of countdown in seconds (default 5)';
