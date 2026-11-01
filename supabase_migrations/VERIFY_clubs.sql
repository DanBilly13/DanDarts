-- VERIFY_clubs.sql
-- Purpose: end-to-end check of migrations 093-098 and 100 (Clubs). Run it AFTER applying the migrations.
-- Names:   Test clubs use the made-up prefix 'Zzvfy' and the town 'Verifyville', so the script still
--          passes after real clubs and blocked words have been added.
-- Safety:  Everything happens inside one transaction that ends in ROLLBACK, so no test users,
--          clubs or friendships are kept. It creates throw-away rows in auth.users and public.users
--          with @verify.invalid emails. Run it as the default postgres role in the Supabase SQL editor.
-- Result:  Ends with a NOTICE 'ALL CLUBS CHECKS PASSED'. The first failing check raises an
--          'Assertion failed' error that names the check; fix it, then re-run.
-- Needs:   friendships rows can be inserted with only requester_id, addressee_id and status
--          (if your live table still has NOT NULL user_id/friend_id columns the friendship
--          checks will fail on insert, not on the feature).

BEGIN;

-- Only sets who "auth.uid()" is; the role switch happens inline below.
CREATE OR REPLACE FUNCTION pg_temp.as_user(p_user UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', p_user::TEXT, 'role', 'authenticated')::TEXT, true);
  PERFORM set_config('request.jwt.claim.sub', p_user::TEXT, true);
END;
$$;

DO $$
DECLARE
  u1 UUID := gen_random_uuid();
  u2 UUID := gen_random_uuid();
  u3 UUID := gen_random_uuid();
  u4 UUID := gen_random_uuid();
  u5 UUID := gen_random_uuid();
  v_res TEXT;
  v_id UUID;
  c1 UUID;
  c2 UUID;
  c3 UUID;
  v_n INTEGER;
  v_code TEXT;
  v_code2 TEXT;
  v_role TEXT;
  i INTEGER;
BEGIN
  -- ---------- set-up (as postgres) ----------
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  SELECT x, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         x::TEXT || '@verify.invalid', now(), now()
  FROM unnest(ARRAY[u1, u2, u3, u4, u5]) AS x;

  INSERT INTO public.users (id, display_name, nickname)
  SELECT x, 'Verify ' || substr(x::TEXT, 1, 4), 'vfy_' || substr(replace(x::TEXT, '-', ''), 1, 8)
  FROM unnest(ARRAY[u1, u2, u3, u4, u5]) AS x;

  -- ---------- name normaliser keeps non-ASCII letters (needs a UTF-8 database locale) ----------
  ASSERT public.club_normalize('Café  Ünï, Ärrows!') = 'café ünï ärrows',
    'club_normalize must keep accented letters: got ' || public.club_normalize('Café  Ünï, Ärrows!');

  -- ---------- signed-out users and direct writes are refused ----------
  RESET ROLE; SET LOCAL ROLE anon;
  BEGIN
    PERFORM public.create_club('Zzvfy Anon Club');
    RAISE EXCEPTION 'anon was allowed to call create_club';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  RESET ROLE; PERFORM pg_temp.as_user(u1); SET LOCAL ROLE authenticated;
  BEGIN
    INSERT INTO public.reports (reporter_id, target_type, target_id) VALUES (u1, 'user', u2);
    RAISE EXCEPTION 'a signed-in user was allowed to insert into reports directly';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  BEGIN
    INSERT INTO public.clubs (name, name_key, join_code) VALUES ('Zzvfy Direct', 'zzvfy direct', 'DIRECT');
    RAISE EXCEPTION 'a signed-in user was allowed to insert into clubs directly';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;

  -- ---------- create ----------
  RESET ROLE; PERFORM pg_temp.as_user(u1); SET LOCAL ROLE authenticated;

  SELECT r.result, r.club_id INTO v_res, c1 FROM public.create_club('Zzvfy Crown Inn', 'Verifyville', 'open') r;
  ASSERT v_res = 'ok' AND c1 IS NOT NULL, 'create open club: got ' || coalesce(v_res, 'null');

  SELECT r.result, r.club_id INTO v_res, v_id FROM public.create_club('Zzvfy Crown Inn', 'Verifyville', 'open') r;
  ASSERT v_res = 'duplicate' AND v_id = c1, 'exact duplicate open club: got ' || coalesce(v_res, 'null');

  SELECT r.result INTO v_res FROM public.create_club('ab', NULL, 'open') r;
  ASSERT v_res = 'invalid_name', 'too-short name: got ' || coalesce(v_res, 'null');

  SELECT r.result INTO v_res FROM public.create_club('Fine Name', NULL, 'secret') r;
  ASSERT v_res = 'invalid_visibility', 'bad visibility: got ' || coalesce(v_res, 'null');

  SELECT r.result, r.club_id INTO v_res, c2 FROM public.create_club('Zzvfy Lads', NULL, 'invite') r;
  ASSERT v_res = 'ok', 'create invite-only club: got ' || coalesce(v_res, 'null');

  RESET ROLE; PERFORM pg_temp.as_user(u2); SET LOCAL ROLE authenticated;

  SELECT r.result INTO v_res FROM public.create_club('zzvfy  CROWN inn!', 'verifyville', 'open') r;
  ASSERT v_res = 'duplicate', 'duplicate after normalising name and town: got ' || coalesce(v_res, 'null');

  SELECT r.result, r.club_id INTO v_res, c3 FROM public.create_club('Zzvfy Lads', NULL, 'invite') r;
  ASSERT v_res = 'ok', 'invite-only duplicates are allowed: got ' || coalesce(v_res, 'null');

  -- ---------- name filter (whole words only) ----------
  RESET ROLE;
  INSERT INTO public.blocked_words (word) VALUES ('badword'), ('ass') ON CONFLICT DO NOTHING;
  PERFORM pg_temp.as_user(u2); SET LOCAL ROLE authenticated;

  SELECT r.result INTO v_res FROM public.create_club('The Badword Inn', NULL, 'open') r;
  ASSERT v_res = 'name_not_allowed', 'blocked word is rejected: got ' || coalesce(v_res, 'null');

  SELECT r.result INTO v_res FROM public.create_club('Zzvfy Glasshouse Arms', NULL, 'open') r;
  ASSERT v_res = 'ok', 'a blocked word inside another word is allowed: got ' || coalesce(v_res, 'null');

  -- ---------- search and visibility ----------
  RESET ROLE; PERFORM pg_temp.as_user(u3); SET LOCAL ROLE authenticated;

  SELECT count(*) INTO v_n FROM public.search_clubs('zzvfy crown');
  ASSERT v_n = 1, 'search finds the open club: got ' || v_n;

  SELECT count(*) INTO v_n FROM public.search_clubs('verifyville');
  ASSERT v_n = 1, 'search matches the town: got ' || v_n;

  SELECT count(*) INTO v_n FROM public.search_clubs('zzvfy lads');
  ASSERT v_n = 0, 'invite-only clubs are hidden from search: got ' || v_n;

  SELECT count(*) INTO v_n FROM public.search_clubs('c');
  ASSERT v_n = 0, 'one-character search returns nothing: got ' || v_n;

  SELECT count(*) INTO v_n FROM public.get_club_preview(c2);
  ASSERT v_n = 0, 'invite-only preview hidden from non-members: got ' || v_n;

  SELECT count(*) INTO v_n FROM public.get_club_preview(c1);
  ASSERT v_n = 1, 'open club preview visible to non-members: got ' || v_n;

  SELECT count(*) INTO v_n FROM public.club_members WHERE club_id = c1;
  ASSERT v_n = 0, 'non-member cannot read club_members: got ' || v_n;

  SELECT count(*) INTO v_n FROM public.clubs WHERE id = c1;
  ASSERT v_n = 0, 'non-member cannot read clubs directly: got ' || v_n;

  SELECT count(*) INTO v_n FROM public.club_members_list(c1);
  ASSERT v_n = 0, 'non-member gets no member list: got ' || v_n;

  -- ---------- join ----------
  SELECT r.result INTO v_res FROM public.join_club(c1) r;
  ASSERT v_res = 'ok', 'join open club: got ' || coalesce(v_res, 'null');

  SELECT r.result INTO v_res FROM public.join_club(c1) r;
  ASSERT v_res = 'already_member', 'joining twice: got ' || coalesce(v_res, 'null');

  SELECT r.result INTO v_res FROM public.join_club(c2) r;
  ASSERT v_res = 'not_found', 'cannot join an invite-only club by id: got ' || coalesce(v_res, 'null');

  SELECT count(*) INTO v_n FROM public.club_members WHERE club_id = c1;
  ASSERT v_n = 2, 'a member can read the member rows: got ' || v_n;

  RESET ROLE; PERFORM pg_temp.as_user(u2); SET LOCAL ROLE authenticated;
  SELECT r.result INTO v_res FROM public.join_club(c1) r;
  ASSERT v_res = 'ok', 'u2 joins the open club too: got ' || coalesce(v_res, 'null');

  -- Everything here runs in one transaction, so every join shares one timestamp. Give the
  -- members distinct join dates so "longest-standing member" is well defined, as it is in real use.
  RESET ROLE;
  UPDATE public.club_members SET joined_at = now() - interval '3 days' WHERE club_id = c1 AND user_id = u1;
  UPDATE public.club_members SET joined_at = now() - interval '2 days' WHERE club_id = c1 AND user_id = u3;
  UPDATE public.club_members SET joined_at = now() - interval '1 day'  WHERE club_id = c1 AND user_id = u2;
  SELECT cl.join_code INTO v_code FROM public.clubs cl WHERE cl.id = c2;
  PERFORM pg_temp.as_user(u4); SET LOCAL ROLE authenticated;

  SELECT r.result INTO v_res FROM public.join_club_by_code('NOPE99') r;
  ASSERT v_res = 'invalid_code', 'unknown code: got ' || coalesce(v_res, 'null');

  SELECT count(*) INTO v_n FROM public.preview_club_by_code('NOPE99');
  ASSERT v_n = 0, 'preview by unknown code returns nothing: got ' || v_n;

  SELECT count(*) INTO v_n FROM public.preview_club_by_code(lower(substr(v_code, 1, 3)) || ' ' || substr(v_code, 4))
  WHERE club_id = c2 AND visibility = 'invite' AND NOT is_member AND name LIKE 'Zzvfy%';
  ASSERT v_n = 1, 'preview by code names an invite-only club for a non-member (case and spaces ignored): got ' || v_n;

  SELECT r.result, r.club_id INTO v_res, v_id
  FROM public.join_club_by_code(lower(substr(v_code, 1, 3)) || ' ' || substr(v_code, 4)) r;
  ASSERT v_res = 'ok' AND v_id = c2, 'join invite-only club by code (case and spaces ignored): got ' || coalesce(v_res, 'null');

  SELECT count(*) INTO v_n FROM public.preview_club_by_code(v_code) WHERE is_member AND member_count >= 2;
  ASSERT v_n = 1, 'preview by code shows is_member once joined: got ' || v_n;

  -- ---------- five-club limit ----------
  RESET ROLE; PERFORM pg_temp.as_user(u5); SET LOCAL ROLE authenticated;

  FOR i IN 1..5 LOOP
    SELECT r.result INTO v_res FROM public.create_club('Zzvfy Limit ' || i, NULL, 'invite') r;
    ASSERT v_res = 'ok', 'club ' || i || ' of 5 for one user: got ' || coalesce(v_res, 'null');
  END LOOP;

  SELECT r.result INTO v_res FROM public.create_club('Zzvfy Limit 6', NULL, 'invite') r;
  ASSERT v_res = 'club_limit', 'sixth club is refused: got ' || coalesce(v_res, 'null');

  SELECT r.result INTO v_res FROM public.join_club(c1) r;
  ASSERT v_res = 'club_limit', 'joining a sixth club is refused: got ' || coalesce(v_res, 'null');

  -- ---------- suggestions (u1: c1 + c2, u2: c1 + c3, u3: c1, u4: c2) ----------
  RESET ROLE; PERFORM pg_temp.as_user(u1); SET LOCAL ROLE authenticated;

  SELECT count(*) INTO v_n FROM public.club_suggestions(20);
  ASSERT v_n = 3, 'u1 sees u2, u3 and u4 as suggestions: got ' || v_n;

  RESET ROLE;
  UPDATE public.users SET club_discoverable = false WHERE id = u3;
  PERFORM pg_temp.as_user(u1); SET LOCAL ROLE authenticated;
  SELECT count(*) INTO v_n FROM public.club_suggestions(20);
  ASSERT v_n = 2, 'someone who switched off "find me" is left out: got ' || v_n;

  SELECT public.dismiss_club_suggestion(u2) INTO v_res;
  ASSERT v_res = 'ok', 'dismiss: got ' || coalesce(v_res, 'null');
  SELECT count(*) INTO v_n FROM public.club_suggestions(20);
  ASSERT v_n = 1, 'a dismissed person is left out: got ' || v_n;

  RESET ROLE;
  INSERT INTO public.friendships (requester_id, addressee_id, status) VALUES (u1, u4, 'pending');
  PERFORM pg_temp.as_user(u1); SET LOCAL ROLE authenticated;
  SELECT count(*) INTO v_n FROM public.club_suggestions(20);
  ASSERT v_n = 0, 'anyone with a friendship row (pending) is left out: got ' || v_n;

  RESET ROLE;
  DELETE FROM public.friendships WHERE requester_id = u1 AND addressee_id = u4;
  INSERT INTO public.friendships (requester_id, addressee_id, status) VALUES (u4, u1, 'blocked');
  PERFORM pg_temp.as_user(u1); SET LOCAL ROLE authenticated;
  SELECT count(*) INTO v_n FROM public.club_suggestions(20);
  ASSERT v_n = 0, 'a blocked person is left out: got ' || v_n;

  SELECT relationship INTO v_res FROM public.club_members_list(c2) WHERE user_id = u4;
  ASSERT v_res = 'blocked', 'member list shows blocked state: got ' || coalesce(v_res, 'null');

  RESET ROLE;
  DELETE FROM public.friendships WHERE requester_id = u4 AND addressee_id = u1;

  -- ---------- admin actions on c2 (admin u1, member u4) ----------
  PERFORM pg_temp.as_user(u4); SET LOCAL ROLE authenticated;
  SELECT public.remove_club_member(c2, u1) INTO v_res;
  ASSERT v_res = 'not_admin', 'a member cannot remove people: got ' || coalesce(v_res, 'null');
  SELECT public.set_club_visibility(c2, 'open') INTO v_res;
  ASSERT v_res = 'not_admin', 'a member cannot change visibility: got ' || coalesce(v_res, 'null');
  SELECT r.result INTO v_res FROM public.regenerate_club_code(c2) r;
  ASSERT v_res = 'not_admin', 'a member cannot regenerate the code: got ' || coalesce(v_res, 'null');

  RESET ROLE; PERFORM pg_temp.as_user(u1); SET LOCAL ROLE authenticated;

  SELECT r.result, r.join_code INTO v_res, v_code2 FROM public.regenerate_club_code(c2) r;
  ASSERT v_res = 'ok' AND v_code2 <> v_code, 'admin regenerates the code: got ' || coalesce(v_res, 'null');

  RESET ROLE; PERFORM pg_temp.as_user(u5); SET LOCAL ROLE authenticated;
  SELECT r.result INTO v_res FROM public.join_club_by_code(v_code) r;
  ASSERT v_res = 'invalid_code', 'the old code stops working: got ' || coalesce(v_res, 'null');

  RESET ROLE; PERFORM pg_temp.as_user(u2); SET LOCAL ROLE authenticated;
  SELECT public.set_club_visibility(c3, 'open') INTO v_res;
  ASSERT v_res = 'ok', 'u2 opens its own Zzvfy Lads (no open twin yet): got ' || coalesce(v_res, 'null');

  RESET ROLE; PERFORM pg_temp.as_user(u1); SET LOCAL ROLE authenticated;
  SELECT public.set_club_visibility(c2, 'open') INTO v_res;
  ASSERT v_res = 'duplicate', 'cannot open a club when an open one has the same name: got ' || coalesce(v_res, 'null');

  SELECT public.remove_club_member(c2, u1) INTO v_res;
  ASSERT v_res = 'use_leave', 'admin cannot remove themselves: got ' || coalesce(v_res, 'null');
  SELECT public.remove_club_member(c2, u4) INTO v_res;
  ASSERT v_res = 'ok', 'admin removes a member: got ' || coalesce(v_res, 'null');

  -- ---------- reports ----------
  SELECT public.report_content('club', c2, 'test report') INTO v_res;
  ASSERT v_res = 'ok', 'report a club: got ' || coalesce(v_res, 'null');
  SELECT public.report_content('user', u2, NULL) INTO v_res;
  ASSERT v_res = 'ok', 'report a user: got ' || coalesce(v_res, 'null');
  SELECT public.report_content('user', u2, 'again') INTO v_res;
  ASSERT v_res = 'ok', 'a repeat report is accepted quietly: got ' || coalesce(v_res, 'null');
  RESET ROLE;
  SELECT count(*) INTO v_n FROM public.reports WHERE reporter_id = u1 AND target_id = u2;
  ASSERT v_n = 1, 'a repeat report within 24 hours is not stored twice: got ' || v_n;
  PERFORM pg_temp.as_user(u1); SET LOCAL ROLE authenticated;
  SELECT public.report_content('team', u2, NULL) INTO v_res;
  ASSERT v_res = 'invalid_type', 'bad report type: got ' || coalesce(v_res, 'null');
  SELECT public.report_content('club', gen_random_uuid(), NULL) INTO v_res;
  ASSERT v_res = 'not_found', 'report of a missing club: got ' || coalesce(v_res, 'null');

  -- ---------- leave, hand-over and cleanup (c1: u1 admin, u2 and u3 members) ----------
  SELECT public.leave_club(c1) INTO v_res;
  ASSERT v_res = 'ok', 'admin leaves: got ' || coalesce(v_res, 'null');

  RESET ROLE;
  SELECT m.role INTO v_role FROM public.club_members m WHERE m.club_id = c1 AND m.user_id = u3;
  ASSERT v_role = 'admin', 'the longest-standing member (u3, joined before u2) becomes admin: got ' || coalesce(v_role, 'null');

  PERFORM pg_temp.as_user(u3); SET LOCAL ROLE authenticated;
  SELECT public.leave_club(c1) INTO v_res;
  ASSERT v_res = 'ok', 'u3 leaves: got ' || coalesce(v_res, 'null');

  RESET ROLE;
  SELECT m.role INTO v_role FROM public.club_members m WHERE m.club_id = c1 AND m.user_id = u2;
  ASSERT v_role = 'admin', 'the remaining member becomes admin: got ' || coalesce(v_role, 'null');

  PERFORM pg_temp.as_user(u2); SET LOCAL ROLE authenticated;
  SELECT public.leave_club(c1) INTO v_res;
  ASSERT v_res = 'ok', 'last member leaves: got ' || coalesce(v_res, 'null');

  RESET ROLE;
  SELECT count(*) INTO v_n FROM public.clubs WHERE id = c1;
  ASSERT v_n = 0, 'a club with no members is deleted: got ' || v_n;

  -- ---------- account deletion ----------
  DELETE FROM public.users WHERE id = u5;
  SELECT count(*) INTO v_n FROM public.clubs WHERE created_by IS NULL AND name LIKE 'Zzvfy Limit %';
  ASSERT v_n = 0, 'deleting the only member removes their clubs: got ' || v_n;

  -- ---------- friend-request cap ----------
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  SELECT gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'cap' || g || '@verify.invalid', now(), now()
  FROM generate_series(1, 51) g;
  INSERT INTO public.users (id, display_name, nickname)
  SELECT a.id, 'Cap ' || a.rn, 'cap_' || substr(replace(a.id::TEXT, '-', ''), 1, 8)
  FROM (SELECT id, row_number() OVER () AS rn FROM auth.users WHERE email LIKE 'cap%@verify.invalid') a;

  FOR v_id IN SELECT id FROM public.users WHERE nickname LIKE 'cap\_%' ORDER BY id LIMIT 50 LOOP
    INSERT INTO public.friendships (requester_id, addressee_id, status) VALUES (u4, v_id, 'pending');
  END LOOP;

  BEGIN
    INSERT INTO public.friendships (requester_id, addressee_id, status)
    SELECT u4, id, 'pending' FROM public.users WHERE nickname LIKE 'cap\_%'
      AND id NOT IN (SELECT addressee_id FROM public.friendships WHERE requester_id = u4) LIMIT 1;
    RAISE EXCEPTION 'the 51st friend request was not refused';
  EXCEPTION
    WHEN raise_exception THEN
      ASSERT SQLERRM = 'friend_request_limit', 'the 51st request raises friend_request_limit: got ' || SQLERRM;
  END;

  -- blocking someone must still work at the limit
  INSERT INTO public.friendships (requester_id, addressee_id, status) VALUES (u4, u3, 'blocked');

  RAISE NOTICE 'ALL CLUBS CHECKS PASSED';
END;
$$;

ROLLBACK;
