> Supporting reference for: database-patterns  
> Apply when: deciding whether data belongs on the match row or in turn history, reconstructing match history, debugging history bugs, or reasoning about summary fields versus canonical gameplay records  
> Do not apply to: pure UI formatting, realtime delivery issues, or mode-specific rule details unless the question is specifically about where that data should live

# Match vs Turn vs History Data

## Purpose

This document explains the difference between:

- **match-level data**
- **turn-level data**
- **history-facing derived data**

It exists to stop mistakes like:
- storing turn truth on the `matches` row
- treating summary fields as if they were the full historical record
- reconstructing history from convenience fields instead of canonical sources
- assuming completed, cancelled, and expired matches all contain the same gameplay detail
- writing history logic that only works for fully completed happy-path matches

This document is about **data ownership by level**.

## Core Rule

Always ask these questions in order:

1. is this top-level match truth?
2. is this something that happened on a specific turn?
3. is this only a summary or convenience snapshot?
4. is this history reconstruction, or just current-state display?
5. does this still work for partial matches and terminal edge cases?

In short:

**the match row stores summary and outcome; the turn table stores what actually happened**

## The Three Levels

Dart Freak data should be understood in three levels.

### 1. Match-level data

This is the top-level record of the match.

It answers questions like:
- what match is this?
- what mode is it?
- what game type is it?
- who won?
- when did it start and end?
- what is the current or final summary state?

This belongs on `matches`.

### 2. Turn-level data

This is the record of what happened on each turn or visit.

It answers questions like:
- who took this turn?
- what darts were thrown?
- what was the score before?
- what was the score after?
- was it a bust?
- did this turn carry extra game-specific metadata?

This belongs in `match_throws`.

### 3. History-facing derived data

This is the data you compute or assemble when showing history.

It may combine:
- `matches`
- `match_players`
- `match_throws`
- game-specific metadata
- summary fields where appropriate

This is not one single table.
It is a reconstruction layer built from canonical sources.

## Match-Level Data

### What belongs on `matches`

Use `matches` for top-level truth such as:
- match identity
- match mode
- game type
- game name
- winner
- started/ended timestamps
- terminal outcome
- remote lifecycle state
- match-level summary/progression state

Examples of summary/progression fields include:
- `winner_id`
- `started_at`
- `ended_at`
- `remote_status`
- `current_player_id`
- `player_scores`
- `last_visit_payload`
- `turn_index_in_leg`

### What match-level data is good for

Match-level fields are good for:
- current match state
- fast summaries
- list views
- terminal outcome
- current score snapshot
- latest visit snapshot
- lifecycle routing/state

### What match-level data is not for

Do not treat match-level fields as:
- the full historical record
- the canonical source of all visits
- a safe replacement for `match_throws`
- proof of exactly how gameplay unfolded turn by turn

### Important rule

A summary field is still only a summary field, even if it is very useful.

## Turn-Level Data

### What belongs in `match_throws`

Use `match_throws` for:
- per-turn / per-visit records
- score before each turn
- score after each turn
- turn ownership via `player_order`
- turn sequence via `turn_index`
- bust outcome
- turn-level game metadata

Important shared fields include:
- `match_id`
- `player_order`
- `turn_index`
- `throws`
- `score_before`
- `score_after`
- `is_bust`
- `game_metadata`

### What turn-level data is good for

Turn rows are good for:
- replaying what actually happened
- building history timelines
- computing detailed gameplay breakdowns
- understanding partial matches
- reconstructing turn-by-turn progression
- supporting game-specific logic where metadata is needed

### Important rule

If the question is:
- “what actually happened?”
- “what were the turns?”
- “what order did visits happen in?”
- “what score changes happened over time?”

then the answer should start with `match_throws`.

## Summary Fields vs Canonical History

This is the most important distinction in the doc.

### Summary fields
Examples:
- `player_scores`
- `last_visit_payload`
- current/final turn counters
- winner and terminal fields

These are useful because they make current state and summary UI easier.

### Canonical history
Examples:
- rows in `match_throws`
- per-turn `throws`
- per-turn `score_before`
- per-turn `score_after`
- per-turn game metadata

These are useful because they tell you what actually happened.

### Core rule

**summary helps you know the current or final state; turn history helps you know the path**

Do not replace the path with the snapshot.

## `player_scores`

### What it is

`player_scores` is a match-level summary field.

It represents score state at the match level, not the full turn-by-turn record.

### Good use

Use it for:
- current score snapshot
- final score summary
- quick display when full history is not needed

### Bad use

Do not use it as the only source for:
- history reconstruction
- turn ordering
- detailed scoring sequence

## `last_visit_payload`

### What it is

`last_visit_payload` is a match-level convenience snapshot of the most recent visit.

### Good use

