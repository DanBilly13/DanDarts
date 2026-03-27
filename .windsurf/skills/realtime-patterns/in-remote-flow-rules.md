> Supporting reference for: realtime-patterns  
> Apply when: deciding how realtime, refetches, list reloads, overlays, or navigation should behave while the user is already inside a remote match flow  
> Do not apply to: local matches or any flow not owned by a remote Supabase-backed match

# In-Remote-Flow Rules

## Purpose

This document defines what “in remote flow” means and how the client should behave while the user is already inside a remote remote-match-owned screen.

This exists because many remote bugs come from one of two mistakes:
1. doing broad reloads too aggressively while the user is deep in a live remote flow
2. suppressing reloads so aggressively that list-backed UI becomes stale

The goal is to make that tradeoff explicit.

---

## Core Rule

When the user is already in remote flow, prefer narrow authoritative updates.

Default behavior:
- prefer `fetchMatch(...)`
- avoid broad `loadMatches(...)` churn

But this is a default, not a hard ban.

Break the default only when stale list-backed state would otherwise leave the UI wrong.

---

## What “In Remote Flow” Means

A user is considered **in remote flow** when the app is currently owned by an active remote-match screen or transition.

Typical examples:
- remote lobby
- remote gameplay
- replay lobby
- remote end-game continuation that is still tied to an active remote flow
- guarded remote navigation transitions where the current match is already the active focus

In practical terms, “in remote flow” means:
- one remote match currently owns the user’s attention
- the app should avoid unnecessary list churn
- active-match truth matters more than broad list refresh by default

---

## Why This Rule Exists

Broad list reloads during remote flow can cause:
- unnecessary UI churn
- stale-to-fresh flicker in unrelated sections
- redundant work while the user only cares about one active match
- confusing interactions between active flow state and background list state

So the default is:

**if one active remote match owns the screen, update that match first**

That usually means `fetchMatch(...)`.

---

## Default Behavior While In Remote Flow

When in remote flow:

### Prefer
- `fetchMatch(...)`
- flowMatch updates
- active-match-driven phase changes
- authoritative confirmation before navigation

### Avoid by default
- broad `loadMatches(...)`
- section churn unrelated to the current active match
- using background card arrays to drive the active screen
- refetch strategies that disturb the user’s active flow without need

This default keeps the active experience stable.

---

## What This Default Does Not Mean

“In remote flow” does **not** mean:
- never reload lists
- ignore replay updates
- ignore sent/pending/ready card changes
- allow overlays to stay stale
- trust current local state more than the server

It only means:
- do not broad-reload unless there is a specific stale-array reason to do so

---

## The Override Rule

Override the default and force a broader reload when the current UI depends on list-backed truth.

That includes cases where:
- replay UI depends on service arrays
- an overlay is watching replay/sent/pending/ready card state
- a remote cancellation must remove or dismiss something list-backed
- card classification must change immediately
- the active screen is still on top, but the UI being shown is not actually driven only by `flowMatch`

This is the main exception.

---

## Good Default Cases

### Good: remote lobby phase update
The user is in lobby and the current match changes.

Use:
- `fetchMatch(...)`

Why:
- one active match owns the screen
- no list classification is needed

---

### Good: gameplay turn/state update
The user is in gameplay and the authoritative match changes.

Use:
- `fetchMatch(...)`

Why:
- active gameplay is driven by one match
- broad list refresh would add churn without helping correctness

---

### Good: authoritative start/in-progress transition
The lobby needs to confirm the match became `in_progress`.

Use:
- `fetchMatch(...)`

Why:
- the active match is what matters
- navigation should follow authoritative confirmation from the active match

---

## Good Override Cases

### Good: replay overlay backed by arrays
The user is technically in remote flow, but the replay overlay is rendering from service arrays.

Use:
- forced `loadMatches(...)`

Why:
- active-match refetch alone will not refresh list-backed replay state

---

### Good: sent/pending/ready card must move while flow is active
A remote status change affects a list-backed card that is still visible or relevant.

Use:
- forced `loadMatches(...)` if normal list reload would be skipped

Why:
- stale arrays would otherwise leave the wrong card on-screen

---

### Good: remote cancellation should dismiss array-backed UI
The user is in remote flow, but the visible overlay/card depends on classified arrays.

Use:
- forced `loadMatches(...)`

Why:
- the active match is not the only truth the UI is depending on

---

## Bad Uses of the In-Remote-Flow Rule

### Bad: treating it as a hard ban
- realtime arrives
- arrays need refresh
- code skips reload only because `isInRemoteFlow == true`
- replay overlay stays stale

