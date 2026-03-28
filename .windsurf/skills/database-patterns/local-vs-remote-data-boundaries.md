> Supporting reference for: database-patterns  
> Apply when: deciding whether a piece of database logic should be shared across local and remote matches, choosing which fields are safe to use for each mode, or debugging bugs caused by assuming local and remote store data the same way  
> Do not apply to: pure UI configuration, realtime subscription behavior, navigation flow, or remote lifecycle reasoning that does not depend on database storage

# Local vs Remote Data Boundaries

## Purpose

This document explains where local and remote match storage overlaps, where it differs, and what Windsurf must not assume.

It exists to stop mistakes like:
- assuming local and remote use the same player model
- assuming fields that exist on `matches` are equally meaningful for both modes
- treating remote-only fields as if they apply to local matches
- treating local multiplayer assumptions as if they apply to remote
- writing queries that work for local matches but fail for remote, or vice versa

This document is about **storage boundaries**, not UI flow.

## Core Rule

Always identify the match mode first.

Ask:

1. is this `local` or `remote`?
2. is this field shared by both modes, or mainly meaningful in one mode?
3. is this player data stored the same way in both modes?
4. is this turn/history logic shared, or only the top-level table shared?
5. is this a product rule or a true database rule?

In short:

**local and remote share parts of the schema, but they are not the same data model**

## Shared Foundation

Both local and remote matches use the same top-level `matches` table.

Both can also use:
- `match_players`
- `match_throws`

That shared foundation is useful, but it does **not** mean both modes use every field the same way.

## Local Matches

### Core shape

Local matches are multiplayer-capable and use `match_players` as the main player table.

For local matches:
- `match_mode = 'local'`
- `challenger_id` and `receiver_id` are not the player model
- players come from `match_players`
- player identity may be:
  - real user via `player_user_id`
  - guest via `guest_name`

### What local storage emphasizes

Local storage is built around:
- flexible player counts
- player order from `match_players`
- game-type-specific rules
- turn history in `match_throws`

### Safe local assumption

For local queries, if you need to know who is in the match and in what order, start with `match_players`.

## Remote Matches

### Core shape

Remote matches are 1v1 and use dedicated role fields on `matches`.

For remote matches:
- `match_mode = 'remote'`
- `challenger_id` and `receiver_id` define the two participants and their roles
- remote also uses remote lifecycle/state fields on `matches`
- `match_players` may also exist for full player/order mapping once the match is fully established

### What remote storage emphasizes

Remote storage is built around:
- strict 2-player structure
- challenger/receiver roles
- remote lifecycle state
- remote-only timestamps and progression fields
- gameplay history once the match actually enters play

### Safe remote assumption

For remote queries, `challenger_id` and `receiver_id` are the safest role truth.

Do not assume every remote row has full related-table population.

## Shared Tables, Different Meaning

Some tables are shared by both modes, but their practical meaning differs.

### `matches`

Shared by both local and remote.

But:
- local uses it mainly for top-level match record and summary
- remote uses it for top-level record **plus** role fields and lifecycle/progression state

### `match_players`

Shared by both local and remote.

But:
- in local, this is the main player model
- in remote, it is useful for player/order mapping, but role truth still comes from `challenger_id` and `receiver_id`

### `match_throws`

Shared by both local and remote.

But:
- all local gameplay relies on it
- remote only produces throws once gameplay actually starts
- early remote terminal rows may have no throw rows at all

## Remote-Only Fields

Some fields are remote-specific in practical meaning and should not be treated as universal match fields.

Examples include:
- `challenger_id`
- `receiver_id`
- `remote_status`
- `current_player_id` in remote lifecycle context
- `challenge_expires_at`
- `join_window_expires_at`
- replay-related fields
- lobby / readiness / countdown / voice-related timestamps

These should not be used as if they are meaningful for local matches.

## Local-Only Practical Assumptions

Some assumptions are safe for local but unsafe for remote.

Examples:
- player identity comes from `match_players`
- there may be more than 2 players
- guest players may exist
- game-type variation is broader
- there is no challenger/receiver role model

Do not accidentally import local multiplayer thinking into remote queries.

## Player Model Boundary

This is one of the most important boundaries.

### Local
Use `match_players` as the player model.

### Remote
Use `challenger_id` / `receiver_id` as the role model, and `match_players` for player/order mapping when needed.

### Unsafe assumption
“Both local and remote just use `match_players` the same way.”

That is too simplistic.

## History Boundary

Both modes can use `match_throws`, but the path into history is different.

### Local history
Local matches generally use:
- `match_players`
- `match_throws`
- game-type-specific metadata where needed

### Remote history
Remote history may depend on:
- `challenger_id` / `receiver_id`
- `match_players`
- `match_throws`
- summary fields on `matches`
- whether the remote row fully reached gameplay or completion

### Unsafe assumption
“If both use `match_throws`, history reconstruction is identical.”

That is not safe.

## Partial Row Boundary

This matters much more for remote than local.

Remote rows may be:
- fully completed
- started and terminated early
- terminated before gameplay
- only partially initialized

So for remote:
- not every row has the same supporting data
- not every terminal row has the same related-table population

This is a major storage difference from the simpler “fully played local match” mental model.

## Product Rules vs Database Rules

Do not confuse app rules with schema guarantees.

Examples:
- remote is product-limited to 2 players
- local setup is currently capped by app config
- these are not automatically database constraints unless explicitly enforced in schema

This matters because code may rely on:
- current product behavior
without the database actually enforcing it

### Safe rule

Treat player limits as product/config rules unless the schema explicitly proves otherwise.

## Legacy / Historical Data Boundary

This is especially important for database work.

The intended current architecture may be cleaner than the historical row set.

That means:
- old rows may reflect earlier app behavior
- partially initialized rows may not follow the fully established pattern
- convenience or legacy fields may still exist
- some tables may be populated only for certain outcomes

Do not turn “current intended model” into “guaranteed shape of every existing row.”

## Common Mistakes

### Mistake: using remote role fields for local player logic
Why it is wrong:
- local does not use challenger/receiver as the player model

### Mistake: using local player-order assumptions for remote role logic
Why it is wrong:
- remote role truth comes from `challenger_id` / `receiver_id`

### Mistake: assuming both modes populate related tables the same way
Why it is wrong:
- remote rows may be partially initialized
- local rows are structurally different in intent

### Mistake: assuming shared table means shared semantics
Why it is wrong:
- the same table may serve both modes with different practical meaning

### Mistake: assuming UI limits are DB constraints
Why it is wrong:
- app config and schema enforcement are not the same thing

## Decision Checklist

Before changing schema or queries, ask:

1. am I working with local or remote?
2. what is the canonical player model for this mode?
3. what tables are actually safe to rely on for this mode?
4. am I assuming full related-table population where that is not guaranteed?
5. am I confusing a product rule with a database invariant?

If those answers are unclear, the change is probably unsafe.

## Relationship to Other Docs

Use this doc for mode boundaries.

Use it with:
- `core-match-tables.md` for the table map
- `match-vs-turn-vs-history-data.md` for history reconstruction rules
- `game-type-storage-patterns.md` for per-game storage differences
- `query-conventions.md` for safe joins and canonical query sources

This doc answers:

**what storage assumptions are shared across local and remote, and what assumptions must stay mode-specific?**

## Bottom Line

Local and remote share some tables, but they do not share one identical data model.

Local is multiplayer-first and player-table-driven.  
Remote is role-driven and lifecycle-heavy.  
Do not write database logic as if they are interchangeable.