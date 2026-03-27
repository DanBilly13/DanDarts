> Supporting reference for: swiftui-navigation  
> Apply when: editing remote lobby/gameplay/replay navigation, preserving duplicate-push protection, working with navInFlight or processing guards, or debugging stale-instance and multi-trigger remote navigation bugs  
> Do not apply to: generic router structure, local-only game navigation, or remote state changes that do not lead to route transitions

# Remote Navigation Guards

## Purpose

This document captures the guard stack that protects remote navigation in Dart Freak.

Remote navigation is not protected by one check.  
It is protected by **multiple layers working together**.

This exists to prevent:
- double taps creating duplicate flow entry
- stale views navigating after they should be inactive
- multiple instances requesting gameplay push
- async race conditions during lobby entry
- gameplay push firing more than once
- remote flow navigation happening from the wrong match context

Do not simplify this guard stack casually.

---

## Core Rule

For remote transitions, navigation is allowed only when:

- the correct feature owns the transition
- the correct guard stack passes
- the current view instance is still valid
- authoritative state supports the transition
- router is still the only executor

In practice:

**remote navigation = owner + guards + authoritative truth + router**

---

## Why Remote Navigation Needs Extra Guards

Remote flow is riskier than ordinary local navigation because it combines:
- async edge function calls
- realtime updates
- view lifecycle churn
- reused screens
- stale instances
- replay edge cases
- multiple observers of the same match state

That means router-level duplicate-push protection is not enough by itself.

Remote flow needs feature-level guards on top of router.

---

## Guard Layers in Dart Freak

The current remote architecture uses multiple guard categories:

- transition ownership guards
- processing guards
- nav-in-flight guards
- stale-instance guards
- cross-instance duplicate guards
- authoritative status guards
- remote flow identity guards
- cancellation / invalid-match guards

These layers are complementary.  
They are not interchangeable.

---

## Transition Owners

Current transition ownership is:

### Lobby push owner
- `RemoteGamesTab`

This is the owner for:
- accept challenge → lobby
- join ready match → lobby

### Gameplay push owner
- `RemoteLobbyView`

This is the owner for:
- lobby → gameplay once authoritative state confirms `in_progress`

This matters because each owner has its own correct guard stack.

Do not move these transitions casually to some other observer without rebuilding the safety model.

---

## Processing Guard

The processing guard prevents duplicate user-driven flow requests.

Primary example:
- `processingMatchId`

Use:
- block repeated accept/join taps
- block concurrent attempts for the same match
- stop duplicate async entry work before router push

### What it protects against
- rapid double-taps
- repeated button presses during async work
- overlapping entry requests from the same screen

### What not to do
Do not remove processing guards just because duplicate-push protection already exists in router.

They solve different problems:
- processing guard stops duplicate **requests**
- router duplicate protection stops duplicate **executions**

You usually want both.

---

## Nav-In-Flight Guard

The nav-in-flight guard protects async entry flow from stale completion.

Primary example:
- `navInFlightMatchId`

Pattern:
1. feature sets nav-in-flight token for the expected match
2. async work runs
3. before pushing, code re-checks that nav-in-flight token still matches
4. only then is the route request allowed

### What it protects against
- async accept/join finishing after user context changed
- earlier request completing after a newer request took over
- stale entry completion pushing the wrong lobby

### Good usage
- set before async flow begins
- revalidate immediately before push
- clear/change when ownership changes

### Bad usage
- set once, never rechecked
- used only for logging
- bypassed on “simple” paths

If `navInFlightMatchId` changed, the push must not happen.

---

## Cancelled / Invalid Match Guard

Remote entry must also be blocked if the match is no longer valid for navigation.

Examples:
- match was cancelled
- match was removed from current actionable state
- local guard cache knows the entry is obsolete

Primary example:
- `cancelledMatchIds`

### What it protects against
- pushing lobby for a match already cancelled
- stale async completion entering a now-invalid match
- UI actions executing against dead remote state

This guard matters especially in list-driven remote flows.

---

## Cross-Instance Duplicate Guard

Gameplay push needs stronger protection because multiple `RemoteLobbyView` instances can observe the same transition.

Primary example:
- static/shared `matchesBeingStarted`
- protected by a lock

Pattern:
1. a view instance tries to start gameplay transition
2. shared atomic set is checked
3. if match already exists in the set, this instance must stand down
4. if not, this instance acquires the right to continue

### What it protects against
- duplicate gameplay pushes across multiple live lobby instances
- repeated `onChange` / state reactions from multiple observers
- race conditions between old and new instances

This is one of the most important remote navigation guards in the whole app.

Do not weaken it because it “looks redundant.”

It is specifically solving a cross-instance problem that router-level duplicate filtering cannot fully solve.

---

## Stale View Instance Guard

A view instance must never navigate if it is no longer active.

Primary example:
- `isViewActive`

Pattern:
- set active on `onAppear`
- set inactive on `onDisappear`
- cancel navigation-related tasks on disappearance where appropriate
- guard all navigation triggers with active-instance check

### What it protects against
- old `RemoteLobbyView` pushing gameplay after a new one took over
- delayed async callbacks navigating from dead screens
- repeated lifecycle events causing obsolete pushes

### Important
This is not optional “extra caution.”
SwiftUI can keep view instances alive long enough for this to matter.

If a view is stale, it must not navigate.

---

## Authoritative Status Guards

Remote navigation must be backed by authoritative truth.

For gameplay push, multiple authoritative checks are intentionally used.

