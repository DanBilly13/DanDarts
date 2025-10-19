-- =====================================================
-- DanDarts Database Migration
-- Create matches table for storing game results
-- =====================================================

-- Create matches table
CREATE TABLE IF NOT EXISTS public.matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_type TEXT NOT NULL,
    game_name TEXT NOT NULL,
    winner_id UUID NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    duration INTEGER NOT NULL, -- Duration in seconds
    players JSONB NOT NULL, -- Array of MatchPlayer objects
    synced_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS matches_timestamp_idx ON public.matches(timestamp DESC);
CREATE INDEX IF NOT EXISTS matches_winner_id_idx ON public.matches(winner_id);
CREATE INDEX IF NOT EXISTS matches_game_type_idx ON public.matches(game_type);
CREATE INDEX IF NOT EXISTS matches_synced_at_idx ON public.matches(synced_at);

-- Create GIN index for JSONB players array (for searching by player ID)
CREATE INDEX IF NOT EXISTS matches_players_idx ON public.matches USING GIN (players);

-- Enable Row Level Security
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own matches" ON public.matches;
DROP POLICY IF EXISTS "Users can insert their own matches" ON public.matches;
DROP POLICY IF EXISTS "Users can update their own matches" ON public.matches;

-- RLS Policy: Users can view matches they participated in
CREATE POLICY "Users can view their own matches"
    ON public.matches
    FOR SELECT
    TO authenticated
    USING (
        -- Check if user's UUID is in any player's id field in the JSONB array
        EXISTS (
            SELECT 1 FROM jsonb_array_elements(players) AS player
            WHERE (player->>'id')::uuid = auth.uid()
               OR player->>'id' = auth.uid()::text
        )
    );

-- RLS Policy: Authenticated users can insert any matches
-- This allows users to record matches between other players (e.g., as scorekeeper)
CREATE POLICY "Authenticated users can insert matches"
    ON public.matches
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- RLS Policy: Users can update their own matches (for sync status)
CREATE POLICY "Users can update their own matches"
    ON public.matches
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM jsonb_array_elements(players) AS player
            WHERE (player->>'id')::uuid = auth.uid()
               OR player->>'id' = auth.uid()::text
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM jsonb_array_elements(players) AS player
            WHERE (player->>'id')::uuid = auth.uid()
               OR player->>'id' = auth.uid()::text
        )
    );

-- Grant permissions
GRANT ALL ON public.matches TO authenticated;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_matches_updated_at ON public.matches;
CREATE TRIGGER update_matches_updated_at
    BEFORE UPDATE ON public.matches
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Matches table created successfully!';
END $$;
