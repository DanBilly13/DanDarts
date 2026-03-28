> Supporting reference for: database-patterns  
> Apply when: adding or changing tables, columns, constraints, indexes, enums, functions, or any database-backed behavior that could affect existing Dart Freak data or queries  
> Do not apply to: pure query-writing with no schema change, UI-only refactors, realtime subscription behavior, or navigation logic unless the issue is specifically caused by schema design

# Migrations and Schema Changes

## Purpose

This document defines how schema changes should be made safely in Dart Freak.

It exists to stop mistakes like:
- changing schema based only on new matches
- adding fields without considering old rows
- breaking history reconstruction
- assuming all rows are fully populated
- baking one game type’s needs into the shared schema
- using migrations to patch over unclear data ownership

This document is about **safe schema evolution**.

## Core Rule

Before making any schema change, ask:

1. what truth is changing?
2. where does that truth actually belong?
3. what existing rows will this affect?
4. what queries, history reads, or functions depend on the current shape?
5. does this require a backfill, compatibility layer, or phased rollout?

In short:

**a schema change is only safe if old data and old read paths still make sense**

## Default Migration Mindset

A migration should do one of these clearly:

- add a new piece of truth at the correct level
- improve performance without changing meaning
- tighten an invariant that the data is already ready to satisfy
- retire a legacy pattern safely

A migration should **not** be used to:
- hide unclear ownership
- duplicate truth “just in case”
- encode UI assumptions as DB invariants without intent
- patch a bug by storing more convenience data in the wrong place

## Decide the Level First

Before changing schema, identify the data level.

### Match-level change
Examples:
- outcome fields
- timing fields
- top-level mode or lifecycle fields
- summary/progression fields

These belong on `matches`.

### Player/order change
Examples:
- player identity
- player order
- guest vs user representation

These belong in player tables, not as ad hoc fields on `matches`.

### Turn/history change
Examples:
- per-turn data
- per-visit scoring
- turn-specific flags
- turn-specific metadata

These belong in `match_throws`, not as repeated snapshots on `matches`.

### Game-specific metadata change
Examples:
- rules context that only applies to one game family
- turn-level metadata for special modes

These should usually be added at the turn layer, not by bloating the shared match schema.

## Backward Compatibility Rule

Every migration must be evaluated against existing rows.

Ask:
- do old rows already have this field?
- if not, what value will they get?
- will existing queries still behave sensibly?
- will existing history still reconstruct?
- will older partial rows violate the new assumption?

### Important rule

Do not design migrations as if only new rows matter.

Dart Freak already has:
- local and remote rows
- multiple game families
- completed rows
- partial rows
- cancelled/expired rows
- older data shapes

The migration must respect that.

## Non-Null Columns Rule

Be careful adding non-null columns.

Before adding a non-null field, ask:
- what will existing rows contain?
- can this value be derived safely?
- do partial/older rows actually have a meaningful value here?
- should this be nullable until backfilled?

### Safer pattern
- add nullable column first
- backfill if needed
- verify reads
- only then make stricter if truly justified

### Unsafe pattern
- add non-null column immediately
- guess a default that changes meaning
- assume old rows will “be fine”

## Defaults Rule

Defaults should be used carefully.

A default is safe when it means:
- a true default business meaning
- not just “something non-null so the migration passes”

### Good default
A value that genuinely means the same thing for old and new rows.

### Bad default
A filler value that makes old data look more complete or more certain than it really is.

### Important rule

A default that changes interpretation is not harmless.

## Constraints Rule

Constraints are good only when the actual data model is ready for them.

Before adding a constraint, ask:
- is this already true in existing data?
- is it a database invariant or only a UI/product rule?
- do partial/legacy rows violate it?
- does this apply to all modes and game types, or only some?

### Good use of constraints
- true invariants
- player/order integrity
- value-domain enforcement
- safe uniqueness rules

### Bad use of constraints
- freezing current UI assumptions into DB rules without intent
- applying remote-only logic to local rows
- applying completed-match assumptions to all rows

## Index Rule

Indexes should reflect real query patterns, not guesses.

Before adding an index, ask:
- what query is this supporting?
- is the query frequent enough to justify it?
- is the index mode-specific?
- does a partial index make more sense?
- does the index reflect canonical read paths?

### Good index changes
- supporting common list queries
- supporting common participant lookups
- supporting lifecycle/status filtering
- supporting history lookup by `match_id`

### Bad index changes
- indexing unused convenience fields
- indexing fields just because they exist
- adding broad indexes when a partial index matches the real workload better

## Enum and Status Changes Rule

Be very careful with enum and status changes.

Before changing an enum or status model, ask:
- what code paths already depend on the current values?
- what old rows already use them?
- what functions or policies assume the current set?
- does history/debug logic assume certain terminal meanings?

