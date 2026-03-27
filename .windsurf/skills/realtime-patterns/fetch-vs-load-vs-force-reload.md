> Supporting reference for: realtime-patterns  
> Apply when: deciding how the client should respond after a remote realtime event, remote action, replay status change, stale card bug, stale overlay bug, or any case where remote UI is not updating correctly  
> Do not apply to: local matches or any client state not backed by remote Supabase data


# Fetch vs Load vs Force Reload

## Purpose

This document defines the three-way refetch decision for remote matches:

- `fetchMatch(...)`
- `loadMatches(...)`
- forced `loadMatches(...)`

This is one of the easiest places for AI and humans to make the wrong call.

Most stale remote UI bugs happen because the app chose the wrong reload path, or skipped the right one.

---

## Core Rule

Choose the smallest authoritative refetch that can make the UI correct.

Use:
- `fetchMatch(...)` for one active match
- `loadMatches(...)` for list/card state
- forced `loadMatches(...)` when the normal in-remote-flow guard would otherwise leave list-backed UI stale

Do not use a bigger reload just because it is easy.
Do not use a smaller reload if the UI actually depends on list arrays.

---

## What Each Path Is For

### `fetchMatch(...)`
Use when the UI depends on **one active match**.

This is the right choice when:
- the user is in remote lobby
- the user is in remote gameplay
- the current screen is driven by `flowMatch` / active match state
- a lifecycle transition for one match needs confirmation
- you need authoritative truth for the currently open match

This path is match-specific and narrow.

---

### `loadMatches(...)`
Use when the UI depends on **classified match arrays**.

This is the right choice when:
- cards in pending / ready / sent sections may move or disappear
- replay cards depend on service arrays
- challenge list buckets need recomputing
- a match may need to appear or disappear from a list
- the screen is not only about one active match

This path is broader and list-oriented.

---

### forced `loadMatches(...)`
Use when the UI depends on list-backed truth, but the normal “skip broad reload while in remote flow” rule would otherwise keep stale arrays alive.

This is the right choice when:
- replay UI is backed by service arrays
- a replay overlay must react to ready/cancelled state
- a sent/pending/ready card must disappear or move while the user is still in remote flow
- a normal `loadMatches(...)` would be suppressed and cause stale UI

This is the exception path.

Use it deliberately, not casually.

---

## Decision Rule

Ask this question first:

**What is the UI actually rendering from right now?**

If the UI is rendering from:
- a single match model → use `fetchMatch(...)`
- section arrays / classified cards → use `loadMatches(...)`
- section arrays that would otherwise stay stale because broad reload is suppressed → use forced `loadMatches(...)`

That is the real decision rule.

---

## Use `fetchMatch(...)` When

Use `fetchMatch(...)` if all of these are true:

- the user is already inside a remote match flow
- one specific match is open
- the screen is driven by authoritative active-match state
- list sections do not need to be reclassified to make the screen correct

Typical examples:
- lobby countdown started
- current player changed
- match moved from lobby to in_progress
- voice readiness state for active match changed
- authoritative gameplay state changed

### Good examples
- remote lobby receives update → `fetchMatch(...)`
- gameplay receives turn change → `fetchMatch(...)`
- countdown/start transition for active match → `fetchMatch(...)`

### Bad examples
- sent challenge card should disappear → `fetchMatch(...)`
- replay overlay backed by arrays should dismiss → `fetchMatch(...)` only
- pending/ready/sent section needs reclassification → `fetchMatch(...)`

Those are list problems, not single-match problems.

---

## Use `loadMatches(...)` When

Use `loadMatches(...)` if the UI depends on list buckets or service arrays.

Typical examples:
- challenge accepted and should move from pending/sent to ready
- challenge cancelled and should disappear from lists
- declined challenge should leave the sender’s sent list
- a replay card should appear in ready or sent
- list sections need to recalculate what belongs where

### Good examples
- challenger sent card should update after receiver declines → `loadMatches(...)`
- ready card should appear after acceptance → `loadMatches(...)`
- pending card should be removed after cancellation → `loadMatches(...)`

### Bad examples
- active lobby screen needs latest countdown state and nothing else → `loadMatches(...)`
- gameplay turn change handled via full list reload → `loadMatches(...)`

That creates unnecessary churn.

---

## Use Forced `loadMatches(...)` When

Forced reload exists for a narrow reason:

sometimes the app is inside remote flow, so broad list reloads are normally skipped, but the current UI still depends on authoritative list arrays.

If you do not force reload in that case, the arrays stay stale and the UI lies.

### Typical forced reload cases
- replay status changes while the user is already in remote flow
- replay overlay is polling or rendering from service arrays
- cancellation/ready transitions for replay must update arrays immediately
- a list-backed remote UI is visible while standard in-flow suppression is active

### Good examples
- replay changed to `ready` while overlay/service arrays must update
- replay changed to `cancelled` while receiver-side overlay still depends on arrays
- a list-backed remote UI is visible and broad reload would otherwise no-op

