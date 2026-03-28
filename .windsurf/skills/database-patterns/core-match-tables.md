> Supporting reference for: database-patterns  
> Apply when: deciding which Dart Freak table should store a piece of truth, joining match data to players or turn history, or debugging schema misunderstandings about what each core table is for  
> Do not apply to: pure UI config, realtime behavior, navigation logic, or game-rule reasoning that does not depend on database table ownership

# Core Match Tables

## Purpose

This document explains the main gameplay-related tables in Dart Freak and the role each one plays.

It exists to stop mistakes like:
- putting truth in the wrong table
- reading summary fields as if they were full history
- treating all player-related tables as interchangeable
- assuming every match populates every related table the same way
- writing queries against whichever table looks easiest instead of the canonical one

This document is the table map for the match system.

## Core Rule

Before reading or writing match data, ask:

1. is this match-level truth?
2. is this player identity or player order truth?
3. is this turn/history truth?
4. is this participant snapshot/history-facing data?
5. is this remote-only infrastructure?

In short:

**pick the table by what kind of truth it stores, not by convenience**

## Main Table Overview

Dart Freak’s core match-related tables are:

- `matches`
- `match_players`
- `match_throws`
- `match_participants`

There are also related support tables such as:
- `remote_match_locks`
- `push_tokens`
- `user_push_tokens`

But the main gameplay table map starts with the first four.

## `matches`

### What it is

`matches` is the top-level match record.

It is the central table for both:
- local matches
- remote matches

### What belongs here

Use `matches` for top-level match truth such as:
- match identity
- match mode
- game type
- timing
- winner / terminal outcome
- remote lifecycle fields
- match-level summary / progression fields

Examples of match-level fields include:
- `id`
- `match_mode`
- `game_type`
- `game_name`
- `winner_id`
- `started_at`
- `ended_at`
- `challenger_id`
- `receiver_id`
- `remote_status`
- `current_player_id`
- `player_scores`
- `last_visit_payload`
- `turn_index_in_leg`

### What does not belong here

Do not treat `matches` as:
- the canonical full player-order table
- the full per-turn history table
- the only source of truth for history reconstruction

### Important rule

`matches` stores the **top-level match record** and some **summary/progression state**.

It does **not** replace turn history.

## `match_players`

### What it is

`match_players` is the canonical player identity and player order table.

### What belongs here

Use `match_players` for:
- who is in the match
- what order they are in
- mapping player order to history rows

This table supports:
- real users via `player_user_id`
- guests via `guest_name`

Important fields include:
- `match_id`
- `player_user_id`
- `guest_name`
- `player_order`

### Why it matters

This is the main table for:
- player order
- player identity mapping
- multiplayer local match structure
- turn-history interpretation

### Important rule

When you need to know:
- who player 0 / player 1 / player 2 is
- which player a turn row belongs to

start with `match_players`.

### Caution

Do not assume all historical rows are perfectly populated in every match state.

But as a design rule, this is the main player-order table.

## `match_throws`

### What it is

`match_throws` is the canonical per-turn / per-visit history table.

### What belongs here

Use `match_throws` for:
- what happened each turn
- score before the turn
- score after the turn
- turn-level outcome details
- game-specific turn metadata

Important shared fields include:
- `match_id`
- `player_order`
- `turn_index`
- `throws`
- `score_before`
- `score_after`
- `is_bust`
- `game_metadata`

### Why it matters

This is the canonical gameplay-history table across game families.

It is used by:
- local matches
- remote matches that actually reach gameplay

### Important rule

If you need to know what actually happened turn by turn, use `match_throws`.

Do not replace it with:
- `last_visit_payload`
- `player_scores`
- other summary fields on `matches`

### Game-specific note

Some games use only the shared throw fields.

Some also rely on `game_metadata`.

So do not assume every game reconstructs history from the exact same subset of columns.

## `match_participants`

### What it is

`match_participants` is a participant table, but it should be treated differently from `match_players`.

### What belongs here

Use `match_participants` as a participant snapshot/history-facing table where appropriate.

Fields include:
- `match_id`
- `user_id`
- `is_guest`
- `display_name`

### Why it matters

This table appears useful for:
- participant snapshots
- history-facing participant info
- completion-facing participant records in some flows

### Important caution

Do **not** assume `match_participants` is the primary live player-order table.

It is not the same thing as `match_players`.

### Current practical rule

If you need:
- canonical player order
- player-to-turn mapping

use `match_players`.

If you need:
- participant snapshot / display-facing participant info

`match_participants` may be relevant.

## `remote_match_locks`

### What it is

`remote_match_locks` is a remote-only support table.

### What belongs here

Use it for:
- lock/concurrency-related remote infrastructure

Fields include:
- `user_id`
- `match_id`
- `lock_status`

### Important rule

Do not treat this as a gameplay-history table or a player-truth table.

It is remote infrastructure.

## `push_tokens` and `user_push_tokens`

### What they are

These are notification/device token tables.

### What belongs here

Use them for:
- user/device token storage
- push notification delivery support

### Important rule

These tables are not part of the core gameplay/history truth model.

## Table Ownership by Truth Type

Use this quick rule:

### Match-level truth
Use `matches`

### Player identity/order truth
Use `match_players`

### Turn/history truth
Use `match_throws`

### Participant snapshot/history-facing participant info
Use `match_participants`

### Remote lock infrastructure
Use `remote_match_locks`

### Push/device infrastructure
Use `push_tokens` / `user_push_tokens`

## Common Mistakes

### Mistake: storing turn truth on `matches`
Example:
- relying on `last_visit_payload` as if it were full history

Why it is wrong:
- `last_visit_payload` is summary/progression state
- `match_throws` is the turn-history source

### Mistake: treating `match_participants` and `match_players` as interchangeable
Why it is wrong:
- they serve different roles
- `match_players` is the player-order table
- `match_participants` is more snapshot/history-facing

### Mistake: assuming every match has all related rows
Why it is wrong:
- partial, cancelled, expired, or older rows may not populate every related table the same way

### Mistake: querying the easiest table instead of the canonical one
Why it is wrong:
- convenience is not ownership
- the schema still has a real source of truth per layer

## Decision Checklist

Before writing a query or changing schema, ask:

1. is this top-level match truth?
2. is this player identity/order truth?
3. is this turn-history truth?
4. is this participant snapshot data?
5. am I using the canonical table, or just the easiest one?

If those answers are unclear, the database change is probably unsafe.

## Relationship to Other Docs

Use this doc as the table map.

Use it with:
- `local-vs-remote-data-boundaries.md` for local vs remote differences
- `match-vs-turn-vs-history-data.md` for history reconstruction rules
- `game-type-storage-patterns.md` for per-game metadata usage
- `query-conventions.md` for safe joins and canonical query sources

This doc answers:

**which core table is responsible for which kind of truth?**

## Bottom Line

In Dart Freak, the core gameplay schema has layers.

- `matches` holds top-level match truth
- `match_players` holds player identity/order truth
- `match_throws` holds turn-history truth
- `match_participants` is not the same thing as `match_players`

Pick the table based on the kind of truth you need.