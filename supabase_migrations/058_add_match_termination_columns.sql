-- =====================================================
-- Add Match Termination Tracking Columns
-- Adds ended_by and ended_reason for audit trail
-- Makes ended_at nullable for proper lifecycle
-- =====================================================

-- Add new columns for match termination tracking
ALTER TABLE public.matches
ADD COLUMN IF NOT EXISTS ended_by UUID REFERENCES users(id),
ADD COLUMN IF NOT EXISTS ended_reason TEXT;

-- CRITICAL: Make ended_at nullable
-- In-progress matches should have NULL ended_at
-- Only completed/cancelled matches have ended_at
ALTER TABLE public.matches
ALTER COLUMN ended_at DROP NOT NULL;

-- Add index for queries by ended_by
CREATE INDEX IF NOT EXISTS matches_ended_by_idx ON public.matches(ended_by);

-- Add helpful comments
COMMENT ON COLUMN public.matches.ended_by IS 'User who ended/aborted the match';
COMMENT ON COLUMN public.matches.ended_reason IS 'Reason for match termination (aborted, completed, expired, etc.)';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Match termination columns added successfully!';
    RAISE NOTICE '   - ended_by (UUID, nullable)';
    RAISE NOTICE '   - ended_reason (TEXT, nullable)';
    RAISE NOTICE '   - ended_at is now nullable';
END $$;
