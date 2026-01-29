CREATE OR REPLACE FUNCTION public.claim_invite(p_token TEXT)
RETURNS TABLE (
  result TEXT,
  inviter_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invite RECORD;
  v_inviter_id UUID;
  v_claimant_id UUID;
BEGIN
  v_claimant_id := auth.uid();

  IF v_claimant_id IS NULL THEN
    RETURN QUERY SELECT 'not_authenticated'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  SELECT *
  INTO v_invite
  FROM public.invites
  WHERE token = p_token
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT 'invalid'::TEXT, NULL::UUID;
    RETURN;
  END IF;

  v_inviter_id := v_invite.inviter_id;

  IF v_invite.claimed_by IS NOT NULL THEN
    RETURN QUERY SELECT 'already_used'::TEXT, v_inviter_id;
    RETURN;
  END IF;

  IF v_invite.expires_at <= now() THEN
    RETURN QUERY SELECT 'expired'::TEXT, v_inviter_id;
    RETURN;
  END IF;

  IF v_inviter_id = v_claimant_id THEN
    RETURN QUERY SELECT 'self_invite'::TEXT, v_inviter_id;
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.friendships f
    WHERE f.status = 'blocked'
      AND (
        (f.requester_id = v_claimant_id AND f.addressee_id = v_inviter_id) OR
        (f.requester_id = v_inviter_id AND f.addressee_id = v_claimant_id) OR
        (f.user_id = v_claimant_id AND f.friend_id = v_inviter_id) OR
        (f.user_id = v_inviter_id AND f.friend_id = v_claimant_id)
      )
  ) THEN
    RETURN QUERY SELECT 'blocked'::TEXT, v_inviter_id;
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.friendships f
    WHERE f.status = 'accepted'
      AND (
        (f.requester_id = v_claimant_id AND f.addressee_id = v_inviter_id) OR
        (f.requester_id = v_inviter_id AND f.addressee_id = v_claimant_id) OR
        (f.user_id = v_claimant_id AND f.friend_id = v_inviter_id) OR
        (f.user_id = v_inviter_id AND f.friend_id = v_claimant_id)
      )
  ) THEN
    RETURN QUERY SELECT 'already_friends'::TEXT, v_inviter_id;
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.friendships f
    WHERE f.status = 'pending'
      AND (
        (f.requester_id = v_claimant_id AND f.addressee_id = v_inviter_id) OR
        (f.requester_id = v_inviter_id AND f.addressee_id = v_claimant_id) OR
        (f.user_id = v_claimant_id AND f.friend_id = v_inviter_id) OR
        (f.user_id = v_inviter_id AND f.friend_id = v_claimant_id)
      )
  ) THEN
    RETURN QUERY SELECT 'pending_exists'::TEXT, v_inviter_id;
    RETURN;
  END IF;

  UPDATE public.invites
  SET claimed_by = v_claimant_id,
      claimed_at = now()
  WHERE id = v_invite.id
    AND claimed_by IS NULL
    AND expires_at > now();

  IF NOT FOUND THEN
    RETURN QUERY SELECT 'already_used'::TEXT, v_inviter_id;
    RETURN;
  END IF;

  BEGIN
    INSERT INTO public.friendships (
      user_id,
      friend_id,
      requester_id,
      addressee_id,
      status,
      created_at
    ) VALUES (
      v_claimant_id,
      v_inviter_id,
      v_claimant_id,
      v_inviter_id,
      'pending',
      now()
    );
  EXCEPTION
    WHEN unique_violation THEN
      RETURN QUERY SELECT 'pending_exists'::TEXT, v_inviter_id;
      RETURN;
  END;

  RETURN QUERY SELECT 'claimed'::TEXT, v_inviter_id;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_invite(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_invite(TEXT) TO authenticated;
