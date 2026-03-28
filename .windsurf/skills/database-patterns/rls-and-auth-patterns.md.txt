> Supporting reference for: database-patterns  
> Apply when: designing or changing Supabase RLS policies, deciding who should be able to read or write a table, or debugging database behavior that may actually be caused by access rules rather than schema shape  
> Do not apply to: pure query structure, UI-only permissions, navigation logic, or game-rule reasoning that does not depend on database access control

# RLS and Auth Patterns

## Purpose

This document explains how to think about row-level security and auth ownership in Dart Freak.

It exists to stop mistakes like:
- giving broad read access because it is convenient
- assuming all gameplay tables should share the same policy model
- confusing participant visibility with public visibility
- relying on client writes where the server should own the action
- changing schema without updating policies
- debugging a “missing data” problem that is really an RLS problem

This document is about **who should be allowed to read or write what, and why**.

## Core Rule

Access should follow real ownership.

Before writing or changing a policy, ask:

1. who owns this row?
2. who needs to read it?
3. who is allowed to create or change it?
4. is this a client-owned action or a server-owned action?
5. does this rule apply to all modes, or only local or remote?
6. does this table store canonical truth, summary, or infrastructure?

In short:

**make access follow the real data ownership model, not the easiest query path**

## Main Auth Model

Dart Freak data is not all owned the same way.

Different tables imply different ownership patterns:

- `matches` stores top-level match truth
- `match_players` stores player identity/order
- `match_throws` stores turn history
- `match_participants` stores participant snapshot/history-facing data
- `remote_match_locks` stores remote-only infrastructure
- push-token tables store user-specific device data

That means policies should not all be copy-pasted from one table to another.

## Access Model by Table Type

### Match tables
Access should generally be based on whether the user is actually part of the match or otherwise allowed to view it.

### Player/order tables
Access should track the match the player row belongs to.

### Turn-history tables
Access should track participation in the underlying match, not just raw visibility of the turn row itself.

### User-device tables
Access should generally be user-owned:
- users manage their own rows
- users do not manage everyone else’s

### Remote infrastructure tables
These often need tighter control and may be server-managed even if the client can read a narrow subset.

## Read Access Rule

Read access should be as narrow as the real use case allows.

Ask:
- does the user need this because they are part of the match?
- or is this accidentally broad because broad reads are easier?

### Safe pattern
A user can read:
- their own match rows
- related player rows for matches they are part of
- related throw rows for matches they are part of
- their own push-token rows

### Unsafe pattern
Authenticated users can read everything just because the app currently only has a small dataset.

### Important rule

Do not confuse:
- “the app needs this data somewhere”
with
- “every authenticated user should be able to read it”

## Write Access Rule

Write access should usually be stricter than read access.

Before allowing writes, ask:
- is this field/table supposed to be client-written?
- or should it only be changed by trusted server logic?

### Safe pattern
Users can directly write:
- rows that are genuinely theirs to create/manage
- user-specific token rows
- certain participant-owned actions if the schema is designed for it

### Unsafe pattern
Users can directly write any row they can read.

### Important rule

Being allowed to see a row does not automatically mean being allowed to mutate it.

## Server-Owned Truth Rule

Some database truth should be controlled by trusted server logic, not casually by the client.

This matters especially for:
- authoritative remote state transitions
- protected progression logic
- match outcome logic
- concurrency/lock handling
- any field where cheating, races, or inconsistent updates matter

### Safe pattern
Use server-side functions, RPCs, edge functions, or tightly constrained writes for high-trust actions.

### Unsafe pattern
Let the client directly update authoritative truth just because RLS can restrict the row to “participants.”

### Important rule

Participant ownership is not the same thing as authority to change canonical game state.

## Local vs Remote Access Boundary

Local and remote do not imply the same auth model.

### Local
Local matches may involve:
- multiple players
- guests
- locally structured player rows

So policy logic should not assume the same role model as remote.

### Remote
Remote matches involve:
- strict participants
- challenger/receiver role fields
- lifecycle/progression concerns
- potentially more server-authoritative state

So policy logic often needs more caution.

### Important rule

Do not copy a local-friendly policy model into remote tables without checking whether it allows unsafe writes.

## Participant-Based Access Rule

A lot of gameplay reads should be participant-based.

Examples:
- reading a match you are in
- reading throw history for a match you are in
- reading player rows for a match you are in

This is usually safer than:
- broad authenticated access

