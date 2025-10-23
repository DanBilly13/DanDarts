-- =====================================================
-- DanDarts Database Migration
-- Add multi-leg match support to matches table
-- =====================================================

-- Add match_format column (1, 3, 5, or 7)
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS match_format INTEGER NOT NULL DEFAULT 1;

-- Add total_legs_played column
ALTER TABLE public.matches 
ADD COLUMN IF NOT EXISTS total_legs_played INTEGER NOT NULL DEFAULT 1;

-- Add comment to explain the columns
COMMENT ON COLUMN public.matches.match_format IS 'Total legs in match format (1=Best of 1, 3=Best of 3, 5=Best of 5, 7=Best of 7)';
COMMENT ON COLUMN public.matches.total_legs_played IS 'Actual number of legs played in the match';

-- Create index for match_format for filtering
CREATE INDEX IF NOT EXISTS matches_match_format_idx ON public.matches(match_format);

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Multi-leg fields added to matches table successfully!';
    RAISE NOTICE 'Note: The players JSONB array should include legsWon field for each player';
END $$;
