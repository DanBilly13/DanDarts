> Supporting reference for: swiftui-navigation  
> Apply when: working on Router.swift, MainTabView navigation wiring, Destination/Route structure, push/pop/popToRoot behavior, or any navigation change that needs to respect Dart Freak's centralized router architecture  
> Do not apply to: local view layout, non-navigation state changes, or remote state handling that does not involve route changes

# Router Architecture

## Purpose

This document explains the actual navigation architecture used in Dart Freak.

It exists to prevent a common AI mistake:

trying to solve navigation problems with generic SwiftUI patterns instead of using the app’s existing router system.

In this app, navigation is centralized.  
That is not optional architecture.  
It is part of how correctness is maintained.

---

## Core Rule

`Router.shared` is the only navigation writer.

Views may request navigation through the router.  
Views must not directly own `NavigationStack` path mutation.

This is the foundation of the app’s navigation model.

---

## High-Level Architecture

Dart Freak uses:

- a centralized `Router.shared`
- a single `NavigationStack`
- a typed `Destination` enum
- a `Route` wrapper for stack path entries
- router closures wired in `MainTabView`
- feature views that request navigation through the router

This gives the app:
- one execution path for navigation
- type-safe destinations
- centralized logging
- duplicate-push protection
- a consistent place to add guards and policy

---

## Main Structural Pieces

### 1. `Router.shared`
The router is a singleton and the single source of truth for navigation requests.

It is `@MainActor`, which matters because navigation is UI work and should stay serialized on the main thread.

The router exposes:
- `push(...)`
- `pop(...)`
- `popToRoot(...)`

These functions are the app’s official navigation interface.

---

### 2. `MainTabView` owns the `NavigationStack`
The actual SwiftUI `NavigationStack` path lives in `MainTabView`.

That means:
- the stack itself is not mutated in random feature files
- path ownership is centralized
- the router is wired to one root stack

This is important:

**router owns requests, MainTabView owns stack state.**

---

### 3. Router closures bridge requests to path mutation
The router does not store the `NavigationPath` directly.

Instead, `MainTabView` wires closures like:
- `pushClosure`
- `popClosure`
- `popToRootClosure`

Those closures perform the actual stack mutation.

This creates a clean separation:
- features call router methods
- MainTabView executes stack changes

---

### 4. `Destination` is the typed route model
Navigation targets are represented by a typed enum.

That means features navigate by requesting:
- `.gameSetup(...)`
- `.remoteLobby(...)`
- `.remoteGameplay(...)`
- `.gameEnd(...)`
- etc.

This is much safer than string routes or ad hoc push logic.

---

### 5. `Route` wraps `Destination` for stack use
The stack works with `Route`, which wraps a `Destination`.

That keeps stack entries hashable and consistent.

In practice, the app reasons about navigation in terms of `Destination`, while the stack stores `Route`.

---

### 6. Destination building happens centrally
`MainTabView` uses a destination builder to map routes to actual views.

That means:
- route construction is centralized
- environment wiring is centralized
- shared navigation modifiers can be applied consistently
- feature views do not manually recreate destination-routing logic everywhere

This is part of why navigation stays coherent.

---

## Why This Architecture Exists

This architecture solves real problems:

### 1. Single execution path
All pushes and pops go through one system.

### 2. Easier debugging
When navigation breaks, there is one central model to inspect.

### 3. Duplicate push protection
The router can prevent duplicate pushes globally.

### 4. Shared policy
Guards, logging, analytics, and future deep-link rules can all be centralized.

### 5. Consistency across local and remote flows
Both normal game flow and remote flow use the same router architecture.

---

## One Navigation Writer Rule

This is the most important consequence of the architecture.

Only the router should perform route execution.

Do not:
- mutate `navigationPath` directly from feature code
- create local stack mutation helpers in random views
- bypass the router because a direct push “seems simpler”
- create second navigation writers in child views

If a feature needs navigation, it should request it through router methods.

---

## What Views Are Allowed To Do

Views may:
- decide whether a transition should be requested
- call `router.push(...)`
- call `router.pop(...)`
- call `router.popToRoot(...)`

Views may not:
- become their own navigation system
- directly mutate the root stack path
- recreate stack ownership locally
- bypass centralized route typing

So the view may own the **decision**, but not the **mechanism**.

