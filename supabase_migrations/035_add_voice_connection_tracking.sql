-- Migration: Add voice connection tracking to matches table
-- Purpose: Enable voice-aware lobby countdown system
-- Date: 2026-03-20

-- Add voice connection tracking columns
ALTER TABLE matches
ADD COLUMN IF NOT EXISTS voice_connect_window_started_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS voice_connect_deadline TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS challenger_voice_ready_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS receiver_voice_ready_at TIMESTAMPTZ;

-- Add comments for documentation
COMMENT ON COLUMN matches.voice_connect_window_started_at IS 'When the 20-second voice connection window began (set once atomically)';
COMMENT ON COLUMN matches.voice_connect_deadline IS 'When the voice connection window expires (set once atomically)';
COMMENT ON COLUMN matches.challenger_voice_ready_at IS 'When challenger reported voice connection established';
COMMENT ON COLUMN matches.receiver_voice_ready_at IS 'When receiver reported voice connection established';
