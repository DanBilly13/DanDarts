> Supporting reference for: swiftui-navigation  
> Apply when: deciding whether a remote transition is allowed, especially for lobby entry, gameplay push, replay lobby entry, overlay dismissal, or any route change that must wait for server-confirmed truth  
> Do not apply to: generic router structure, local-only navigation, or UI state changes that do not affect route transitions

# Authoritative Navigation Checks

## Purpose

This document defines the truth requirements that must be satisfied before remote navigation is allowed.

In Dart Freak, remote navigation is not allowed just because:
- a button was tapped
- a local flag changed
- a realtime payload arrived
- a view thinks it is “probably time”

Remote navigation must follow **authoritative state**.

This document exists to prevent:
- premature gameplay pushes
- replay navigation from stale list state
- lobby entry after cancellation or invalidation
- dismissal from local assumptions
- route changes that race ahead of server truth

---

## Core Rule

For remote flows:

**navigation is allowed only after the authoritative state required for that transition is confirmed.**

The transition owner may request navigation only when:
- the right authoritative facts are true
- the right guards still pass
- the current screen context is still valid

In short:

**authoritative truth first, route change second**

---

## What Counts as Authoritative Truth

Authoritative truth comes from:
- a freshly fetched active match
- freshly reloaded service arrays
- confirmed server-backed lifecycle state
- confirmed canonical match row fields

It does **not** come from:
- realtime payload alone
- optimistic local state
- stale cached card state
- overlay assumptions
- earlier status values that have not been revalidated

If a transition matters, re-check truth from the server-backed model that actually owns it.

---

## Why This Rule Exists

Remote transitions are especially vulnerable to “looks true locally” bugs.

Examples:
- local state says match started, but authoritative row does not
- replay card looks ready, but authoritative arrays still disagree
- overlay seems dismissable, but authoritative state has not actually removed the match
- lobby thinks gameplay is ready, but a stale instance is reading old match state

These bugs are expensive because they create:
- duplicate navigation
- wrong-screen transitions
- route changes that must later be undone
- UI that disagrees with backend truth

The fix is not “more confidence.”

The fix is authoritative confirmation.

---

## Transition Rule

Before any remote navigation happens, ask:

1. what exact transition is being requested?
2. what authoritative state must be true for that transition?
3. what source confirms that truth?
4. has that source been refreshed recently enough to trust?
5. does the current screen still match the thing being validated?

If those answers are unclear, navigation should not happen yet.

---

## Authoritative Sources by Transition Type

### Active match transitions
Usually confirmed by:
- `fetchMatch(...)`
- authoritative `flowMatch`
- current canonical match state after refetch

Typical examples:
- lobby → gameplay
- gameplay → end game
- terminal/unwind transitions
- active remote lobby checks

### List / replay / overlay transitions
Usually confirmed by:
- `loadMatches(...)`
- forced `loadMatches(...)` when needed
- authoritative arrays / match buckets
- replay presence/absence in arrays

Typical examples:
- replay becomes ready
- replay card moves sections
- replay overlay dismissal from disappearance/cancelled state
- sent/pending/ready card-driven transitions

The correct authoritative source depends on what the UI is actually rendering from.

---

## Gameplay Push Rule

Gameplay push is one of the highest-risk transitions.

Before lobby → gameplay is allowed, authoritative truth should confirm that:
- the match is really `in_progress`
- the current match identity is still correct
- the current screen instance is still valid
- the transition has not already been claimed by another instance
- the current flow still belongs to this match

This must not be based on:
- one local status change alone
- one payload alone
- a stale match object that has not been revalidated

Gameplay push should follow confirmed authoritative state, not a hopeful interpretation of events.

---

## Lobby Entry Rule

Before entering a remote lobby, authoritative truth should confirm that:
- the match is still valid for lobby entry
- the match has not been cancelled/invalidated
- the user action still belongs to the current request
- status is still compatible with entering that route
- the match identity still matches the nav request

This is especially important because lobby entry often involves async work:
- accept
- join
- replay entry
- post-edge-function transitions

By the time async work completes, truth may have changed.
That is why authoritative re-check matters.

---

## Replay Lobby Entry Rule

Replay lobby entry should only happen after authoritative state confirms replay is actually ready for that route.

That means:
- if the replay UI is list-backed, authoritative arrays must confirm the replay belongs in the navigable state
- if the replay UI is active-match-driven, authoritative replay match fetch must confirm it
- if replay state changed via realtime, that is still only a trigger to refetch, not permission to navigate

Do not navigate replay flow because:
- overlay state “looks ready”
- a payload suggested `ready`
- an old replay object still exists locally

Replay navigation must follow current authoritative truth.

---

## Dismissal Rule

Dismissal is also a navigation decision and must follow authoritative truth.

Before dismissing:
- confirm the authoritative reason is real
- confirm the current overlay/screen is still active
- confirm the source that owns the dismissal state was actually refreshed

Valid authoritative dismissal examples:
- replay no longer exists in authoritative arrays
- authoritative state confirms cancelled/terminal condition
- active match fetch confirms screen should no longer remain

Invalid dismissal examples:
- payload alone says cancelled
- local overlay state timed out
- last known object “probably means done”

---

