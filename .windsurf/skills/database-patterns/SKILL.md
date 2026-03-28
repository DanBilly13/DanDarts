---
name: database-patterns
description: database patterns for dart freak. use when working on supabase schema, table relationships, player storage, history reconstruction, query design, local vs remote data boundaries, rls/auth, or migrations.
---

# Database Patterns

Use this skill when working on Dart Freak database design or any 
logic that depends on database structure.

## Core Mental Model

Dart Freak database truth lives in layers:

- **match level** — identity, mode, game type, outcome, remote 
lifecycle fields
- **player/order level** — who is in the match and in what order
- **turn/history level** — what actually happened each visit
- **game metadata level** — game-specific turn data where needed

Store truth at the narrowest correct level.  
Do not let convenience summary fields replace canonical data.

## Decision Order

Before any database change, answer:

1. what is the canonical truth?
2. what level does it belong at?
3. is this shared across local and remote, or mode-specific?
4. is this a product/UI rule or a real database invariant?
5. will this still work for partial matches, cancelled rows, and 
old data?

## What This Skill Prevents

- storing turn data on the match row
- treating summary/convenience fields as canonical history
- assuming remote and local reconstruct history the same way
- assuming every match has full related-table population
- assuming one game type's storage pattern applies to all games
- writing queries that only work for completed happy-path rows
- writing migrations that break old rows

## Supporting References

- `core-match-tables.md` — table map and canonical roles
- `local-vs-remote-data-boundaries.md` — shared vs mode-specific 
storage
- `match-vs-turn-vs-history-data.md` — history reconstruction rules
- `game-type-storage-patterns.md` — per-game metadata patterns
- `query-conventions.md` — safe joins and canonical query sources
- `migrations-and-schema-changes.md` — safe schema evolution
- `rls-and-auth-patterns.md` — access and policy rules

## Bottom Line

Put truth in the right table at the right level.  
Summary is not history.  
Local and remote are not the same.  
Old rows are not always fully populated.