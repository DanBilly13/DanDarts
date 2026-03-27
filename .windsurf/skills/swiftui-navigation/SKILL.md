---
name: swiftui-navigation
description: app-specific navigation rules for dart freak. use when working on router-based navigation, navigationstack flows, route pushes or pops, remote flow transitions, replay navigation, end game transitions, stale view instance bugs, duplicate push bugs, navInFlight guards, gameplay push timing, onAppear navigation, onChange push, or any task where navigation happens twice, too early, too late, or from the wrong screen. do not use for local view layout work or non-navigation state changes.
---

# SwiftUI Navigation

Use this skill when changing or debugging **navigation behavior** in Dart Freak.

This is not a general SwiftUI navigation guide.  
It describes the navigation architecture and guard rules used in this app.

## Scope

Apply this skill when working on:
- router-based pushes / pops / popToRoot
- `NavigationStack` behavior
- route transitions between app screens
- remote lobby / gameplay / replay / end game navigation
- duplicate push bugs
- stale view instance navigation bugs
- navigation timing bugs
- authoritative checks before navigation
- guard and latch logic around remote transitions

Do not use this skill for:
- local layout/styling work
- generic SwiftUI state updates that do not affect navigation
- non-navigation remote state handling unless it directly controls a route change

## Core Architecture

Dart Freak uses a **centralized router architecture**.

Key rules:
- `Router.shared` is the single source of truth for navigation actions
- `MainTabView` owns the `NavigationStack` path
- screens request navigation through the router
- screens do **not** manipulate `NavigationStack` path directly
- route changes should stay type-safe through `Destination`

## Core Rules

### 1. Router is the only navigation writer
All push/pop/popToRoot actions must go through `Router.shared`.

Do not:
- mutate `NavigationPath` directly from feature views
- create competing navigation writers
- bypass router patterns because a local push seems easier

### 2. One transition, one owner
For any specific transition, one feature/view should own the decision to navigate.

Examples:
- remote games tab owns lobby entry requests
- remote lobby owns gameplay push
- replay overlay flow should have one clear owner for lobby entry or dismissal

Do not let:
- realtime
- `onAppear`
- `onChange`
- parent views
- child views
- async callbacks

all compete to trigger the same navigation.

### 3. Navigation follows authoritative truth
For remote flows, navigation must follow authoritative state.

Examples:
- lobby → gameplay only after authoritative `in_progress`
- replay → lobby only after authoritative ready/joinable state
- dismissal only after authoritative removal/cancel/terminal confirmation when required

Do not navigate from hope, local assumptions, or raw realtime payloads.

### 4. Stale instances must never navigate
SwiftUI can keep old view instances alive longer than expected.

Any navigation triggered from:
- `onAppear`
- `onChange`
- async `Task`
- delayed callbacks
- realtime reactions

must be protected so stale screen instances cannot push or dismiss.

### 5. Preserve existing guard architecture
When editing remote navigation, preserve:
- `processingMatchId`
- `navInFlightMatchId`
- `matchesBeingStarted`
- `isViewActive`
- remote flow depth / `flowMatchId`
- authoritative status checks
- duplicate-push prevention in router

Do not simplify these away casually.

## Navigation Model in Dart Freak

The current architecture is:

- `Router.shared` owns app navigation requests
- `MainTabView` wires router closures into a single `NavigationStack`
- `Destination` defines typed routes
- `Route` wraps destinations for stack use
- remote flows add feature-level guards on top of router navigation
- router also provides centralized logging and duplicate-push protection

This means:
- router owns **how** navigation is performed
- feature screens own **whether** a transition should be requested
- remote guards decide **whether the request is still valid**

## Remote Navigation Rules

Remote navigation is high-risk and must be guarded.

Important app-specific rules:
- lobby push originates from the remote games flow, not arbitrary child views
- gameplay push originates from remote lobby, not from realtime payload alone
- replay navigation must stay single-owner
- remote transitions must verify authoritative state before pushing
- stale instances must be blocked with active-instance guards
- duplicate pushes must be blocked at both router and feature level when needed

## Gameplay Push Safety

Gameplay push is especially sensitive.

Before requesting gameplay navigation, preserve the existing structure:
- view instance must still be active
- match identity must still be correct
- authoritative match status must confirm `in_progress`
- duplicate gameplay push guards must still hold
- any global/static latch for “already starting” must remain respected

Do not weaken these checks because “the status already changed once.”

## Replay Navigation Safety

Replay navigation is a special case.

Replay flows may combine:
- overlay state
- router navigation
- active remote flow
- authoritative replay status
- dismissal and re-entry behavior

Be careful not to create:
- second navigation owners
- overlay dismissal plus route push races
- payload-driven replay navigation
- stale overlay instance navigation

## What This Skill Prevents

This skill is mainly here to stop these mistakes:

- direct `NavigationStack` mutation from feature code
- multiple places pushing the same route
- navigation from realtime payload alone
- stale `RemoteLobbyView` / `RemoteGameplayView` instances pushing
- removal of latches/guards because they “look redundant”
- replay navigation being treated like ordinary local navigation
- route changes based on local UI state instead of authoritative remote state

## Standard Decision Order

When changing navigation code, reason in this order:

1. who owns this transition
2. what authoritative state must be true first
3. what guards/latches must still pass
4. is the current view instance still active and valid
5. is router the only place that will perform the actual push/pop
6. could another observer/path also trigger the same transition

If you cannot answer these clearly, do not change the navigation yet.

## Use Supporting References

Consult supporting docs as needed:

- `router-architecture.md` for how router wiring works
- `one-navigation-owner.md` for transition ownership rules
- `remote-navigation-guards.md` for remote guard stack and duplicate prevention
- `authoritative-navigation-checks.md` for what must be true before route changes
- `lifecycle-and-instance-guards.md` for stale instance protection
- `replay-navigation-rules.md` for replay-specific route behavior
- `navigation-debug-order.md` for debugging sequence
- `navigation-anti-patterns.md` for what not to do

## Bottom Line

In Dart Freak, navigation is not just a view concern.

The router owns route execution.  
One feature owns each transition decision.  
Remote navigation only happens after guards and authoritative truth agree.