### Important rule

Status changes are not just schema changes.
They are behavior changes.

Treat them as high-risk.

## Table Split / Table Merge Rule

If you are thinking about:
- adding a new table
- splitting one table into two
- merging two layers into one

first ask:
- are these actually different levels of truth?
- or are you creating a new table because ownership is unclear?

### Good reason to split
- two different truth layers are being mixed
- one table is carrying unrelated responsibilities
- game-specific data needs a cleaner boundary

### Bad reason to split
- temporary confusion
- trying to avoid understanding canonical ownership
- hiding read complexity instead of fixing it

## Legacy Field Rule

Treat legacy fields carefully.

Before removing or ignoring a field, ask:
- is new code still reading this?
- do old rows still depend on it?
- does any history screen or export still use it?
- should this be documented as legacy before removal?

### Good pattern
- mark as legacy in docs and code
- stop new writes first
- verify read paths
- migrate or retire later

### Bad pattern
- stop thinking about the field because it is inconvenient
- delete it before proving nothing depends on it

## Product Rule vs Schema Rule

Do not automatically turn product/UI behavior into schema enforcement.

Examples:
- current player limits
- current remote-only assumptions
- setup-time restrictions

Before encoding one of these into schema, ask:
- is this meant to be a long-term invariant?
- or just the current app behavior?

### Important rule

Only enforce in schema what truly belongs in schema.

## Partial Rows Rule

Schema changes must survive partial and terminal rows.

This matters especially for:
- remote rows that never fully establish
- cancelled/expired rows
- rows with incomplete related-table population
- history rows created under older app behavior

### Important rule

Do not write migrations that assume every row is fully mature.

## Function / RPC Compatibility Rule

If a schema change touches fields used by DB functions or RPCs, check them explicitly.

Ask:
- does this function read the old field?
- does it write the old field?
- does its logic depend on old constraints or nullability?
- does it need a companion migration or rewrite?

A schema migration that leaves server-side functions inconsistent is not complete.

## RLS / Policy Compatibility Rule

If a schema change affects ownership or access, review RLS and policies too.

Ask:
- does a policy reference this column?
- does this table’s access model change?
- are new rows readable/writable under the intended rules?
- does the migration accidentally widen or narrow access?

A schema change can silently break reads even when the table shape looks correct.

## Safe Migration Patterns

### Additive first
Prefer:
- add field/table/index
- update writers
- update readers
- backfill if needed
- tighten later if appropriate

### Phase changes
For risky changes:
- support old and new shape briefly
- migrate reads and writes deliberately
- remove legacy path only after verification

### Document the ownership change
If the migration changes canonical ownership, document it clearly.

## Unsafe Migration Patterns

Avoid:
- changing ownership without documenting it
- replacing canonical truth with convenience fields
- assuming completed rows represent all rows
- adding “temporary” duplicated fields that never get removed
- using broad defaults that distort old data
- applying one mode’s assumptions to the whole schema

## Common Mistakes

### Mistake: adding summary data because queries are hard
Why it is wrong:
- query difficulty is not proof that ownership should move

### Mistake: making old rows fake-complete
Why it is wrong:
- backfills and defaults should preserve meaning, not invent it

### Mistake: adding a shared column for one game type
Why it is wrong:
- game-specific metadata often belongs at the turn layer

### Mistake: tightening constraints before old rows are ready
Why it is wrong:
- the migration may validate structure while breaking historical meaning

### Mistake: changing schema without checking functions and policies
Why it is wrong:
- DB behavior includes more than the table definition

## Decision Checklist

Before approving a migration, ask:

1. what truth is changing?
2. what table/level should own that truth?
3. what existing rows are affected?
4. do queries still work?
5. do history reads still work?
6. do functions/RPCs still work?
7. do policies still work?
8. does this need a backfill or phased rollout?
9. am I enforcing a real invariant or just current app behavior?

If those answers are unclear, the migration is probably unsafe.

## Relationship to Other Docs

Use this doc when the main question is:

**how do I change Dart Freak schema safely without breaking old data, history, or read paths?**

Use it with:
- `core-match-tables.md` for table ownership
- `local-vs-remote-data-boundaries.md` for mode-specific assumptions
- `match-vs-turn-vs-history-data.md` for summary vs history ownership
- `game-type-storage-patterns.md` for game-specific storage needs
- `query-conventions.md` for canonical read-path expectations
- `rls-and-auth-patterns.md` for access model implications

This doc answers:

**how should schema evolve safely over time?**

## Bottom Line

In Dart Freak, safe migrations do not just make the new schema work.

They preserve meaning for:
- old rows
- partial rows
- history reads
- functions
- policies
- and every game mode that already exists