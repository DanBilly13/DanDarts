-- DanDarts Database Migration 102
-- Purpose: Clubs: invite your DartFreak friends to a club from inside the app. The friend sees
--          "Dan invited you to The Crown" on their Clubs tab with Join / No thanks.
-- Safety:  Additive only. One new table (no direct access; everything goes through the
--          functions below), two triggers, five functions. Safe to re-run.
-- Apply:   Supabase SQL editor, after 101. First run it with the final COMMIT changed to
--          ROLLBACK to prove it applies, then run it again with COMMIT.
-- Rules:   - Any member can invite, Open or Invite-only (like sharing the link), but only people
--            they're already friends with (accepted, either direction) and nobody either side
--            has blocked.
--          - Nobody is added without saying yes. Accepting joins the club even when it is
--            Invite-only (the invite stands in for the link), within the 5-club limit.
--          - An invite lasts 30 days. It disappears if the inviter leaves the club, if the
--            invitee joins some other way, or if the club is deleted.
--          Result codes: ok, not_authenticated, not_member, not_friend, blocked, already_member,
--          already_invited, not_found, club_limit, too_many.

BEGIN;

CREATE TABLE IF NOT EXISTS public.club_invites (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id     UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  inviter_id  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  invitee_id  UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (inviter_id <> invitee_id)
);

