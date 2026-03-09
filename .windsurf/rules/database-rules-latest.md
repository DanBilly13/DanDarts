---
trigger: always_on
---

# Database Rules (LATEST)

Purpose: Prevent regressions in DanDarts DB + RLS. Full reference lives in:
.windsurf/reference/database/Database_Documentation_LATEST.md

## Golden rules
- Treat `matches.players` as LEGACY. Do not write new code that depends on it.
- Player participation source of truth = `match_players` (plus `challenger_id/receiver_id` for remote).
- Turn history source of truth = `match_throws` (`throws` is `int4[]`, not JSON).

## Match type invariants
- Local matches:
  - `match_mode='local'`
  - `challenger_id`/`receiver_id` are NULL
  - participants must be present in `match_players.player_user_id` (or `guest_name`)
- Remote matches:
  - `match_mode='remote'`
  - `challenger_id` and `receiver_id` are set
  - `match_players` also contains both users

## RLS invariants (do not break)
- Any policy that uses `jsonb_array_elements(m.players)` MUST guard with:
  `CASE WHEN jsonb_typeof(m.players)='array' THEN m.players ELSE '[]'::jsonb END`
- `match_throws` SELECT must allow access via `match_players.player_user_id = auth.uid()` for local matches.

## Debug checklist
- "cannot extract elements from a scalar" => an RLS policy is calling `jsonb_array_elements` on non-array JSON.
- "Found 0 throw records" for a local match => policy doesn’t include `match_players` membership check.