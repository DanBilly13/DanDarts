---
trigger: manual
---

# DanDarts — Database Design (ERD Overview) & API Notes

## Summary
This document describes the Postgres schema (Supabase) for DanDarts and includes API usage notes for inserting match throws (`POST /match_throws`). It is intended as a canonical reference for backend and client integration.

---

## Tables & Columns (Schema)

### users
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `display_name` TEXT NOT NULL
- `nickname` TEXT UNIQUE NOT NULL
- `handle` TEXT UNIQUE NULLABLE  -- optional user handle like `@thearrow`
- `avatar_url` TEXT NULLABLE
- `created_at` TIMESTAMP WITH TIME ZONE DEFAULT now()
- `last_seen_at` TIMESTAMP WITH TIME ZONE NULLABLE

**Indexes / Constraints**
- Unique index on `nickname`
- Optional index on `display_name` for search

---

### friends
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `user_id` UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE
- `friend_id` UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE
- `status` TEXT NOT NULL CHECK (status IN ('pending','accepted','rejected'))
- `created_at` TIMESTAMP WITH TIME ZONE DEFAULT now()

**Notes**
- `(user_id, friend_id)` should be unique to prevent duplicate requests.
- Consider a symmetric view or ensure both directions are accepted as needed.

---

### games
- `id` TEXT PRIMARY KEY   -- e.g. '301', 'halve_it', 'knockout'
- `name` TEXT NOT NULL
- `rules` JSONB NULLABLE   -- structured rules & metadata
- `created_at` TIMESTAMP WITH TIME ZONE DEFAULT now()

---

### matches
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `game_id` TEXT NOT NULL REFERENCES games(id)
- `started_at` TIMESTAMP WITH TIME ZONE DEFAULT now()
- `ended_at` TIMESTAMP WITH TIME ZONE NULLABLE
- `winner_id` UUID NULLABLE REFERENCES users(id)
- `host_device_id` TEXT NULLABLE  -- optional local device identifier for guest attribution
- `metadata` JSONB NULLABLE       -- e.g., duration_seconds, notes
- `created_at` TIMESTAMP WITH TIME ZONE DEFAULT now()

**Notes**
- For local-only matches (all guests), `winner_id` may be NULL and `host_device_id` used to correlate.

---

### match_players
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `match_id` UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE
- `player_user_id` UUID NULLABLE REFERENCES users(id)  -- null for guest players
- `guest_name` TEXT NULLABLE                         -- used when player_user_id is null
- `player_order` INTEGER NOT NULL                    -- 0-based order in match
- `created_at` TIMESTAMP WITH TIME ZONE DEFAULT now()

**Constraints**
- Unique constraint on (`match_id`, `player_order`)

---

### match_throws
- `id` UUID PRIMARY KEY DEFAULT gen_random_uuid()
- `match_id` UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE
- `player_order` INTEGER NOT NULL                    -- matches match_players.player_order
- `turn_index` INTEGER NOT NULL                      -- 0-based turn index
- `throws` INT[] OR JSONB NOT NULL                   -- prefer `integer[]` or `jsonb` if you need extra metadata
- `score_before` INTEGER NOT NULL
- `score_after` INTEGER NOT NULL
- `created_at` TIMESTAMP WITH TIME ZONE DEFAULT now()

**Indexes / Constraints**
- Unique constraint on (`match_id`, `player_order`, `turn_index`) to avoid duplicate turns
- Consider GIN index on `throws` if querying by values (optional)

**Column type note**
- Postgres supports `integer[]` (e.g., `[20,60,0]`) or `jsonb` (`[20,60,0]`). Choose `integer[]` for compactness and easier numeric operations; use `jsonb` if you expect extra throw metadata later (e.g., `{ "scores":[20,60,0], "marks":[ "S20","T20","M" ] }`).

---

### player_stats
- `user_id` UUID PRIMARY KEY REFERENCES users(id)
- `games_played` INTEGER DEFAULT 0
- `wins` INTEGER DEFAULT 0
- `losses` INTEGER DEFAULT 0
- `last_updated` TIMESTAMP WITH TIME ZONE DEFAULT now()

**Notes**
- This table is a cache/aggregate for quick reads. Keep updated by triggers or background jobs after match insert.

---

## Relationships (ERD Summary)
- `users` 1 — * `friends` (friend links)
- `games` 1 — * `matches`
- `matches` 1 — * `match_players`
- `match_players` 1 — * `match_throws` (via `player_order`)
- `users` 1 — 1 `player_stats`

---

## API Notes — `POST /match_throws` (bulk insert)

**Purpose**
- Insert all throws for a match (typically called after a match finishes).
- Use bulk insert to avoid many small requests and ensure atomicity.

**Endpoint (PostgREST / Supabase REST)**