-- One open invite per person per club, whoever sent it.
CREATE UNIQUE INDEX IF NOT EXISTS club_invites_one_pending
  ON public.club_invites (club_id, invitee_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS club_invites_invitee_idx ON public.club_invites (invitee_id) WHERE status = 'pending';

REVOKE ALL ON public.club_invites FROM anon, authenticated;
ALTER TABLE public.club_invites ENABLE ROW LEVEL SECURITY;

-- Clean-up: a member leaving takes their pending invites with them; joining (any way) clears
-- the invites waiting for you in that club.
CREATE OR REPLACE FUNCTION public.club_invites_on_member_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    DELETE FROM public.club_invites
    WHERE club_id = OLD.club_id AND inviter_id = OLD.user_id AND status = 'pending';
    RETURN OLD;
  END IF;
  UPDATE public.club_invites SET status = 'accepted'
  WHERE club_id = NEW.club_id AND invitee_id = NEW.user_id AND status = 'pending';
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.club_invites_on_member_change() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS club_invites_member_left ON public.club_members;
CREATE TRIGGER club_invites_member_left
  AFTER DELETE ON public.club_members
  FOR EACH ROW EXECUTE FUNCTION public.club_invites_on_member_change();

DROP TRIGGER IF EXISTS club_invites_member_joined ON public.club_members;
CREATE TRIGGER club_invites_member_joined
  AFTER INSERT ON public.club_members
  FOR EACH ROW EXECUTE FUNCTION public.club_invites_on_member_change();

-- Invite up to 50 friends at once. One row back per person, with its result.
CREATE OR REPLACE FUNCTION public.invite_to_club(p_club_id UUID, p_user_ids UUID[])
RETURNS TABLE (user_id UUID, result TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_uid UUID := auth.uid();
  v_target UUID;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT NULL::UUID, 'not_authenticated'::TEXT;
    RETURN;
  END IF;
  IF NOT public.is_club_member(p_club_id) THEN
    RETURN QUERY SELECT NULL::UUID, 'not_member'::TEXT;
    RETURN;
  END IF;
  IF coalesce(array_length(p_user_ids, 1), 0) > 50 THEN
    RETURN QUERY SELECT NULL::UUID, 'too_many'::TEXT;
    RETURN;
  END IF;

  FOREACH v_target IN ARRAY coalesce(p_user_ids, ARRAY[]::UUID[]) LOOP
    IF v_target = v_uid THEN
      CONTINUE;
    ELSIF EXISTS (
      SELECT 1 FROM public.friendships f
      WHERE f.status = 'blocked'
        AND ((f.requester_id = v_uid AND f.addressee_id = v_target)
          OR (f.requester_id = v_target AND f.addressee_id = v_uid))
    ) THEN
      RETURN QUERY SELECT v_target, 'blocked'::TEXT;
    ELSIF NOT EXISTS (
      SELECT 1 FROM public.friendships f
      WHERE f.status = 'accepted'
        AND ((f.requester_id = v_uid AND f.addressee_id = v_target)
          OR (f.requester_id = v_target AND f.addressee_id = v_uid))
    ) THEN
      RETURN QUERY SELECT v_target, 'not_friend'::TEXT;
    ELSIF EXISTS (SELECT 1 FROM public.club_members m WHERE m.club_id = p_club_id AND m.user_id = v_target) THEN
      RETURN QUERY SELECT v_target, 'already_member'::TEXT;
    ELSIF EXISTS (
      SELECT 1 FROM public.club_invites i
      WHERE i.club_id = p_club_id AND i.invitee_id = v_target AND i.status = 'pending'
        AND i.created_at > now() - interval '30 days'
    ) THEN
      RETURN QUERY SELECT v_target, 'already_invited'::TEXT;
    ELSE
      -- An expired pending invite is replaced by the new one.
      DELETE FROM public.club_invites i
      WHERE i.club_id = p_club_id AND i.invitee_id = v_target AND i.status = 'pending';
      INSERT INTO public.club_invites (club_id, inviter_id, invitee_id)
      VALUES (p_club_id, v_uid, v_target);
      RETURN QUERY SELECT v_target, 'ok'::TEXT;
    END IF;
  END LOOP;
END;
$$;

-- For a member's Invite sheet: who already has an open invite to this club.
CREATE OR REPLACE FUNCTION public.club_pending_invitees(p_club_id UUID)
RETURNS TABLE (user_id UUID)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_club_member(p_club_id) THEN
    RETURN;
  END IF;
  RETURN QUERY
  SELECT i.invitee_id FROM public.club_invites i
  WHERE i.club_id = p_club_id AND i.status = 'pending' AND i.created_at > now() - interval '30 days';
END;
$$;

-- The invites waiting for the caller, newest first, with what the card needs.
CREATE OR REPLACE FUNCTION public.my_club_invites()
RETURNS TABLE (
  invite_id UUID,
  club_id UUID,
  club_name TEXT,
  club_town TEXT,
  club_image_url TEXT,
  member_count INTEGER,
  inviter_id UUID,
  inviter_name TEXT,
  inviter_avatar_url TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;
  RETURN QUERY
  SELECT i.id, c.id, c.name, c.town, c.image_url, c.member_count,
         u.id, u.display_name, u.avatar_url, i.created_at
  FROM public.club_invites i
  JOIN public.clubs c ON c.id = i.club_id
  JOIN public.users u ON u.id = i.inviter_id
  WHERE i.invitee_id = v_uid
    AND i.status = 'pending'
    AND i.created_at > now() - interval '30 days'
    AND NOT EXISTS (
      SELECT 1 FROM public.friendships f
      WHERE f.status = 'blocked'
        AND ((f.requester_id = v_uid AND f.addressee_id = i.inviter_id)
          OR (f.requester_id = i.inviter_id AND f.addressee_id = v_uid))
    )
  ORDER BY i.created_at DESC;
END;
$$;

-- Join (p_accept true) or say no thanks. Joining works for Invite-only clubs too.
CREATE OR REPLACE FUNCTION public.respond_to_club_invite(p_invite_id UUID, p_accept BOOLEAN)
RETURNS TABLE (result TEXT, club_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_uid UUID := auth.uid();
  v_club UUID;
BEGIN
  IF v_uid IS NULL THEN
    RETURN QUERY SELECT 'not_authenticated'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  SELECT i.club_id INTO v_club
  FROM public.club_invites i
  WHERE i.id = p_invite_id AND i.invitee_id = v_uid AND i.status = 'pending'
    AND i.created_at > now() - interval '30 days';
  IF NOT FOUND THEN
    RETURN QUERY SELECT 'not_found'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  IF NOT p_accept THEN
    UPDATE public.club_invites SET status = 'declined' WHERE id = p_invite_id;
    RETURN QUERY SELECT 'ok'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM public.club_members m WHERE m.club_id = v_club AND m.user_id = v_uid) THEN
    UPDATE public.club_invites SET status = 'accepted' WHERE id = p_invite_id;
    RETURN QUERY SELECT 'already_member'::TEXT, v_club;
    RETURN;
  END IF;

  IF (SELECT count(*) FROM public.club_members m WHERE m.user_id = v_uid) >= 5 THEN
    RETURN QUERY SELECT 'club_limit'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  BEGIN
    -- The member trigger marks this invite (and any other for this club) accepted.
    INSERT INTO public.club_members (club_id, user_id, role) VALUES (v_club, v_uid, 'member');
  EXCEPTION
    WHEN unique_violation THEN
      RETURN QUERY SELECT 'already_member'::TEXT, v_club;
      RETURN;
    WHEN raise_exception THEN
      RETURN QUERY SELECT 'club_limit'::TEXT, NULL::UUID;
      RETURN;
  END;

  RETURN QUERY SELECT 'ok'::TEXT, v_club;
END;
$$;

REVOKE ALL ON FUNCTION public.invite_to_club(UUID, UUID[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.club_pending_invitees(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.my_club_invites() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.respond_to_club_invite(UUID, BOOLEAN) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.invite_to_club(UUID, UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_pending_invitees(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_club_invites() TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_club_invite(UUID, BOOLEAN) TO authenticated;

DO $$
BEGIN
  RAISE NOTICE 'Migration 102 complete: club invites between friends';
END $$;

COMMIT;
