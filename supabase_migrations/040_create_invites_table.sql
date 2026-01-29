CREATE TABLE IF NOT EXISTS public.invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token TEXT NOT NULL UNIQUE,
  inviter_id UUID NOT NULL REFERENCES public.users (id) ON DELETE CASCADE,
  claimed_by UUID REFERENCES public.users (id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  claimed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days')
);

CREATE INDEX IF NOT EXISTS invites_inviter_id_idx ON public.invites (inviter_id);
CREATE INDEX IF NOT EXISTS invites_expires_at_idx ON public.invites (expires_at);

ALTER TABLE public.invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Inviter can insert invites" ON public.invites;
CREATE POLICY "Inviter can insert invites" ON public.invites
  FOR INSERT
  TO authenticated
  WITH CHECK (inviter_id = auth.uid());

DROP POLICY IF EXISTS "Inviter can view own invites" ON public.invites;
CREATE POLICY "Inviter can view own invites" ON public.invites
  FOR SELECT
  TO authenticated
  USING (inviter_id = auth.uid());
