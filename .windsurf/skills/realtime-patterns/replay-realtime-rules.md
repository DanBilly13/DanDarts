> Supporting reference for: realtime-patterns  
> Apply when: working on replay challenge creation, replay ready/cancelled transitions, replay overlays, replay lobby entry, replay session rebinding, or any realtime bug that only happens in replay flows  
> Do not apply to: local matches or non-replay remote challenge flows unless contrast helps


# Replay Realtime Rules

## Purpose

Replay is a special realtime case in the remote match system.

It looks similar to normal remote challenge flow, but it has extra complexity because replay often combines:
- active remote flow
- service-array-backed UI
- replay-specific lifecycle transitions
- voice session reuse / rebinding
- overlay-driven behavior

Because of that, replay bugs often do **not** follow the simple “just fetch the active match” rule.

This document defines the replay-specific exceptions and rules.

---

## Core Rule

Treat replay as a remote flow with extra realtime sensitivity.

For replay:
- realtime is still a trigger, not truth
- authoritative refetch is still required
- but replay UI often depends on service arrays, not just one active match
- so replay may require forced list reloads even while already in remote flow

Replay is the main place where normal in-flow suppression needs careful exceptions.

---

## Why Replay Is Different

Replay is different because the user may already be inside a remote-owned screen when replay state changes.

Examples:
- end-game replay overlay is visible while still tied to the previous remote match flow
- replay status changes to `ready`
- replay is cancelled remotely
- replay challenge disappears from service arrays
- replay lobby reuses or rebinds a voice session

That means replay UI may be driven by:
- service arrays
- overlay state
- active match refetch
- voice rebind state

all at the same time

A normal remote match bug may be fixed by `fetchMatch(...)`.
A replay bug often is not.

---

## Core Replay Rule

When a replay-related realtime event arrives, first ask:

**Is the visible replay UI driven by the active match, or by service arrays / overlay state?**

If it is driven by:
- active replay match state → `fetchMatch(...)` may be enough
- replay cards / replay overlay / service arrays → `loadMatches(...)` or forced `loadMatches(...)` may be required

Do not assume replay is just another active-match refetch problem.

---

## Replay Overlay Diagnostic Questions

Before fixing any replay overlay bug, answer these questions explicitly:

- is the overlay reading from current service arrays?
- is it polling service arrays?
- is it waiting for service arrays to update?
- is it rendering from a cached replay object that originally came from arrays?
- or is it truly driven by one actively refetched authoritative match?

This is one of the most important replay checks in the whole system.

If the overlay is array-backed, then:
- `fetchMatch(...)` alone is often not enough
- array freshness is part of correctness
- forced `loadMatches(...)` may be required even while in remote flow

If the overlay is truly active-match-driven, then:
- `fetchMatch(...)` is usually the correct path
- broad list reload may be unnecessary

Do not guess which model the overlay uses.
Identify it first.

---

## Replay Status Changes That Matter Most

The most important replay realtime transitions are:

- replay becomes `ready`
- replay becomes `cancelled`
- replay disappears from service arrays after cancellation/expiry/reclassification
- replay enters `lobby`
- replay enters `in_progress`

Each of these may need a different reaction depending on what the UI is rendering from.

---

## Replay Ready Rule

When replay changes to `ready`:

### If the UI is list-backed
Examples:
- replay card shown in sent/ready/pending sections
- replay overlay watching service arrays

Use:
- `loadMatches(...)`
- forced `loadMatches(...)` if normal list reload would be skipped in remote flow

Why:
- replay card visibility and section movement are array problems

### If the UI is active-match-driven
Examples:
- already inside the replay match flow and only one active replay match matters

Use:
- `fetchMatch(...)`

Why:
- the current screen is driven by one authoritative match

---

## Replay Cancelled Rule

When replay changes to `cancelled`:

### If the UI depends on arrays or overlay state
Use:
- `loadMatches(...)`
- forced `loadMatches(...)` if stale arrays would otherwise remain on screen

Why:
- cancelled replay often needs:
  - card removal
  - overlay dismissal
  - section reclassification
  - disappearance from sent/pending/ready arrays

### Important
Do not assume `fetchMatch(...)` alone will fix a replay cancellation bug if the overlay/card is array-backed.

This is one of the most common replay mistakes.

---

## Replay Disappearance Rule

Sometimes replay does not remain visible as `cancelled`.
Instead, it disappears from authoritative service arrays after reload.

That is still authoritative truth.

So replay UI must handle both:
1. replay found with updated cancelled/changed status
2. replay no longer found in arrays

If the replay disappears from authoritative arrays:
- treat that disappearance as meaningful
- do not keep stale overlay state alive just because the last local object still exists

For replay overlays, disappearance from authoritative arrays is often the correct dismissal signal.

---

## Replay Overlay Rule

Replay overlays are a special case.

An overlay may appear to be “about one replay match,” but in practice it may still be driven by service arrays rather than by a dedicated authoritative active-match fetch.

