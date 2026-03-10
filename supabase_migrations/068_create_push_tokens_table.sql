-- =====================================================
-- DanDarts Database Migration
-- Create push_tokens table for APNs push notification tokens
-- Phase 8: Push Notifications
-- =====================================================

-- Create push_tokens table
CREATE TABLE IF NOT EXISTS public.push_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  device_install_id TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'ios',
  provider TEXT NOT NULL DEFAULT 'apns',
  environment TEXT NOT NULL CHECK (environment IN ('sandbox', 'production')),
  push_token TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ,
  
  -- Constraints
  UNIQUE(user_id, device_install_id)
  -- Note: Removed UNIQUE(push_token) - same device token can be shared by multiple users on the same device
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_push_tokens_user_id ON public.push_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_push_tokens_active ON public.push_tokens(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_push_tokens_environment ON public.push_tokens(environment);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to auto-update updated_at
DROP TRIGGER IF EXISTS update_push_tokens_updated_at ON public.push_tokens;
CREATE TRIGGER update_push_tokens_updated_at
  BEFORE UPDATE ON public.push_tokens
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (for re-running migration)
DROP POLICY IF EXISTS "Users can view their own tokens" ON public.push_tokens;
DROP POLICY IF EXISTS "Users can insert their own tokens" ON public.push_tokens;
DROP POLICY IF EXISTS "Users can update their own tokens" ON public.push_tokens;
DROP POLICY IF EXISTS "Users can delete their own tokens" ON public.push_tokens;

-- RLS Policy: Users can view their own tokens
CREATE POLICY "Users can view their own tokens"
  ON public.push_tokens FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- RLS Policy: Users can insert their own tokens
CREATE POLICY "Users can insert their own tokens"
  ON public.push_tokens FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- RLS Policy: Users can update their own tokens
CREATE POLICY "Users can update their own tokens"
  ON public.push_tokens FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- RLS Policy: Users can delete their own tokens
CREATE POLICY "Users can delete their own tokens"
  ON public.push_tokens FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Migration 068: push_tokens table created successfully';
END $$;
