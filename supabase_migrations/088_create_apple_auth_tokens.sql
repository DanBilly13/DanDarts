-- =====================================================
-- DanDarts Database Migration 088
-- Create apple_auth_tokens (server-only storage for Apple refresh tokens)
-- =====================================================
-- Date: 2026-07-14
--
-- Purpose:
--   Sign in with Apple requires revoking the user's Apple token when their
--   account is deleted (App Review 5.1.1). The Apple authorization code obtained
--   at sign-in expires in ~5 minutes, so it cannot be stored and used later.
--   Instead we exchange it for a long-lived REFRESH TOKEN at sign-in time and
--   store that here, to be revoked by the delete-account edge function.
--
-- Security:
--   - This is secret material. RLS is ENABLED and NO policies are created for
--     `authenticated`/`anon`, so clients can neither read nor write it directly.
--   - Only the service_role (used by the exchange-apple-code and delete-account
--     edge functions) bypasses RLS and can read/write.
--   - Row is removed automatically when the user is deleted (ON DELETE CASCADE).
-- =====================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.apple_auth_tokens (
    user_id       UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    refresh_token TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.apple_auth_tokens IS
    'Server-only: Apple Sign in refresh tokens for account-deletion revocation. No client access (RLS, no policies).';

-- Enable RLS with NO policies => clients (authenticated/anon) get zero access.
-- service_role bypasses RLS and is the only reader/writer.
ALTER TABLE public.apple_auth_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.apple_auth_tokens FORCE ROW LEVEL SECURITY;

-- Lock down grants explicitly (defensive; service_role is unaffected by these).
REVOKE ALL ON public.apple_auth_tokens FROM anon, authenticated;

DO $$
BEGIN
    RAISE NOTICE '=== Migration 088 complete: apple_auth_tokens created (server-only) ===';
END $$;

COMMIT;

-- =====================================================
-- ROLLBACK (run manually if needed)
-- =====================================================
/*
BEGIN;
DROP TABLE IF EXISTS public.apple_auth_tokens;
COMMIT;
*/