---

## Router vs Feature Responsibilities

The clean split is:

### Router responsibility
- perform push/pop/popToRoot
- centralize navigation execution
- log navigation actions
- provide duplicate-push protection
- stay the single writer

### Feature responsibility
- determine whether navigation should be requested
- validate authoritative state if needed
- apply local feature guards/latches before requesting a route

This distinction matters a lot in remote flow.

---

## Remote Flow Does Not Replace Router

Remote navigation has extra guards, but it still uses the same router architecture.

That means:
- remote feature code may decide when lobby/gameplay transition is allowed
- but the actual push still goes through router
- remote navigation guards layer on top of router, not around it

Do not create a separate remote navigation mechanism.

Remote flow is a guarded caller of router navigation, not a replacement for it.

---

## MainTabView as Navigation Root

Because `MainTabView` owns the root `NavigationStack`, it also becomes the place where:
- path depth is known
- route rendering is centralized
- environment objects for destinations can be injected
- app-wide navigation behavior stays coherent across tabs

This is especially important because the app has multiple tabs but one consistent route system.

So even when a feature is inside a specific tab, it is still participating in the same central navigation architecture.

---

## Duplicate Push Protection

The router includes duplicate-push protection.

This is important because in a real app, multiple triggers can try to request the same route within a short interval:
- `onAppear`
- `onChange`
- realtime reactions
- async completions
- repeated button taps

The router helps absorb some of that risk by dropping very recent duplicate pushes.

This is protection, not permission.

Feature code must still avoid creating duplicate push requests.
The router just provides a last line of defense.

---

## Navigation Logging

The router logs navigation actions and flushed path changes.

This is valuable because:
- pushes can be traced to their call sites
- path depth changes are visible
- duplicate or unexpected route requests are easier to spot

When adding navigation code, preserve centralized router logging.
Do not move important route execution into places where that visibility is lost.

---

## View Factory Pattern

The destination builder in `MainTabView` acts like a centralized view factory.

That means:
- route → view mapping stays in one place
- view construction stays predictable
- navigation modifiers stay consistent
- environment setup stays standardized

This is especially useful in a large app with:
- local game flow
- remote game flow
- replay flow
- end game flow

Without this, navigation code would drift and duplicate.

---

## Good Patterns

### Good: feature requests a route
- feature validates local conditions
- feature calls `router.push(...)`
- router performs navigation

### Good: remote feature uses router after guards
- remote lobby validates authoritative transition
- remote lobby calls `router.push(.remoteGameplay(...))`
- router performs push once

### Good: root builder owns destination construction
- route is requested centrally
- MainTabView resolves route into the correct view

---

## Bad Patterns

### Bad: direct path mutation from feature code
- feature reaches into `NavigationPath`
- feature appends/removes routes itself

This breaks the single-writer model.

### Bad: second navigation system
- feature creates local custom stack mutation logic
- router is bypassed for “special cases”

This makes the app harder to reason about and debug.

### Bad: destination building scattered across features
- route construction logic duplicated in many places
- environment injection becomes inconsistent

This weakens architecture coherence.

### Bad: relying on router duplicate protection as the main strategy
- feature emits repeated push requests
- router drops some of them
- bug remains hidden but architecture is still wrong

Router duplicate protection is a safeguard, not the primary design.

---

## What To Preserve When Editing

When changing navigation architecture, preserve:

- `Router.shared` as the single navigation writer
- `MainTabView` as the `NavigationStack` owner
- closure wiring from router to root stack
- typed `Destination`
- `Route`-based stack entries
- centralized destination building
- duplicate-push protection
- router logging

Do not casually “simplify” these patterns away.

---

## When To Read Other Docs

Use this doc for the base architecture.

Then use:
- `one-navigation-owner.md` for transition ownership
- `remote-navigation-guards.md` for feature-level remote guards
- `authoritative-navigation-checks.md` for remote truth before pushing
- `lifecycle-and-instance-guards.md` for stale view protection
- `replay-navigation-rules.md` for replay-specific transitions

This doc explains the structure.  
Those docs explain how to use the structure safely.

---

## Bottom Line

In Dart Freak, navigation is centralized on purpose.

`MainTabView` owns the stack.  
`Router.shared` owns route execution.  
Features may request navigation, but they do not get to invent their own navigation system.