### Bad examples
- force reload every time any realtime event arrives
- force reload active gameplay changes that only need `fetchMatch(...)`
- use forced reload as a substitute for understanding what the screen depends on

Forced reload is not “stronger fetch.”
It is an override for a specific stale-array problem.

---

## In-Remote-Flow Interaction

Default rule:
- while in remote flow, prefer `fetchMatch(...)`
- avoid broad list churn

Why:
- broad reloads can disturb screens that only need active-match truth
- they are more expensive and noisier
- they can cause UI churn while the user is already deep in a flow

But this is a default, not an absolute law.

If the current UI depends on service arrays and those arrays must change now, force reload is correct.

---

## Replay Is the Main Exception

Replay is the place where this distinction matters most.

Replay often mixes:
- active remote flow
- list-backed service arrays
- overlay state
- remote transitions like `ready`, `cancelled`, or disappearance from arrays

That means replay bugs often happen when:
- realtime arrives
- normal reload path is suppressed
- arrays stay stale
- overlay or replay card never updates

When replay UI depends on arrays, forced `loadMatches(...)` is often the correct answer.

---

## Navigation Interaction

Reload choice must be decided before navigation.

Bad:
- realtime arrives
- payload suggests `in_progress`
- client navigates immediately
- authoritative state catches up later

Good:
- realtime arrives
- choose `fetchMatch(...)`
- authoritative match confirms `in_progress`
- current screen validates
- then navigation happens

For list-driven navigation or replay dismissal:
- use `loadMatches(...)` or forced `loadMatches(...)`
- wait for authoritative arrays/state to confirm the change
- then update/dismiss/navigate

---

## Stale UI Smell Guide

Use this section as a quick diagnostic.

### Smell: active lobby/gameplay screen is stale
Likely fix:
- `fetchMatch(...)`

### Smell: sent/pending/ready cards are stale
Likely fix:
- `loadMatches(...)`

### Smell: replay overlay or replay card is stale while in remote flow
Likely fix:
- forced `loadMatches(...)`

### Smell: app reloads too much and UI churns everywhere
Likely fix:
- replace `loadMatches(...)` with `fetchMatch(...)` where only one active match matters

### Smell: nothing updates after realtime, but logs show event arrived
Likely fix:
- check whether correct reload path ran
- check whether normal reload was skipped when a force reload was actually needed

---

## Good Decision Examples

### Example 1: Lobby countdown started
The lobby screen is showing one active match.

Use:
- `fetchMatch(...)`

Why:
- the screen only needs updated active-match truth
- no list reclassification is required

---

### Example 2: Receiver declines a challenge
The sender’s sent card must disappear from the sent list.

Use:
- `loadMatches(...)`

Why:
- the sent section is list-backed
- card classification must be recomputed

---

### Example 3: Replay changed to ready while user is inside remote flow
Replay overlay depends on service arrays, but normal broad reload would be skipped.

Use:
- forced `loadMatches(...)`

Why:
- list-backed replay UI will stay stale otherwise

---

### Example 4: Match moved from lobby to in_progress
The open lobby screen should transition to gameplay.

Use:
- `fetchMatch(...)`

Why:
- the active match drives the transition
- navigation should wait for authoritative match confirmation

---

## Bad Decision Examples

### Bad: using `fetchMatch(...)` for list problems
- pending card should disappear
- sender card should move sections
- replay array-backed UI should update

Why bad:
- one match refetch does not reclassify service arrays

---

### Bad: using `loadMatches(...)` for active match truth
- gameplay turn changed
- lobby countdown started
- active flow needs one match update

Why bad:
- too broad
- noisy
- invites churn

---

### Bad: forcing reload by default
- every replay event
- every lobby event
- every active gameplay update

Why bad:
- hides architectural thinking
- makes bugs harder to reason about
- creates unnecessary churn

---

## Decision Checklist

Before choosing a path, ask:

1. is the UI driven by one active match or by service arrays?
2. does a card need to move, disappear, or reclassify?
3. am I already in remote flow?
4. would normal broad reload be skipped here?
5. if I do not force reload, will list-backed UI remain stale?
6. am I trying to fix a navigation problem that really needs authoritative refetch first?

If you cannot answer those, do not guess.
Figure out what the screen is actually rendering from.

---

## Client May / Must Not

### Client may
- prefer narrow refetches
- use broad reloads for list-backed UI
- force reload when stale arrays would otherwise break the UI
- log why a particular path was chosen

### Client must not
- use one reload path for all cases
- assume active-match refetch fixes list classification
- force reload by habit
- skip authoritative refetch because realtime payload “looks enough”

---

## What Good Looks Like

Good remote refetch behavior has this property:

**the chosen reload path exactly matches what the current UI depends on.**

If the UI is wrong, the fix is usually not “more reload.”
The fix is “the correct reload.”

---

## Bottom Line

Use `fetchMatch(...)` for one active match.  
Use `loadMatches(...)` for list truth.  
Use forced `loadMatches(...)` only when list truth would otherwise stay stale inside remote flow.