This is one of the most common bugs.

---

### Bad: using it to justify stale UI
- “we are in remote flow, so I won’t reload”
- sender/receiver cards never update
- overlay never dismisses
- cancellation never appears

“In remote flow” is not an excuse for stale state.

---

### Bad: ignoring what the UI is actually rendering from
- the screen is visibly array-backed
- code still chooses `fetchMatch(...)` only
- nothing changes because the arrays never reload

The rule is about **what the UI depends on**, not about what the route is called.

---

## Decision Rule While In Remote Flow

Ask these questions in order:

1. is the visible UI driven by one active match or by service arrays?
2. if I only run `fetchMatch(...)`, will the visible UI become correct?
3. if I skip `loadMatches(...)`, will cards/overlays remain stale?
4. is the stale thing actually part of replay, sent, pending, or ready list-backed UI?
5. am I avoiding reload for correctness reasons, or only because of a blanket in-flow guard?

If the visible UI is not driven only by the active match, the default rule may need to be overridden.

---

## Flow Ownership Rule

While in remote flow, the active match owns:
- lifecycle transitions for lobby/gameplay
- authoritative phase updates
- turn ownership
- countdown/start checks on the current screen

But active flow ownership does **not** automatically own:
- replay overlays backed by arrays
- remote card sections
- sent/pending/ready list truth
- background list classification problems that are still visible to the user

This distinction matters.

---

## Replay Is the Biggest Exception

Replay often breaks the simple in-flow rule.

Why:
- the user may be inside a remote-owned screen
- but the replay UI may still depend on service arrays
- replay ready/cancelled transitions often need list refresh, not only active-match refresh

So for replay:
- do not assume `fetchMatch(...)` is enough
- check whether the current replay UI is actually array-backed
- force reload when stale arrays would otherwise break the UX

Replay is where this rule most often needs deliberate override.

---

## Navigation Rule While In Remote Flow

Being in remote flow does not make realtime-driven navigation safe.

Even while in flow:
- realtime should trigger authoritative refetch
- navigation should wait for authoritative confirmation
- local guards must confirm the current screen instance is still valid

Bad:
- realtime arrives during lobby
- payload suggests `in_progress`
- immediate push to gameplay

Good:
- realtime arrives
- `fetchMatch(...)` confirms `in_progress`
- guards confirm correct screen context
- then navigate

---

## Logging Rule

When the code chooses to skip or override reload while in remote flow, log the reason.

Useful logs:
- in remote flow: yes/no
- chosen path: `fetchMatch`, `loadMatches`, forced `loadMatches`
- why broad reload was skipped
- why broad reload was forced
- whether the visible UI is active-match-driven or array-driven

Bad logs:
- “skipped”
- “reloaded”
- no decision context

The point of the log is to explain the decision.

---

## Good Patterns

### Pattern: stable active flow
- user is in lobby/gameplay
- realtime event affects current match
- use `fetchMatch(...)`
- update from authoritative match
- keep list churn suppressed

### Pattern: controlled override
- user is in remote flow
- replay overlay depends on arrays
- normal reload would no-op
- use forced `loadMatches(...)`
- overlay updates correctly

Both are correct.
The difference is what the visible UI depends on.

---

## Bad Patterns

### Pattern: blanket suppression
- `isInRemoteFlow == true`
- all list reloads skipped
- replay/sent/pending/ready UI stays stale

### Pattern: blanket broad reload
- `isInRemoteFlow == true`
- every event triggers `loadMatches(...)`
- active flow gets noisy and unstable

### Pattern: wrong mental model
- code chooses based on route name alone
- ignores whether the visible UI is flowMatch-backed or array-backed

---

## Client May / Must Not

### Client may
- suppress broad reload by default while in remote flow
- prefer `fetchMatch(...)` for active-match truth
- override suppression when stale arrays would break visible UI
- log why the override happened

### Client must not
- treat in-flow suppression as absolute
- allow replay/list-backed UI to stay stale just to preserve the default
- force broad reload for every event without checking what the UI depends on
- confuse “currently in remote flow” with “only the active match matters”

---

## Debug Rule

When a stale UI bug happens during remote flow, ask:

1. was the screen actually active-match-driven or array-driven?
2. did the code default to suppression?
3. should suppression have been overridden?
4. was `fetchMatch(...)` chosen when `loadMatches(...)` was really needed?
5. was forced reload required but not used?

A lot of “remote flow bugs” are actually bad override decisions.

---

## Bottom Line

While in remote flow, default to narrow active-match updates.

But if the visible UI depends on list-backed truth, override that default deliberately.  
Stable flow is the goal — not stale flow.