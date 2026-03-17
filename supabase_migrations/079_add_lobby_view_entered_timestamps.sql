-- Migration: Add Lobby View Entered Timestamps
-- Adds confirmation timestamps for when clients actually enter lobby UI
-- This gates countdown start to ensure both players see the countdown

ALTER TABLE matches
ADD COLUMN IF NOT EXISTS challenger_lobby_view_entered_at TIMESTAMPTZ NULL,
ADD COLUMN IF NOT EXISTS receiver_lobby_view_entered_at TIMESTAMPTZ NULL;

COMMENT ON COLUMN matches.challenger_lobby_view_entered_at IS 'Timestamp when challenger RemoteLobbyView.onAppear was called';
COMMENT ON COLUMN matches.receiver_lobby_view_entered_at IS 'Timestamp when receiver RemoteLobbyView.onAppear was called';