Typical requirement:
- local/visible match state says `in_progress`
- freshly fetched or flow-backed authoritative match also says `in_progress`
- final confirmation still says `in_progress`

### What it protects against
- premature gameplay push
- local state drifting ahead of authoritative state
- race conditions where one update said progress but current truth no longer does

Do not reduce remote gameplay navigation to:
- “one status changed once, so push now”

Remote transitions should stay authoritative.

---

## Remote Flow Identity Guards

The app also tracks which remote flow currently owns the user.

Examples:
- `flowMatchId`
- remote flow depth
- `isInRemoteFlow`

These are not always the direct trigger guard, but they provide important context:
- which match owns the active flow
- whether a reload or navigation request belongs to the current match
- whether an old instance is trying to act from the wrong flow

### What they protect against
- wrong-match navigation
- stale flow ownership
- transitions continuing after flow ownership changed

This is especially important when replay or rapid transitions are involved.

---

## Lobby Push Guard Stack

For lobby entry from `RemoteGamesTab`, the current safety model is roughly:

1. transition owner is correct (`RemoteGamesTab`)
2. not already processing (`processingMatchId`)
3. match still valid for lobby entry
4. nav-in-flight token set and preserved
5. cancelled/invalid guards pass
6. status still supports lobby entry
7. router push requested once

### What this stack is trying to prevent
- double-tap accept/join
- async completion from obsolete request
- pushing lobby for a dead match
- racing multiple lobby-entry requests

---

## Gameplay Push Guard Stack

For gameplay entry from `RemoteLobbyView`, the current safety model is roughly:

1. transition owner is correct (`RemoteLobbyView`)
2. this view instance is still active (`isViewActive`)
3. cross-instance atomic guard passes (`matchesBeingStarted`)
4. authoritative `in_progress` checks pass
5. flow match identity still matches expected match
6. router push requested once

### What this stack is trying to prevent
- stale lobby instance push
- duplicate gameplay push from multiple instances
- gameplay navigation before authoritative truth is stable
- push from wrong-match context

---

## Router Duplicate Protection Is Not Enough

The router already drops very recent duplicate pushes.

That is useful, but it is not the whole safety model.

Why not:
- router only sees executed push attempts
- it does not know remote flow ownership
- it does not know stale-instance validity
- it does not know whether a match was cancelled
- it does not know which async completion is obsolete

So keep this hierarchy clear:

- feature guards prevent bad requests
- router protects final route execution

Do not rely on router duplicate filtering as your only defense.

---

## Good Patterns

### Good: guarded accept → lobby
- user taps once
- processing guard passes
- nav-in-flight token established
- async entry finishes
- token still valid
- match still actionable
- router pushes lobby once

### Good: guarded lobby → gameplay
- authoritative state becomes `in_progress`
- active lobby instance sees it
- cross-instance gameplay guard passes
- view is still active
- authoritative checks confirm transition
- router pushes gameplay once

### Good: stale instance stands down
- old instance receives state change
- `isViewActive == false`
- it logs and does nothing
- correct active instance remains owner

---

## Bad Patterns

### Bad: remove processing guard
- rely on button disabled state only
- async duplicate requests now possible

### Bad: remove nav-in-flight recheck
- old async request completes
- wrong lobby gets pushed

### Bad: remove cross-instance gameplay guard
- multiple lobby instances observe `in_progress`
- duplicate gameplay push race returns

### Bad: remove active-instance check
- stale screen still navigates after disappearance

### Bad: use only one weak status check
- local state briefly says `in_progress`
- gameplay push happens before authoritative confirmation stabilizes

---

## Preserve Existing Guard Intent

When editing remote navigation, preserve the intent of each guard:

- `processingMatchId` → no duplicate user flow start
- `navInFlightMatchId` → async completion must still belong to current request
- `cancelledMatchIds` → dead matches must not navigate
- `matchesBeingStarted` → only one instance may own gameplay push
- `isViewActive` → stale views must not act
- authoritative status checks → remote transition must be real
- `flowMatchId` / flow depth → flow identity must still match

Even if names change, these protections must still exist.

---

## How To Evaluate a Proposed Change

Before changing remote navigation code, ask:

1. which exact transition is this?
2. who owns it now?
3. which guards currently protect it?
4. which of those guards are request-level vs instance-level vs truth-level?
5. if I remove or move this code, what class of bug comes back?
6. am I preserving both owner and guard structure?

If you cannot answer those, do not refactor blindly.

---

## Debugging Guard Failures

When a remote transition fails or duplicates, debug in this order:

1. who owned the transition
2. did processing guard pass
3. did nav-in-flight token still match
4. was the view instance still active
5. did cross-instance duplicate guard block another actor
6. did authoritative state really support the transition
7. did router receive one request or many

This usually reveals the real weak layer.

---

## When To Use Other Docs

Use this doc for the guard stack itself.

Then use:
- `router-architecture.md` for core execution model
- `one-navigation-owner.md` for ownership
- `authoritative-navigation-checks.md` for truth requirements
- `lifecycle-and-instance-guards.md` for view-instance safety details
- `replay-navigation-rules.md` for replay-specific navigation behavior
- `navigation-debug-order.md` for full diagnosis sequence

This doc explains **what blocks unsafe remote navigation**.  
The others explain the rest of the navigation system around it.

---

## Bottom Line

Remote navigation in Dart Freak is safe because multiple guards agree before router executes.

Do not collapse that into one check.  
Each guard is protecting a different class of bug.