## Realtime Is Not Enough

Realtime may tell the app that it should re-check whether navigation is valid.

Realtime may not, by itself, prove that navigation is valid.

This means:
- payload says `in_progress` → refetch, then decide
- payload says `cancelled` → reload, then dismiss if authoritative result agrees
- payload says replay is ready → reload authoritative replay source, then decide

This is one of the most important rules in the app.

---

## Multiple Confirmation Checks Are Acceptable

For important remote transitions, it is acceptable to confirm authoritative truth more than once if the architecture already does so.

That is not redundancy for its own sake.
It is often deliberate protection against:
- stale intermediate state
- race conditions
- old instance reactions
- async timing problems

So if a transition currently does:
- local visible status check
- flow-backed authoritative check
- final authoritative confirmation

do not automatically “simplify” that away.

It may be there because one check was not enough in practice.

---

## Match Identity Must Still Match

Authoritative state is not enough on its own.

The truth must still belong to the screen/request that is about to navigate.

That means checking:
- match id still matches expected match
- flow ownership still belongs to this match
- nav-in-flight token still belongs to this request
- current view instance still represents the same route context

Without identity matching, even true authoritative state can still cause the wrong navigation.

---

## Good Examples

### Good: lobby to gameplay
- realtime or fetch suggests progress
- authoritative match is refetched
- authoritative state confirms `in_progress`
- match identity still matches current lobby
- guards pass
- gameplay push happens once

### Good: replay overlay dismissal
- replay update arrives
- authoritative arrays reload
- replay is missing or cancelled in authoritative source
- overlay is still active
- dismissal occurs

### Good: remote lobby entry after async join
- async join completes
- nav-in-flight token still matches
- authoritative match still supports lobby entry
- router push is requested

---

## Bad Examples

### Bad: gameplay push from local status only
- local match says `in_progress`
- no authoritative refetch
- push gameplay immediately

### Bad: replay push from payload
- payload says ready
- replay lobby pushed without authoritative reload

### Bad: dismiss from cached overlay object
- overlay still holds old replay model
- no array reload happened
- overlay dismisses based on assumption

### Bad: old async completion pushes lobby
- accept/join started earlier
- user context changed
- old completion still pushes because truth was not re-checked against current request

---

## How To Decide What Must Be True

For any transition, write the answer in this form:

**Before `<transition>`, authoritative state must confirm `<facts>`.**

Examples:

- Before **lobby → gameplay**, authoritative state must confirm the match is `in_progress`.
- Before **replay → lobby**, authoritative state must confirm replay is in a navigable ready/joinable state.
- Before **overlay dismissal**, authoritative state must confirm replay was removed, cancelled, or otherwise no longer belongs on screen.
- Before **remote lobby entry**, authoritative state must confirm the match is still valid for entry and still belongs to the current request.

This is the easiest way to reason clearly.

---

## Good Pattern

The intended pattern is:

1. event or action happens
2. choose correct authoritative source
3. refetch or revalidate that source
4. check identity and guards
5. navigate if and only if truth still supports the route

This applies to:
- pushes
- pops
- dismissals
- replay entry
- gameplay entry
- terminal transitions

---

## Bad Pattern

The main bad pattern is:

1. something changed locally
2. code assumes navigation is now correct
3. route changes immediately
4. authoritative state is checked later, or never

That is exactly the class of bug this doc is trying to prevent.

---

## Questions To Ask Before Editing

Before changing remote navigation code, ask:

1. what is the exact transition?
2. what authoritative source owns that truth?
3. what exact facts must be true?
4. are we currently checking those facts, or assuming them?
5. are we checking them late enough in the flow to still trust them?
6. does the truth still belong to this screen/request?

If those answers are vague, the change is not ready.

---

## Relationship to Guards

This document and `remote-navigation-guards.md` are both required.

They are not alternatives.

- **authoritative checks** answer: **what must be true before this transition is allowed**
- **guards** answer: **whether this specific request, screen instance, and timing are still valid right now**

Examples:
- authoritative check: is the match really `in_progress`?
- guard check: is this still the active lobby instance allowed to push gameplay?
- authoritative check: is the replay really ready/joinable?
- guard check: does this async completion still belong to the current nav request?
- authoritative check: was the replay really removed or cancelled?
- guard check: is the overlay still active and owned by the current flow?

You need both.

A transition can fail if:
- the truth is wrong
- the request is stale
- the screen instance is stale
- another instance already owns the transition
- the nav request no longer belongs to the current flow

So the correct pattern is:

**authoritative truth + valid current request + router execution**

not just one of those.

---

## When To Use Other Docs

Use this doc when deciding:
- what truth is required before navigation

Then use:
- `router-architecture.md` for route execution model
- `one-navigation-owner.md` for transition ownership
- `remote-navigation-guards.md` for remote guard stack
- `lifecycle-and-instance-guards.md` for stale instance protection
- `replay-navigation-rules.md` for replay-specific route conditions
- `navigation-debug-order.md` for diagnosis sequence

This doc explains **what must be true before navigation is allowed**.  
The others explain how the rest of the system supports that.

---

## Bottom Line

In remote flow, navigation is never justified by vibes.

It is justified only when the authoritative state for that transition is confirmed.