Use it for:
- quick current-state display
- showing the latest action
- lightweight summary/state refresh

### Bad use

Do not use it as:
- the full gameplay record
- proof that only one visit exists
- a substitute for `match_throws`

### Important rule

`last_visit_payload` tells you about the latest visit, not all visits.

## `turn_index_in_leg`

### What it is

`turn_index_in_leg` is a match-level progression counter.

### Good use

Use it for:
- current progression state
- current match bookkeeping
- quick lifecycle/progression logic

### Bad use

Do not treat it as the full historical sequence source.
That is still the turn table’s job.

## History Reconstruction Rule

When reconstructing history, use the right source for each concern.

### Use `matches` for:
- top-level match identity
- mode
- game type
- final/terminal outcome
- winner
- timing
- summary state

### Use `match_players` for:
- player identity
- player order mapping
- resolving which player a turn belongs to

### Use `match_throws` for:
- actual visit sequence
- score progression
- per-turn outcomes
- game-specific metadata

### Use summary fields carefully

Use summary fields to support:
- quick summaries
- current state
- terminal display

But not as the main replacement for turn history.

## Partial and Terminal Match Rule

This is where many bugs come from.

Not every match reaches clean full completion.

A match may be:
- completed
- cancelled before gameplay
- cancelled after gameplay starts
- expired before gameplay
- expired after some gameplay
- only partially initialized

That means:
- some matches have no throw rows
- some terminal matches have partial throw history
- some summary fields may be present only when gameplay actually progressed

### Important rule

Do not assume:
- only completed matches have throw rows
- every cancelled or expired match has no gameplay data
- all terminal rows are structurally identical

History logic must work from the actual data present, not from status alone.

## Turn Truth vs Display Truth

Sometimes a UI only needs:
- final winner
- final score snapshot
- most recent visit
- quick summary line

That is display truth.

Sometimes a UI needs:
- exact turn order
- exact scoring sequence
- what happened before the match ended
- mode-specific turn breakdown

That is historical truth.

### Core rule

Do not use display truth as if it were historical truth.

## Game-Type Differences

Different game types use turn history differently.

### Standard scoring games

Games like x01 rely mostly on shared turn fields such as:
- `throws`
- `score_before`
- `score_after`
- `is_bust`

### Metadata-heavy games

Some games also need extra turn-level metadata.

Known examples include:
- `halve_it`
- `killer`

### Important rule

The turn table is still the canonical history layer, but some games need metadata there to make history meaningful.

Do not flatten all game types into one identical history model.

## Common Mistakes

### Mistake: using `last_visit_payload` as match history

Why it is wrong:
- it is only the latest visit snapshot
- it does not tell the full sequence

### Mistake: using `player_scores` as if it explains how the match unfolded

Why it is wrong:
- it shows score state, not turn sequence

### Mistake: assuming no throws means no meaningful row

Why it is wrong:
- a match may still have top-level outcome meaning even without gameplay detail

### Mistake: assuming terminal matches all have the same history structure

Why it is wrong:
- some terminal matches are fully played
- some are partial
- some never started

### Mistake: reconstructing history from the easiest field instead of the canonical one

Why it is wrong:
- convenience fields are not ownership fields

## Good Questions To Ask

Ask:
- is this current/final summary, or full history?
- do I need top-level outcome or turn sequence?
- which table actually owns this truth?
- could this match be partial or early-terminated?
- does this game type need extra turn metadata?

These questions usually point you to the correct level.

## Bad Questions To Ask

Avoid starting with:
- “can’t we just use `last_visit_payload`?”
- “can’t we just read the score from `matches`?”
- “if the match is cancelled, history probably does not matter”
- “if the row has the winner, that should be enough to reconstruct it”

Those shortcuts often create history bugs.

## Decision Checklist

Before writing a history query or changing schema, ask:

1. is this top-level match truth or turn-level truth?
2. am I using a summary field where full history is required?
3. do I need player-order mapping from `match_players`?
4. could this match be partial or terminal without being fully completed?
5. does this game type require extra turn metadata?

If those answers are unclear, the change is probably unsafe.

## Relationship to Other Docs

Use this doc when the main question is:

**what belongs on the match row, what belongs in turn history, and how should history be reconstructed safely?**

Use it with:
- `core-match-tables.md` for the table map
- `local-vs-remote-data-boundaries.md` for mode-specific storage differences
- `game-type-storage-patterns.md` for metadata patterns by game type
- `query-conventions.md` for safe joins and canonical query sources

This doc answers:

**what is summary, what is turn truth, and what is safe history reconstruction?**

## Bottom Line

In Dart Freak:

- `matches` holds top-level truth and summary
- `match_throws` holds what actually happened
- history should be reconstructed from canonical sources
- summary is useful, but summary is not history