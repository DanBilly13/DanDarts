> Supporting reference for: database-patterns  
> Apply when: working on database logic that depends on game type, deciding whether shared turn fields are enough, or reasoning about when game-specific metadata is required  
> Do not apply to: pure UI setup rules, navigation flow, realtime behavior, or generic schema questions that do not depend on game-specific storage differences

# Game Type Storage Patterns

## Purpose

This document explains how different Dart Freak game types use the shared schema differently.

It exists to stop mistakes like:
- assuming all games use x01 scoring logic
- assuming `match_throws` means the same thing for every mode
- ignoring game-specific metadata
- writing history or query logic that works for `301` and `501` but breaks for other games
- flattening all game modes into one storage model just because they share tables

This document is about **storage patterns by game family**.

## Core Rule

Always identify the game type first.

Ask:

1. is this a standard scoring game or a metadata-heavy game?
2. are shared `match_throws` fields enough to understand the turn?
3. does this game need extra turn-level metadata?
4. am I assuming x01 semantics where they do not apply?

In short:

**shared tables do not mean identical game logic**

## Current Game Families

Dart Freak currently includes these game types:

### Local games
- `301`
- `501`
- `halve_it`
- `killer`
- `knockout`
- `sudden_death`

### Remote games
- `Remote 301`
- `Remote 501`

## Shared Foundation

All current game families use the same broad core schema:

- `matches` for top-level match truth
- `match_players` for player identity and order
- `match_throws` for turn/visit history

But they do **not** all use the exact same scoring or metadata pattern.

## Standard Scoring Family

The standard scoring family currently includes:

- `301`
- `501`
- `Remote 301`
- `Remote 501`

These are the safest games to interpret from the shared turn fields alone.

### Shared turn fields used here

These games generally rely on:
- `throws`
- `score_before`
- `score_after`
- `is_bust`

### Practical interpretation

For standard scoring games, a turn row in `match_throws` usually gives enough information to understand:
- what was thrown
- what the score was before
- what the score became after
- whether bust logic applied

### Important rule

These games are the closest thing Dart Freak has to a “default” scoring/storage model.

But even here, the canonical history source is still `match_throws`, not summary fields on `matches`.

## Remote x01 Games

Remote x01 games are:

- `Remote 301`
- `Remote 501`

These use the same broad scoring shape as local x01 games, but they also sit inside the remote match model.

That means:
- turn history still lives in `match_throws`
- match-level remote lifecycle and role fields still live on `matches`

### Important rule

Do not confuse:
- x01 scoring storage
with
- remote lifecycle storage

The scoring pattern may be similar to local x01, but the match-level storage context is different.

## Games With Extra Metadata

Some games need extra turn-level metadata because the shared score fields are not enough to explain the turn fully.

Known examples currently include:
- `halve_it`
- `killer`

### Important rule

When a game uses extra metadata, do not assume the shared turn fields alone tell the full story.

## `halve_it`

### Storage pattern

`halve_it` uses the shared turn fields in `match_throws`, but also stores extra turn-level metadata.

Known metadata example:
- `target_display`

### Why this matters

In `halve_it`, understanding a turn may require knowing the current target in addition to:
- what was thrown
- score before
- score after

The shared turn fields alone do not fully explain the rules context.

### Safe rule

For `halve_it`:
- use shared turn fields for score/visit facts
- use `game_metadata` for target/context facts

Do not reconstruct Halve It history using x01 assumptions alone.

## `killer`

### Storage pattern

`killer` also uses the shared turn fields in `match_throws`, but relies on extra turn-level metadata.

Known metadata example:
- `killer_darts`

### Why this matters

In `killer`, the meaning of a turn may depend on per-dart outcomes such as:
- miss
- became killer
- hit opponent
- hit own number

Those meanings are not captured by:
- `score_before`
- `score_after`
- `is_bust`

alone.

### Safe rule

For `killer`:
- use shared turn fields as the turn record shell
- use `game_metadata` for game-rule meaning

Do not flatten Killer history into normal score progression logic.

## `knockout`

### Current storage pattern

`knockout` uses the shared schema and currently does not appear to rely on extra turn metadata in the same way as Halve It or Killer.

### Safe rule

Use the shared turn fields, but do not assume that means Knockout should be interpreted as x01.

Shared storage shape does not automatically mean shared gameplay semantics.

## `sudden_death`

### Current storage pattern

`sudden_death` also uses the shared schema and currently does not appear to rely on extra turn metadata in the same way as Halve It or Killer.

### Safe rule

Use the shared turn fields, but do not assume that means Sudden Death should be treated exactly like x01.

Again, shared storage shape is not identical to shared game logic.

## Shared Fields vs Metadata

This is the key distinction in this doc.

### Shared fields
These are fields like:
- `throws`
- `score_before`
- `score_after`
- `is_bust`

They provide a general turn-history structure across game types.

### Metadata
This is game-specific turn context stored in `game_metadata`.

It exists because some games need more than the shared fields to explain what the turn meant.

### Core rule

Use shared fields for:
- generic turn facts

Use metadata for:
- game-specific turn meaning

Do not force one into the other.

## What Windsurf Should Not Assume

Do not assume:
- all games are x01 under the hood
- every game can be reconstructed from `score_before` and `score_after` alone
- metadata-heavy games can be queried like x01 without loss of meaning
- a shared table means a shared scoring model
- remote games require separate turn tables just because they are remote

## Common Mistakes

### Mistake: assuming x01 logic for all games

Why it is wrong:
- some games use metadata-heavy turn meaning
- score progression is not always the whole story

### Mistake: ignoring `game_metadata`

Why it is wrong:
- some turns are not fully understandable without metadata

### Mistake: treating remote x01 as a totally separate scoring family

Why it is wrong:
- the scoring pattern is still x01-like
- the difference is mostly in match-level remote structure

### Mistake: assuming games without metadata are identical to each other

Why it is wrong:
- lack of metadata does not mean identical gameplay semantics
- it only means the current stored turn shape is lighter

## Query and History Guidance

When writing queries or history logic:

### For x01 games
Start with:
- `match_throws`
- shared turn fields
- player order mapping from `match_players`

### For metadata-heavy games
Start with:
- `match_throws`
- shared turn fields
- `game_metadata`

Then interpret the turn with the game-specific context.

### Important rule

The same query structure may work across games, but the same interpretation logic may not.

## Decision Checklist

Before writing database logic for a game type, ask:

1. what game type is this?
2. is this standard scoring or metadata-heavy?
3. do shared turn fields fully explain the turn?
4. do I need `game_metadata` to interpret the turn correctly?
5. am I accidentally applying x01 assumptions to another game family?

If those answers are unclear, the query or schema change is probably unsafe.

## Relationship to Other Docs

Use this doc when the main question is:

**does this game type use the shared storage pattern only, or does it require extra game-specific metadata or interpretation?**

Use it with:
- `core-match-tables.md` for the table map
- `local-vs-remote-data-boundaries.md` for mode boundaries
- `match-vs-turn-vs-history-data.md` for summary vs turn truth
- `query-conventions.md` for safe joins and canonical sources

This doc answers:

**how do different game types use the shared schema differently?**

## Bottom Line

In Dart Freak, game types share tables, but they do not all share one scoring/storage meaning.

- x01 games mostly use the shared turn fields directly
- some games also require turn-level metadata
- the game type must always be identified before interpreting stored data