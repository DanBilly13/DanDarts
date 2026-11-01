-- DanDarts Database Migration 093
-- Purpose: Clubs (part 1 of 6): tables, helper functions and the users.club_discoverable flag.
-- Spec:    docs/superpowers/specs/2026-11-01-clubs-design.md
-- Safety:  Additive only. Creates new tables and functions and adds one column with a default
--          to public.users. Nothing existing is dropped or rewritten. Safe to re-run.
-- Apply:   Supabase SQL editor. First run it wrapped in BEGIN; ... ROLLBACK; to prove it applies,
--          then run it again with COMMIT. Apply 093 to 098 in order.

BEGIN;

-- Pre-flight: the tables this feature builds on must look the way the migrations say.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'friendships' AND column_name = 'requester_id'
  ) OR NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'friendships' AND column_name = 'addressee_id'
  ) OR NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'friendships' AND column_name = 'status'
  ) THEN
    RAISE EXCEPTION 'Pre-flight failed: public.friendships does not have requester_id, addressee_id and status';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'avatar_url'
  ) THEN
    RAISE EXCEPTION 'Pre-flight failed: public.users does not have avatar_url';
  END IF;
END $$;

-- Lower case, punctuation turned into single spaces. Used to spot duplicate club names and to
-- match the blocked-word list. Accents are kept (cafe and cafe-with-accent stay different).
CREATE OR REPLACE FUNCTION public.club_normalize(p_text TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT lower(btrim(regexp_replace(coalesce(p_text, ''), '[^[:alnum:]]+', ' ', 'g')));
$$;

CREATE TABLE IF NOT EXISTS public.clubs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL CHECK (char_length(name) BETWEEN 3 AND 40),
  name_key      TEXT NOT NULL,
  town          TEXT CHECK (town IS NULL OR char_length(town) <= 40),
  town_key      TEXT,
  visibility    TEXT NOT NULL DEFAULT 'open' CHECK (visibility IN ('open', 'invite')),
  join_code     TEXT NOT NULL UNIQUE,
  member_count  INTEGER NOT NULL DEFAULT 0,
  created_by    UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Only Open clubs must be unique per name and town; hidden clubs may repeat.
CREATE UNIQUE INDEX IF NOT EXISTS clubs_open_name_town_key
  ON public.clubs (name_key, (coalesce(town_key, '')))
  WHERE visibility = 'open';

CREATE TABLE IF NOT EXISTS public.club_members (
  club_id    UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role       TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'member')),
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (club_id, user_id)
);

CREATE INDEX IF NOT EXISTS club_members_user_id_idx ON public.club_members (user_id);

CREATE TABLE IF NOT EXISTS public.club_suggestion_dismissals (
  user_id            UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  suggested_user_id  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, suggested_user_id)
);

CREATE TABLE IF NOT EXISTS public.reports (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id  UUID REFERENCES public.users(id) ON DELETE SET NULL,
  target_type  TEXT NOT NULL CHECK (target_type IN ('club', 'user')),
  target_id    UUID NOT NULL,
  reason       TEXT CHECK (reason IS NULL OR char_length(reason) <= 500),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS reports_created_at_idx ON public.reports (created_at DESC);

-- Whole words, lower case. Matched against the normalised club name, word by word.
CREATE TABLE IF NOT EXISTS public.blocked_words (
  word TEXT PRIMARY KEY CHECK (word = lower(word) AND char_length(word) >= 2)
);

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS club_discoverable BOOLEAN NOT NULL DEFAULT true;

-- Six characters from an alphabet without 0/O/1/I/L; cryptographically random bytes (uuid),
-- retried until the code is unused.
CREATE OR REPLACE FUNCTION public.generate_club_code()
RETURNS TEXT
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_alphabet CONSTANT TEXT := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_bytes BYTEA;
  v_code TEXT;
  i INTEGER;
BEGIN
  LOOP
    v_bytes := decode(replace(gen_random_uuid()::TEXT, '-', ''), 'hex');
    v_code := '';
    FOR i IN 0..5 LOOP
      v_code := v_code || substr(v_alphabet, 1 + (get_byte(v_bytes, i) % length(v_alphabet)), 1);
    END LOOP;
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.clubs c WHERE c.join_code = v_code);
  END LOOP;
  RETURN v_code;
END;
$$;

REVOKE ALL ON FUNCTION public.generate_club_code() FROM PUBLIC, anon, authenticated;

DO $$
BEGIN
  RAISE NOTICE 'Migration 093 complete: clubs tables, club_normalize, generate_club_code, users.club_discoverable';
END $$;

COMMIT;
