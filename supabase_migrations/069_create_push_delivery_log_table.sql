-- =====================================================
-- DanDarts Database Migration
-- Create push_delivery_log table for idempotency and observability
-- Phase 8: Push Notifications
-- =====================================================

-- Create push_delivery_log table
CREATE TABLE IF NOT EXISTS public.push_delivery_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dedupe_key TEXT NOT NULL,
  match_id UUID NOT NULL,
  recipient_user_id UUID NOT NULL,
  event_type TEXT NOT NULL,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  success BOOLEAN NOT NULL,
  error_message TEXT,
  
  -- Unique constraint for idempotency
  UNIQUE(dedupe_key)
);

-- Create indexes for performance and cleanup
CREATE INDEX IF NOT EXISTS idx_push_delivery_log_sent_at ON public.push_delivery_log(sent_at);
CREATE INDEX IF NOT EXISTS idx_push_delivery_log_match_id ON public.push_delivery_log(match_id);
CREATE INDEX IF NOT EXISTS idx_push_delivery_log_recipient ON public.push_delivery_log(recipient_user_id);

-- Note: Auto-cleanup of old logs (>7 days) will be handled by a scheduled Edge Function or pg_cron
-- For now, logs will accumulate. Cleanup can be added later as needed.

-- Enable Row Level Security (restrict access to service role only)
ALTER TABLE public.push_delivery_log ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Service role can manage delivery logs" ON public.push_delivery_log;

-- RLS Policy: Only service role can access (Edge Functions use service role)
-- No user-level access needed - this is internal logging only
CREATE POLICY "Service role can manage delivery logs"
  ON public.push_delivery_log
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Migration 069: push_delivery_log table created successfully';
END $$;