But participant-based access still needs the correct participation model.

### Safe rule
Define participation from the canonical source for that mode/table.

Do not infer participation from a convenience field if a more canonical ownership source exists.

## User-Owned Rows Rule

Some rows are straightforwardly user-owned.

Examples:
- push tokens
- device token rows
- other per-user infrastructure rows

For those, the normal pattern is:
- user can read their own row(s)
- user can insert/update/delete their own row(s)
- user cannot manage other users’ rows

This is the cleanest RLS pattern in the system.

## Infrastructure Table Rule

Infrastructure tables should be treated differently from gameplay tables.

Example:
- `remote_match_locks`

These tables often support internal coordination rather than player-facing truth.

### Safe pattern
Keep write access narrow.
Prefer server-managed writes where correctness matters.

### Unsafe pattern
Treat infrastructure tables like normal user-owned gameplay rows.

## Policies Should Follow Canonical Ownership

This is one of the most important rules.

If a table’s truth is match-owned, write policies in terms of match ownership or participation.

If a table’s truth is user-owned, write policies in terms of user ownership.

If a table’s truth is server-owned, do not pretend the client should manage it directly.

### Important rule

Write policies from the table’s actual ownership model, not from convenience or habit.

## RLS and Schema Changes

Every schema change that affects ownership or access assumptions should trigger a policy review.

Ask:
- does the new field/table change who owns the data?
- does the policy still reflect the canonical ownership model?
- does a new relationship need a new access path?
- did the migration silently widen or narrow access?

### Important rule

A schema change is not complete if the access model is now wrong.

## RLS and Query Bugs

Some missing-data bugs are actually policy bugs.

Before assuming:
- the row is missing
- the join is wrong
- the sync failed

ask:
- is RLS blocking the read?
- is the user actually allowed to see this row?
- is the policy using the correct ownership logic?

### Important rule

Not every empty result is a query bug.
Sometimes it is an auth bug.

## RLS and Historical Rows

Be careful with policies that assume every row is fully populated.

This matters especially for:
- older rows
- partial rows
- remote rows that never fully established
- rows created under earlier architecture patterns

### Safe rule
Policies should avoid depending on fields that may be absent or inconsistently populated unless that is explicitly intended.

### Unsafe rule
A policy assumes a perfect modern row shape for every historical row.

## Common Mistakes

### Mistake: broad authenticated read access
Why it is wrong:
- “authenticated” is not the same as “authorized for this match”

### Mistake: same policy for every gameplay table
Why it is wrong:
- table ownership differs by table type

### Mistake: letting participants directly mutate all remote truth
Why it is wrong:
- participation is not the same as authority

### Mistake: treating infrastructure tables like user-owned rows
Why it is wrong:
- support tables often need tighter control

### Mistake: forgetting to update policies after schema changes
Why it is wrong:
- the data model may change while access logic stays stale

## Good Questions To Ask

Ask:
- who owns this row?
- who needs to read it?
- who is allowed to change it?
- should this be client-written or server-written?
- is this rule based on canonical ownership?
- will this still work for old and partial rows?

These questions usually lead to safer policies.

## Bad Questions To Ask

Avoid starting with:
- “can we just allow authenticated users?”
- “can we just mirror the policy from the other table?”
- “can we just let the client update this directly?”
- “can we just open reads until the bug is fixed?”

Those shortcuts often create long-term security and correctness problems.

## Decision Checklist

Before adding or changing a policy, ask:

1. what table is this?
2. is it match-owned, user-owned, or server-owned?
3. who should read it?
4. who should write it?
5. is this local, remote, or shared?
6. does the policy depend on canonical ownership data?
7. does it still work for old and partial rows?
8. does it accidentally widen access beyond the real use case?

If those answers are unclear, the policy is probably unsafe.

## Relationship to Other Docs

Use this doc when the main question is:

**who should be allowed to read or write this table, and based on what ownership model?**

Use it with:
- `core-match-tables.md` for table roles
- `local-vs-remote-data-boundaries.md` for mode-specific structure
- `query-conventions.md` for canonical read paths
- `migrations-and-schema-changes.md` for schema evolution and compatibility

This doc answers:

**how should access control follow the real data model?**

## Bottom Line

In Dart Freak, good RLS follows real ownership.

- match-owned data should use match-based access
- user-owned data should use user-based access
- server-owned truth should stay tightly controlled

Do not widen access just because it makes queries easier.