# DanDarts Database Documentation (Latest)

Comprehensive reference for the DanDarts database schema, including local matches, remote matches, RLS policies, and data flow patterns.

> **Audience:** DanDarts iOS + Supabase contributors  
> **Database:** PostgreSQL (Supabase)  
> **Schema:** `public`  
> **Last updated:** 2026-03-09  
> **This document:** **LATEST** — supersedes older DanDarts database docs.

---

## Table of Contents

- [Overview](#overview)
- [Golden Rules](#golden-rules)
- [Core Tables](#core-tables)
  - [`users`](#users)
  - [`matches`](#matches)
  - [`match_players`](#match_players)
  - [`match_throws`](#match_throws)
  - [`match_participants` (denormalized)](#match_participants-denormalized)
  - [`remote_match_locks`](#remote_match_locks)
- [Match Types: Local vs Remote](#match-types-local-vs-remote)
  - [Local Matches](#local-matches)
  - [Remote Matches](#remote-matches)
- [Row Level Security (RLS) Policies](#row-level-security-rls-policies)
  - [`match_players` SELECT policy](#match_players-select-policy)
  - [`match_throws` SELECT policy](#match_throws-select-policy)
  - [`match_participants` SELECT policy](#match_participants-select-policy)
  - [Policy coverage checklist (recommended)](#policy-coverage-checklist-recommended)
- [Data Flow Patterns](#data-flow-patterns)
  - [Local match flow](#local-match-flow)
  - [Remote match flow](#remote-match-flow)
- [Common Queries](#common-queries)
- [Troubleshooting](#troubleshooting)
- [Migration History (high level)](#migration-history-high-level)
- [Related Docs](#related-docs)

---

## Overview

DanDarts supports:

- **Local matches** (offline / guest players possible)
- **Remote matches** (two authenticated users; server-authoritative turn saves)

Key concepts:

- Turn-by-turn history is stored in **`match_throws`**
- Player participation is tracked in **`match_players`** (authoritative)
- Remote match state (scores, turn index, status) is stored in **`matches`**
- RLS protects match visibility and turn visibility per user

---

## Golden Rules

These rules prevent 90% of “why can’t I load X?” or “why is RLS failing?” issues:

1. **Authoritative players source:** `match_players`  
   - Always load participants via `match_players`, not `matches.players`.

2. **Authoritative turns source:** `match_throws`  
   - Turns are keyed by `(match_id, player_order, turn_index)`.

3. **`matches.players` is legacy & inconsistent**  
   - It may be `NULL`, a JSON array, a JSON object, or (commonly in older rows) a **JSONB string containing serialized JSON**.  
   - **Never rely on it for authorization.** If you must use it, *always guard JSON array operations*.

4. **All JSON array ops must be guarded**
   - `jsonb_array_elements(m.players)` must only be called when `jsonb_typeof(m.players) = 'array'`.

5. **Local match access should be granted via `match_players.player_user_id`**
   - Local matches typically have `challenger_id` / `receiver_id` = `NULL`.

---

## Core Tables

### `users`

Stores authenticated user profiles.

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  display_name TEXT NOT NULL,
  nickname TEXT UNIQUE NOT NULL,
  handle TEXT UNIQUE NULLABLE,
  avatar_url TEXT NULLABLE,
  created_at TIMESTAMPTZ DEFAULT now(),
  last_seen_at TIMESTAMPTZ NULLABLE
);
```

**Key points**
- `id` is the primary identifier.
- `nickname` is unique (used for search).
- `handle` is optional (e.g. `@thearrow`).

---

### `matches`

Stores match metadata for **both** local and remote matches.

```sql
CREATE TABLE matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id TEXT NOT NULL REFERENCES games(id),

  -- Common fields
  started_at TIMESTAMPTZ DEFAULT now(),
  ended_at TIMESTAMPTZ NULLABLE,
  winner_id UUID NULLABLE REFERENCES users(id),
  metadata JSONB NULLABLE,
  created_at TIMESTAMPTZ DEFAULT now(),

  -- Match type
  match_mode TEXT DEFAULT 'local',  -- 'local' or 'remote'

  -- Local match fields
  host_device_id TEXT NULLABLE,
  players JSONB NULLABLE,  -- Legacy field; do not use as source of truth

  -- Remote match fields
  challenger_id UUID NULLABLE,
  receiver_id UUID NULLABLE,
  remote_status remote_match_status NULLABLE,
  current_player_id UUID NULLABLE,
  join_window_expires_at TIMESTAMPTZ NULLABLE,
  challenge_expires_at TIMESTAMPTZ NULLABLE,
  last_visit_payload JSONB NULLABLE,
  player_scores JSONB NULLABLE,
  turn_index_in_leg INTEGER DEFAULT 0,
  ended_by UUID REFERENCES users(id),
  ended_reason TEXT
);
```

**Key points**
- `match_mode` distinguishes local vs remote.
- **Local matches:** participants come from `match_players`.
- **Remote matches:** primary participants often come from `challenger_id` / `receiver_id`, but `match_players` is still used.
- `players` is **legacy** and may be inconsistent in older rows (including JSON strings).

Remote match status enum:

```sql
CREATE TYPE remote_match_status AS ENUM (
  'pending',
  'ready',
  'lobby',
  'in_progress',
  'completed',
  'expired',
  'cancelled'
);
```

---

### `match_players`

Stores match participation for both local and remote matches.

```sql
CREATE TABLE match_players (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  player_user_id UUID NULLABLE REFERENCES users(id),
  guest_name TEXT NULLABLE,
  player_order INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(match_id, player_order)
);
```

**Key points**
- Authenticated player: `player_user_id` set, `guest_name` null.
- Guest player: `player_user_id` null, `guest_name` set.
- `player_order` is **0-indexed** and used to align with `match_throws.player_order`.

---

### `match_throws`

Stores turn-by-turn throw history for all matches.

```sql
CREATE TABLE match_throws (
  id BIGSERIAL PRIMARY KEY,
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  player_order INTEGER NOT NULL,
  turn_index INTEGER NOT NULL,
  throws INTEGER[] NOT NULL,  -- Array of 3 dart scores
  score_before INTEGER NOT NULL,
  score_after INTEGER NOT NULL,
  is_bust BOOLEAN NOT NULL DEFAULT false,
  game_metadata JSONB NULLABLE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(match_id, player_order, turn_index)
);
```

**Key points**
- `throws` is `INTEGER[]` (e.g. `{60,60,41}`), **not JSONB**.
- `player_order` aligns with `match_players.player_order`.
- `turn_index` is **0-indexed per player**.
- Unique constraint prevents duplicate turns.

---

### `match_participants` (denormalized)

Optimized lookup table for fast participant-based queries (e.g. head-to-head).

```sql
CREATE TABLE match_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  user_id UUID NOT NULL,
  is_guest BOOLEAN NOT NULL DEFAULT false,
  display_name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

**Key points**
- Denormalized for performance (duplicates data from `match_players`).
- Used for fast head-to-head queries.
- Typically populated when matches are saved.

---

### `remote_match_locks`

Prevents users from having multiple active remote matches.

```sql
CREATE TABLE remote_match_locks (
  user_id UUID PRIMARY KEY,
  match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  lock_status TEXT NOT NULL CHECK (lock_status IN ('ready', 'in_progress')),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

**Key points**
- One lock per user (`PRIMARY KEY(user_id)`).
- Prevents race conditions in remote match creation.
- Deleted when match completes via cascade cleanup (if match is deleted) or explicit cleanup logic.

---

## Match Types: Local vs Remote

### Local Matches

**Characteristics**
- Played offline on a single device.
- Can include guest players.
- All data usually written after match completes.
- No real-time sync loop.

**Data storage**
```sql
-- matches
match_mode = 'local'
challenger_id = NULL
receiver_id = NULL
remote_status = NULL

-- matches.players (legacy)
-- Might be []::jsonb, might be NULL, might be a JSONB string containing serialized JSON.
-- Not authoritative.

-- match_players (authoritative)
player_user_id = <user_id> OR NULL (guests)
guest_name     = NULL OR <guest_name>

-- match_throws
<turn-by-turn data>
```

**Access (intent)**
- Authenticated users can access local matches where they appear in `match_players.player_user_id`.
- Guests cannot access after device wipe (no identity).

---

### Remote Matches

**Characteristics**
- Live multiplayer between two authenticated users.
- Turn-based asynchronous gameplay.
- **Server-authoritative** turn saving.
- Realtime updates via Supabase Realtime.

**Data storage**
```sql
-- matches
match_mode = 'remote'
challenger_id = <user_id>
receiver_id   = <user_id>
remote_status = 'in_progress' | 'completed' | ...
current_player_id = <user_id>
player_scores = '{"<player_id>": 301, ...}'::jsonb
turn_index_in_leg = 0, 1, 2, ...
last_visit_payload = '{...}'::jsonb

-- match_players (also used)
player_user_id = <user_id> (always authenticated)
guest_name = NULL

-- match_throws
<turn-by-turn data, typically inserted via Edge Function / RPC>
```

**Access (intent)**
- Users can access remote matches if:
  - they are `challenger_id` or `receiver_id`, **or**
  - they appear in `match_players.player_user_id`.

**Server-authoritative boundary**
- Remote match turn writes should be validated server-side (Edge Function / RPC).
- The client should not be able to insert arbitrary remote `match_throws` unless explicitly intended.

---

## Row Level Security (RLS) Policies

> **Important:** These are the SELECT policies captured during the “local matches can’t load throws” fix.  
> You should also define/verify INSERT/UPDATE/DELETE policies as needed (especially for remote write paths).

### `match_players` SELECT policy

Policy name: `match_players_select_participants`

```sql
CREATE POLICY match_players_select_participants
ON match_players
FOR SELECT
TO authenticated
USING (
  -- Direct check: is the current user a player in this match?
  player_user_id = auth.uid()

  -- OR remote match check via matches table
  OR EXISTS (
    SELECT 1
    FROM matches m
    WHERE m.id = match_players.match_id
      AND (
        m.challenger_id = auth.uid()
        OR m.receiver_id = auth.uid()
      )
  )
);
```

**Key points**
- Primary check (`player_user_id = auth.uid()`) enables local match access.
- Secondary check covers remote challenger/receiver.
- Does **not** depend on `matches.players`.

---

### `match_throws` SELECT policy

Policy name: `match_throws_select_participants`

```sql
CREATE POLICY match_throws_select_participants
ON match_throws
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM matches m
    WHERE m.id = match_throws.match_id
      AND (
        -- Remote matches: check challenger/receiver
        m.challenger_id = auth.uid()
        OR m.receiver_id = auth.uid()

        -- Legacy/optional: check players array (guarded)
        OR EXISTS (
          SELECT 1
          FROM jsonb_array_elements(
            CASE
              WHEN m.players IS NOT NULL AND jsonb_typeof(m.players) = 'array'
                THEN m.players
              ELSE '[]'::jsonb
            END
          ) AS player(value)
          WHERE (player.value ->> 'id')::uuid = auth.uid()
        )
      )
  )

  -- LOCAL MATCHES: check match_players table
  OR EXISTS (
    SELECT 1
    FROM match_players mp
    WHERE mp.match_id = match_throws.match_id
      AND mp.player_user_id = auth.uid()
  )
);
```

**Key points**
- Fixes “Found 0 throw records” for local matches by checking `match_players`.
- Guarded JSON parsing prevents: `cannot extract elements from a scalar`.
- The `matches.players` check is legacy/fallback and should not be treated as authoritative.

---

### `match_participants` SELECT policy

Policy: `Authenticated users can view all match participants`

```sql
CREATE POLICY "Authenticated users can view all match participants"
ON match_participants
FOR SELECT
TO authenticated
USING (true);
```

**Key points**
- Permissive by design for fast lookup queries.
- This may reveal relationship metadata (who played whom). Reassess if privacy requirements change.
- Match content security should still be enforced by `matches`, `match_players`, and `match_throws` RLS.

---

### Policy coverage checklist (recommended)

For each table, explicitly confirm:

- `matches`: SELECT / INSERT / UPDATE / DELETE
- `match_players`: SELECT / INSERT / DELETE
- `match_throws`: SELECT / INSERT / DELETE
- `remote_match_locks`: SELECT / INSERT / UPDATE / DELETE (usually server-controlled)
- `match_participants`: SELECT (and maybe INSERT only by server)

This doc currently includes **SELECT** policies only.

---

## Data Flow Patterns

### Local match flow

1. User plays match offline
2. Match completes
3. App calls `MatchService.saveMatch()`
4. Insert into `matches` (`match_mode='local'`)
5. Insert into `match_players` (authenticated + guests)
6. Insert into `match_throws` (turn-by-turn)
7. Insert into `match_participants` (denormalized)

**Services**
- `MatchService.swift` — saves match to Supabase
- `MatchesService.swift` — loads match history

---

### Remote match flow

1. Challenger creates challenge
   - Insert into `matches` (`match_mode='remote'`, `remote_status='pending'`)
   - Insert into `remote_match_locks`

2. Receiver accepts challenge
   - Edge Function: `accept-challenge`
   - Update `remote_status='ready'`
   - Set `join_window_expires_at`

3. Both players join lobby
   - Update `remote_status='in_progress'`
   - Insert into `match_players`

4. Players take turns
   - Client calls Edge Function: `save-visit`
   - Edge Function validates turn (and/or RPC `save_remote_visit`)
   - Edge Function inserts into `match_throws`
   - Edge Function updates `matches` (scores, turn counter, etc.)
   - Realtime subscription notifies opponent

5. Match completes
   - Edge Function updates `remote_status='completed'`
   - Set `winner_id`, `ended_at`
   - Delete `remote_match_locks`

**Services**
- `RemoteMatchAdapter.swift` — client-side remote match logic
- Edge Functions: `save-visit`, `accept-challenge`, `abort-match`
- RPC: `save_remote_visit` — server-authoritative turn validation

---

## Common Queries

### Load match history for a user

```sql
SELECT m.*
FROM matches m
WHERE EXISTS (
  SELECT 1
  FROM match_players mp
  WHERE mp.match_id = m.id
    AND mp.player_user_id = '<user_id>'
)
ORDER BY m.created_at DESC
LIMIT 50;
```

### Load turn data for a match

```sql
SELECT *
FROM match_throws
WHERE match_id = '<match_id>'
ORDER BY player_order, turn_index;
```

### Load head-to-head matches (optimized)

```sql
-- Step 1: Find match IDs where both users participated
SELECT mp1.match_id
FROM match_participants mp1
INNER JOIN match_participants mp2
  ON mp1.match_id = mp2.match_id
WHERE mp1.user_id = '<user_id_1>'
  AND mp2.user_id = '<user_id_2>'
  AND mp1.is_guest = false
  AND mp2.is_guest = false
LIMIT 50;
```

See: `MatchesService.loadHeadToHeadMatchesOptimized()` for the full implementation (batch loads + sorting).

---

## Troubleshooting

### Issue: `cannot extract elements from a scalar`

**Symptom**
- PostgREST error `22023` when querying tables protected by policies calling `jsonb_array_elements(...)`.

**Cause**
- An RLS policy called `jsonb_array_elements(m.players)` when `m.players` is not a JSON array.
- Older rows may have `matches.players` stored as a **JSONB string** that contains serialized JSON.

**Solution**
- Guard JSON array access in policies:

```sql
jsonb_array_elements(
  CASE
    WHEN m.players IS NOT NULL AND jsonb_typeof(m.players) = 'array'
      THEN m.players
    ELSE '[]'::jsonb
  END
)
```

- Prefer `match_players` membership checks over `matches.players`.

---

### Issue: “Found 0 throw records” for local matches

**Cause**
- `match_throws` RLS policy checked only `challenger_id/receiver_id` and/or `matches.players`.
- Local matches often have challenger/receiver = NULL, and legacy players is unreliable.

**Solution**
- Ensure `match_throws` policy includes a membership check via `match_players`:

```sql
EXISTS (
  SELECT 1
  FROM match_players mp
  WHERE mp.match_id = match_throws.match_id
    AND mp.player_user_id = auth.uid()
)
```

---

### Issue: Remote match turns not saving

**Possible causes**
- Edge Function / RPC failing validation
- Missing/incorrect INSERT policy for `match_throws`
- Client attempting to write data meant to be server-only

**Debug steps**
- Check Edge Function logs in Supabase dashboard
- Verify `save_remote_visit` RPC exists and is callable
- Verify intended INSERT policy path for `match_throws`
- Verify match exists and user is a participant

---

### Issue: Match history shows wrong players

**Cause**
- Using `matches.players` instead of `match_players`.

**Solution**
- Always load players via `match_players`.
- Treat `matches.players` as legacy and non-authoritative.

---

## Migration History (high level)

Key migrations referenced in this doc:

- `047_remote_matches_schema.sql` — added remote match support
- `042_create_match_participants_table.sql` — denormalized participant table
- `067_fix_matches_players_data_format.sql` — attempted to normalize `matches.players` (note: legacy rows may still be JSON strings)
- `068_fix_rls_for_local_matches.sql` — fixed RLS policies for local matches (match_players + match_throws)

See `supabase_migrations/` for the full history.

---

## Related Docs

- `docs/DATABASE_OPTIMIZATION.md` — performance optimization details
- `.windsurf/rules/database-design.md` — original schema design
- `.windsurf/rules/remote-matches-current-context-phase-7-match-history-stage-2.md` — remote match implementation

---

**Status:** Production Ready ✅ (with the note that INSERT/UPDATE policy coverage should be verified and documented)
