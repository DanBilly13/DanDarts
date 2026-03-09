-- 067_fix_matches_players_data_format.sql
-- Fix PostgrestError 22023 "cannot extract elements from a scalar"
-- Root cause: jsonb_array_elements(m.players) in RLS policies crashes when matches.players is not a JSON array.
-- Strategy:
--   1) Normalize old matches.players so it is always a JSON array
--   2) Replace any unsafe policies that call jsonb_array_elements(m.players) without guarding jsonb_typeof()
--   3) Verify

begin;

-- ============================================================
-- 1) Diagnose: show broken matches (players is NULL or not array)
-- ============================================================
-- (Leave as SELECT for visibility in SQL editor / logs)
select
  id,
  match_mode,
  game_name,
  created_at,
  jsonb_typeof(players) as players_type,
  players
from public.matches
where players is null
   or jsonb_typeof(players) <> 'array'
order by created_at asc
limit 200;

-- ============================================================
-- 2) Normalize data: make matches.players always a JSON array
-- ============================================================

-- A) NULL -> []
update public.matches
set players = '[]'::jsonb
where players is null;

-- B) OBJECT -> wrap as [object]
update public.matches
set players = jsonb_build_array(players)
where jsonb_typeof(players) = 'object';

-- NOTE:
-- If you suspect some rows store a JSON *string* (e.g. "\"[{...}]\""),
-- that's rarer; fix manually after inspecting the diagnostic output above.

-- ============================================================
-- 3) Fix policies: make jsonb_array_elements(m.players) SAFE
-- ============================================================
-- We don't know the exact policy names in your project from here,
-- so we'll:
--   - Drop/recreate the specific known-bad policy if it exists
--   - Provide a safe template you should apply to any policy that uses jsonb_array_elements(matches.players)

-- ---- 3a) match_players SELECT policy (safe version)
-- If your policy name differs, adjust the DROP POLICY line to match.

drop policy if exists match_players_select_participants on public.match_players;

create policy match_players_select_participants
on public.match_players
for select
to authenticated
using (
  exists (
    select 1
    from public.matches m
    where m.id = match_players.match_id
      and (
        m.challenger_id = auth.uid()
        or m.receiver_id = auth.uid()
        or exists (
          select 1
          from jsonb_array_elements(
            case
              when m.players is not null and jsonb_typeof(m.players) = 'array'
                then m.players
              else '[]'::jsonb
            end
          ) as player(value)
          where (player.value ->> 'id')::uuid = auth.uid()
        )
      )
  )
);

-- ---- 3b) match_throws SELECT policy (safe version)
drop policy if exists match_throws_select_participants on public.match_throws;

create policy match_throws_select_participants
on public.match_throws
for select
to authenticated
using (
  exists (
    select 1
    from public.matches m
    where m.id = match_throws.match_id
      and (
        m.challenger_id = auth.uid()
        or m.receiver_id = auth.uid()
        or exists (
          select 1
          from jsonb_array_elements(
            case
              when m.players is not null and jsonb_typeof(m.players) = 'array'
                then m.players
              else '[]'::jsonb
            end
          ) as player(value)
          where (player.value ->> 'id')::uuid = auth.uid()
        )
      )
  )
);

-- ============================================================
-- 4) Verify: no broken matches remain
-- ============================================================
select count(*) as broken_matches_remaining
from public.matches
where players is null
   or jsonb_typeof(players) <> 'array';

-- ============================================================
-- 5) Verify: an old failing match_id no longer errors
-- (Replace with any known failing one)
-- ============================================================
-- select *
-- from public.match_throws
-- where match_id = '755af369-b595-43d9-8eed-8ba1ea34103e';

commit;
