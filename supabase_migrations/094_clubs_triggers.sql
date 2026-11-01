-- DanDarts Database Migration 094
-- Purpose: Clubs (part 2 of 6): member count, five-club limit, admin hand-over and empty-club cleanup.
-- Spec:    docs/superpowers/specs/2026-11-01-clubs-design.md
-- Safety:  Additive only. New trigger functions and triggers on the new club_members table.
--          Safe to re-run (DROP TRIGGER IF EXISTS before each CREATE TRIGGER).

BEGIN;

-- A person can be in at most five clubs. RPCs check this first and return a friendly code;
-- this is the backstop.
CREATE OR REPLACE FUNCTION public.club_members_before_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF (SELECT count(*) FROM public.club_members m WHERE m.user_id = NEW.user_id) >= 5 THEN
    RAISE EXCEPTION 'club_limit' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS club_members_before_insert ON public.club_members;
CREATE TRIGGER club_members_before_insert
  BEFORE INSERT ON public.club_members
  FOR EACH ROW EXECUTE FUNCTION public.club_members_before_insert();

CREATE OR REPLACE FUNCTION public.club_members_after_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.clubs c
  SET member_count = (SELECT count(*) FROM public.club_members m WHERE m.club_id = NEW.club_id)
  WHERE c.id = NEW.club_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS club_members_after_insert ON public.club_members;
CREATE TRIGGER club_members_after_insert
  AFTER INSERT ON public.club_members
  FOR EACH ROW EXECUTE FUNCTION public.club_members_after_insert();

-- Runs for every way a membership can disappear: leaving, being removed, the account being
-- deleted, or the club being deleted. Recounts, deletes an empty club, and makes sure a club
-- that still has members always has an admin (the longest-standing member).
CREATE OR REPLACE FUNCTION public.club_members_after_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_next_user UUID;
BEGIN
  UPDATE public.clubs c
  SET member_count = (SELECT count(*) FROM public.club_members m WHERE m.club_id = OLD.club_id)
  WHERE c.id = OLD.club_id;

  -- The club itself is already gone (cascade); nothing more to do.
  IF NOT FOUND THEN
    RETURN OLD;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.club_members m WHERE m.club_id = OLD.club_id) THEN
    DELETE FROM public.clubs c WHERE c.id = OLD.club_id;
    RETURN OLD;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.club_members m WHERE m.club_id = OLD.club_id AND m.role = 'admin'
  ) THEN
    SELECT m.user_id INTO v_next_user
    FROM public.club_members m
    WHERE m.club_id = OLD.club_id
    ORDER BY m.joined_at, m.user_id
    LIMIT 1;

    UPDATE public.club_members m
    SET role = 'admin'
    WHERE m.club_id = OLD.club_id AND m.user_id = v_next_user;
  END IF;

  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS club_members_after_delete ON public.club_members;
CREATE TRIGGER club_members_after_delete
  AFTER DELETE ON public.club_members
  FOR EACH ROW EXECUTE FUNCTION public.club_members_after_delete();

REVOKE ALL ON FUNCTION public.club_members_before_insert() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.club_members_after_insert() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.club_members_after_delete() FROM PUBLIC;

DO $$
BEGIN
  RAISE NOTICE 'Migration 094 complete: club member triggers';
END $$;

COMMIT;
