> Supporting reference for: database-patterns  
> Apply when: writing queries against Dart Freak match data, joining matches to players or throws, reconstructing history, or deciding which table should be treated as the canonical source in a read path  
> Do not apply to: pure UI filtering, realtime subscription behavior, or schema migration planning unless the main issue is query shape or source selection

# Query Conventions

## Purpose

This document defines the default query conventions for Dart Freak.

It exists to stop mistakes like:
- querying the easiest field instead of the canonical one
- joining the wrong player table
- reconstructing history from summary fields
- assuming all remote rows have the same related-table population
- writing queries that only work for completed happy-path matches
- applying one game type’s read pattern to every other game type

This document is about **how to read data safely**.

## Core Rule

When writing a query, decide these things first:

1. what truth are you trying to read?
2. which table canonically owns that truth?
3. does this query need summary state or full history?
4. is this local or remote?
5. does this query need to survive partial, cancelled, expired, or old rows?

In short:

**query from canonical ownership, not convenience**

## Canonical Read Sources

Use these default read rules.

### Top-level match truth
Read from `matches`

Use for:
- match identity
- match mode
- game type
- game name
- winner
- terminal outcome
- timing
- remote lifecycle fields
- summary/progression state

### Player identity and player order
Read from `match_players`

Use for:
- player identity
- player order
- mapping turns to players
- guest vs real-user distinction

### Turn-by-turn history
Read from `match_throws`

Use for:
- visit sequence
- throws
- score progression
- busts
- turn-level metadata

### Participant snapshot / history-facing participant info
Read from `match_participants` only when that is specifically the layer you need.

Do not default to it for live player-order logic.

## Start With the Smallest Correct Query

Do not start by joining every related table.

Start with the smallest correct source for the question.

### Good
- need winner and ended time → query `matches`
- need player order → query `match_players`
- need turn sequence → query `match_throws`

### Bad
- need winner → join everything just in case
- need latest score → rebuild from turn table when match summary already answers it
- need history → read only summary fields from `matches`

## Match Queries

Use `matches` first when you need:
- match lists
- mode filtering
- game type filtering
- terminal status
- winner
- started / ended time
- remote lifecycle state
- summary score state

### Good pattern
Use `matches` as the root table when the query is match-oriented.

### Important caution
Do not let a match-oriented root query drift into false assumptions about:
- player order
- full history
- complete related-row population

## Player Queries

Use `match_players` when you need:
- ordered players
- player count
- user-vs-guest logic
- mapping `player_order` to a person

### Good pattern
Join `match_players` onto `matches` when the read path needs player resolution.

### Important caution
Do not use `challenger_id` / `receiver_id` as a universal player model for all matches.
That is remote-specific role truth, not the universal player-order model.

## Remote Player Queries

For remote reads, separate:
- **role truth**
from
- **player-order truth**

### Use `matches` for:
- `challenger_id`
- `receiver_id`
- remote lifecycle state

### Use `match_players` for:
- player order mapping
- turn-to-player mapping

### Important caution
For remote rows, do not assume every row has fully populated related tables.
Queries must tolerate:
- partial initialization
- cancelled/expired early rows
- terminal rows with varying related-table completeness

## Turn / History Queries

Use `match_throws` when you need:
- exact visit sequence
- full gameplay breakdown
- score progression over time
- mode-specific per-turn metadata

### Good pattern
Query `match_throws` by `match_id`, then join player resolution only as needed.

### Important caution
Do not reconstruct turn history from:
- `last_visit_payload`
- `player_scores`
- other summary fields on `matches`

Those are summary helpers, not the full historical record.

## Summary vs History Query Rule

This is one of the most important conventions.

### Use summary fields when you need:
- current/final score snapshot
- winner
- latest visit snapshot
- quick list or overview display
- current state without replaying every turn

### Use turn history when you need:
- exact progression
- replayable sequence
- detailed history UI
- debugging what actually happened
- game-specific turn semantics

### Core rule
Do not pay the cost of full history when summary is enough.
But do not fake history from summary when full history is required.

## Joins

Prefer explicit, purpose-driven joins.

### `matches` → `match_players`
Use when you need:
- ordered players
- player names/IDs
- guest info

### `matches` → `match_throws`
Use when you need:
- turn history
- throw counts
- progression details

### `match_throws` → `match_players`
Use when you need:
- resolve a throw row’s `player_order` to the actual player

