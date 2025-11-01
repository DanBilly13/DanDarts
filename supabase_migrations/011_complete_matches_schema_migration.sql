-- =====================================================
-- DanDarts Database Migration
-- Complete matches schema migration - proper fix
-- =====================================================

-- STEP 1: Update matches table to support new schema
-- Add new columns if they don't exist
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS ended_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS game_id TEXT,
ADD COLUMN IF NOT EXISTS metadata JSONB;

-- Make old columns nullable (for backward compatibility)
ALTER TABLE public.matches 
ALTER COLUMN game_type DROP NOT NULL,
ALTER COLUMN game_name DROP NOT NULL,
ALTER COLUMN winner_id DROP NOT NULL,
ALTER COLUMN duration DROP NOT NULL,
ALTER COLUMN players DROP NOT NULL;

-- Migrate existing data from old columns to new columns
UPDATE public.matches 
SET 
    started_at = COALESCE(started_at, timestamp - (duration || ' seconds')::INTERVAL, timestamp),
    ended_at = COALESCE(ended_at, timestamp),
    game_id = COALESCE(game_id, game_type),
    metadata = COALESCE(metadata, '{}'::jsonb)
WHERE started_at IS NULL OR ended_at IS NULL OR game_id IS NULL OR metadata IS NULL;

-- Now make new columns NOT NULL (after migration)
ALTER TABLE public.matches 
ALTER COLUMN started_at SET NOT NULL,
ALTER COLUMN ended_at SET NOT NULL,
ALTER COLUMN game_id SET NOT NULL;

-- STEP 2: Create match_players table
CREATE TABLE IF NOT EXISTS public.match_players (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
    player_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    guest_name TEXT,
    player_order INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    
    -- Constraints
    CONSTRAINT match_players_match_order_unique UNIQUE (match_id, player_order),
    CONSTRAINT match_players_user_or_guest CHECK (
        (player_user_id IS NOT NULL AND guest_name IS NULL) OR
        (player_user_id IS NULL AND guest_name IS NOT NULL)
    )
);

-- STEP 3: Create match_throws table
CREATE TABLE IF NOT EXISTS public.match_throws (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
    player_order INTEGER NOT NULL,
    turn_index INTEGER NOT NULL,
    throws INTEGER[] NOT NULL,
    score_before INTEGER NOT NULL,
    score_after INTEGER NOT NULL,
    game_metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT now(),
    
    -- Constraints
    CONSTRAINT match_throws_match_turn_unique UNIQUE (match_id, player_order, turn_index)
);

-- STEP 4: Create indexes for performance
CREATE INDEX IF NOT EXISTS matches_started_at_idx ON public.matches(started_at DESC);
CREATE INDEX IF NOT EXISTS matches_ended_at_idx ON public.matches(ended_at DESC);
CREATE INDEX IF NOT EXISTS matches_game_id_idx ON public.matches(game_id);
CREATE INDEX IF NOT EXISTS matches_metadata_idx ON public.matches USING GIN (metadata);

CREATE INDEX IF NOT EXISTS match_players_match_id_idx ON public.match_players(match_id);
CREATE INDEX IF NOT EXISTS match_players_user_id_idx ON public.match_players(player_user_id);

CREATE INDEX IF NOT EXISTS match_throws_match_id_idx ON public.match_throws(match_id);
CREATE INDEX IF NOT EXISTS match_throws_player_order_idx ON public.match_throws(player_order);

-- STEP 5: Enable RLS on new tables
ALTER TABLE public.match_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_throws ENABLE ROW LEVEL SECURITY;

-- STEP 6: Create RLS policies for match_players
CREATE POLICY "Users can view match_players for their matches"
    ON public.match_players
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            WHERE m.id = match_id
            AND (
                m.winner_id = auth.uid() OR
                EXISTS (
                    SELECT 1 FROM jsonb_array_elements(m.players) AS player
                    WHERE (player->>'id')::uuid = auth.uid()
                )
            )
        )
    );

CREATE POLICY "Authenticated users can insert match_players"
    ON public.match_players
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- STEP 7: Create RLS policies for match_throws
CREATE POLICY "Users can view match_throws for their matches"
    ON public.match_throws
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.matches m
            WHERE m.id = match_id
            AND (
                m.winner_id = auth.uid() OR
                EXISTS (
                    SELECT 1 FROM jsonb_array_elements(m.players) AS player
                    WHERE (player->>'id')::uuid = auth.uid()
                )
            )
        )
    );

CREATE POLICY "Authenticated users can insert match_throws"
    ON public.match_throws
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- STEP 8: Grant permissions
GRANT ALL ON public.match_players TO authenticated;
GRANT ALL ON public.match_throws TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Complete matches schema migration successful!';
    RAISE NOTICE 'Tables created: match_players, match_throws';
    RAISE NOTICE 'Matches table updated with new columns';
    RAISE NOTICE 'All indexes and RLS policies created';
END $$;