That means:
- overlay bugs are often stale-array bugs
- overlay dismissal often depends on list truth
- replay cancellation often needs forced list reload even during remote flow

If the overlay is array-backed, treat it as an array-backed problem, not a single-match problem.

---

## Replay and In-Remote-Flow Suppression

Replay is the most common reason to override the normal “skip broad reload while in remote flow” rule.

Default remote-flow rule:
- prefer `fetchMatch(...)`
- suppress broad list reloads

Replay exception:
- if replay UI is backed by arrays and must react now, force the list reload

Typical cases:
- replay changed to `ready`
- replay changed to `cancelled`
- replay overlay needs dismissal
- replay card must move sections
- replay disappearance from arrays is the authoritative signal

If you do not override in these cases, replay UI often stays stale.

---

## Replay Navigation Rule

Realtime must not directly own replay navigation.

Bad:
- realtime says replay is ready
- client immediately navigates

Good:
- realtime arrives
- authoritative state is reloaded
- replay is confirmed as ready/joinable
- local guards confirm current screen context
- then navigation happens

This is especially important because replay often happens while another remote flow is still winding down.

---

## Replay Rebind Rule

Replay may reuse or rebind an existing voice session.

That does **not** change the realtime rule.

Even when voice is reused:
- replay lifecycle state is still server-authoritative
- replay readiness still needs authoritative confirmation
- replay UI still must react to authoritative match/list state
- voice reuse does not make payloads trustworthy

Do not let “voice session preserved” turn into “client can skip refetch.”

Those are separate concerns.

---

## Replay Realtime and Voice Are Separate Layers

Keep these layers distinct:

### Voice layer
- peer connection
- signalling channel
- rebind/reannounce logic
- replay-ready event
- confirm voice ready call

### Replay lifecycle layer
- replay status
- replay card visibility
- replay lobby state
- countdown/start state
- overlay dismissal / navigation

The voice layer may help the replay proceed,
but it does not replace authoritative replay state.

A replay can look voice-ready locally and still require authoritative refetch for the UI to be correct.

---

## Replay Reload Decision Guide

Use this quick decision guide:

### Replay card moved between sections
Use:
- `loadMatches(...)`

### Replay overlay depends on service arrays
Use:
- forced `loadMatches(...)` if needed

### Replay active lobby/gameplay needs authoritative active state
Use:
- `fetchMatch(...)`

### Replay cancellation should dismiss overlay and arrays are stale
Use:
- forced `loadMatches(...)`

### Replay became ready while not inside active replay flow
Use:
- `loadMatches(...)`

---

## Good Replay Patterns

### Good: replay ready card
- realtime update arrives
- code recognizes replay/list-backed UI
- forced list reload runs if needed
- replay card moves to ready
- UI updates from authoritative arrays

### Good: replay cancelled remotely
- realtime update arrives
- authoritative arrays reload
- replay either appears as cancelled or disappears
- overlay/card dismisses from authoritative result
- no stale local replay object is kept alive

### Good: replay lobby transition
- replay becomes active flow
- current screen uses authoritative replay match fetch
- navigation waits for refetched status
- replay voice rebind remains separate from lifecycle truth

---

## Bad Replay Patterns

### Bad: replay treated like ordinary active match
- replay overlay is array-backed
- code only runs `fetchMatch(...)`
- arrays never refresh
- overlay stays stale

### Bad: replay cancellation trusted from payload
- realtime says cancelled
- overlay dismisses immediately
- authoritative arrays never confirmed the change

### Bad: replay ready causes instant navigation
- payload says ready
- UI pushes lobby
- later refetch disagrees or arrives out of order

### Bad: voice reuse treated as lifecycle truth
- replay voice rebind succeeds
- code assumes replay lifecycle is fully ready
- card/overlay/start logic skips authoritative checks

---

## Replay Debug Order

When replay realtime is broken, debug in this order:

1. did the replay realtime event arrive
2. was it identified as replay-specific
3. is the visible replay UI active-match-driven or array-driven
4. what refetch path was chosen
5. was broad reload suppressed because of in-remote-flow logic
6. did authoritative arrays change
7. did the replay overlay/card read from those arrays
8. did the replay disappear from arrays or change status
9. did navigation/dismissal wait for authoritative confirmation
10. was voice rebind incorrectly confused with lifecycle readiness

This order matters.

---

## Client May / Must Not

### Client may
- treat replay as a special realtime case
- force list reloads when replay UI depends on arrays
- dismiss replay overlay from authoritative disappearance
- keep voice rebind and replay lifecycle logic separate

### Client must not
- assume replay follows the normal active-match-only rule
- suppress reload just because the app is technically in remote flow
- trust replay payload alone for dismissal or navigation
- treat replay voice reuse as proof of replay lifecycle readiness

---

## What Good Looks Like

Good replay realtime handling has this property:

**replay UI becomes correct even if the realtime event only woke the client up, because authoritative reload strategy did the real work.**

That is the target.

---

## Bottom Line

Replay is not just “another remote update.”

It is the place where stale array truth, overlay truth, and active match truth collide.  
Handle it deliberately.