### `matches` → `match_participants`
Use only when you specifically want participant snapshot/history-facing participant info.

Do not use it as the default substitute for `match_players`.

## Filtering Conventions

### Filter by `match_mode` early
If the query is mode-specific, filter by `match_mode` as early as possible.

This avoids:
- local assumptions leaking into remote queries
- remote assumptions leaking into local queries

### Filter by `game_type` early
If the read path depends on game semantics, identify `game_type` early.

This avoids:
- applying x01 logic to metadata-heavy games
- ignoring game-specific metadata

### Filter by terminal or lifecycle state carefully
Do not assume:
- terminal rows all have the same supporting data
- completed is the only state with history
- cancelled/expired always mean no gameplay data

Use actual stored data, not status alone, when that distinction matters.

## Ordering Conventions

### Match lists
Usually order by a match-level timestamp such as:
- `updated_at`
- `ended_at`
- `started_at`
- `timestamp`

depending on the surface and purpose.

### Turn history
Order turn history by:
- `turn_index`
- then `player_order`
- then `created_at` when needed

The exact combination depends on the game pattern, but the goal is:
- stable chronological reconstruction

### Important caution
Do not rely on insertion order alone when a specific sequence field exists.

## Partial Row Safety

Queries must be robust to rows that are not fully populated.

This matters especially for:
- remote matches that never fully established
- cancelled/expired rows
- early rows created under older app behavior

### Safe rule
Assume related-table population may vary unless the query is intentionally limited to a fully established subset.

### Unsafe rule
“Every match will always have all related rows.”

That is not a safe default.

## Local vs Remote Query Rule

### Local
Default player source:
- `match_players`

Default history source:
- `match_throws`

### Remote
Default role source:
- `challenger_id` / `receiver_id` on `matches`

Default player-order source when needed:
- `match_players`

Default history source:
- `match_throws` once gameplay exists

### Important caution
Do not write one “universal” query that silently assumes local and remote are structurally identical.

## Game-Type Query Rule

### Standard scoring games
For x01-style reads, shared fields in `match_throws` may be enough.

### Metadata-heavy games
For games like:
- `halve_it`
- `killer`

history queries may also need `game_metadata`.

### Core rule
Do not write turn-history reads that ignore `game_metadata` for games that need it.

## Common Mistakes

### Mistake: using `matches` alone for history
Why it is wrong:
- `matches` gives top-level truth and summary, not full sequence

### Mistake: using `match_participants` as the default player join
Why it is wrong:
- it is not the canonical live player-order table

### Mistake: assuming remote always has full related rows
Why it is wrong:
- some remote rows are partial or early terminal

### Mistake: assuming terminal status implies data completeness
Why it is wrong:
- terminal rows vary
- some have gameplay data, some do not

### Mistake: ignoring `game_type`
Why it is wrong:
- not all games can be interpreted from the same fields

## Preferred Query Mindset

Think like this:

### First decide the truth
Examples:
- winner
- player order
- turn sequence
- latest score snapshot
- remote participants
- game-specific turn meaning

### Then pick the owning table
- `matches`
- `match_players`
- `match_throws`
- `match_participants`

### Then add only the joins required
No more.

This leads to safer, more maintainable queries.

## Decision Checklist

Before finalizing a query, ask:

1. what truth am I trying to read?
2. which table canonically owns it?
3. do I need summary or full history?
4. is this local or remote?
5. does the query survive partial and old rows?
6. does the game type require metadata-aware interpretation?

If those answers are unclear, the query is probably unsafe.

## Relationship to Other Docs

Use this doc when the main question is:

**how should I query Dart Freak match data without relying on the wrong source?**

Use it with:
- `core-match-tables.md` for the table map
- `local-vs-remote-data-boundaries.md` for mode-specific storage boundaries
- `match-vs-turn-vs-history-data.md` for summary vs history ownership
- `game-type-storage-patterns.md` for per-game metadata patterns
- `migrations-and-schema-changes.md` for schema evolution concerns

This doc answers:

**what table should I read from first, and how should I join safely?**

## Bottom Line

In Dart Freak, safe queries start from canonical ownership.

- `matches` for top-level truth
- `match_players` for player identity/order
- `match_throws` for actual gameplay history
- `match_participants` only when you truly need participant snapshot data

Read from the owning table first.  
Join only what the query actually needs.