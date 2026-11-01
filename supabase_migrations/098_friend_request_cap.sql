-- DanDarts Database Migration 098
-- Purpose: Clubs (part 6 of 6): cap friend requests at 50 per person per 24 hours.
-- Why:     Open clubs let anyone join and see the member list, so without a cap a stranger could
--          join a big club and send a request to everyone. Today there is no limit at all.
-- Spec:    docs/superpowers/specs/2026-11-01-clubs-design.md
-- Safety:  Adds one BEFORE INSERT trigger on public.friendships. It only looks at new 'pending'
--          rows, never at blocks, accepts or updates, so existing friendships are unaffected.
--          Also covers requests created by claim_invite. The 50 lives in one place below.
--          Apps map the error text 'friend_request_limit' to a friendly message.
--          To change the limit later, re-run this file with a different number.

BEGIN;

CREATE OR REPLACE FUNCTION public.friendships_request_cap()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_limit CONSTANT INTEGER := 50;
BEGIN
  IF NEW.status = 'pending' THEN
    IF (
      SELECT count(*)
      FROM public.friendships f
      WHERE f.requester_id = NEW.requester_id
        AND f.status <> 'blocked'
        AND f.created_at > now() - interval '24 hours'
    ) >= v_limit THEN
      RAISE EXCEPTION 'friend_request_limit' USING ERRCODE = 'P0001';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS friendships_request_cap ON public.friendships;
CREATE TRIGGER friendships_request_cap
  BEFORE INSERT ON public.friendships
  FOR EACH ROW EXECUTE FUNCTION public.friendships_request_cap();

DO $$
BEGIN
  RAISE NOTICE 'Migration 098 complete: friend request cap (50 per 24 hours)';
END $$;

COMMIT;
