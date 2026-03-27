> Supporting reference for: swiftui-navigation  
> Apply when: deciding which part of the app is allowed to trigger a specific push/pop/dismiss, especially in remote flows, replay flows, or any bug where navigation fires twice or from more than one place  
> Do not apply to: general router architecture, local layout work, or non-navigation state handling

# One Navigation Owner

## Purpose

This document defines one of the most important navigation rules in Dart Freak:

**for any specific transition, there must be one clear owner.**

This exists to prevent a very common class of navigation bugs:
- duplicate pushes
- double dismissal
- racing transitions
- stale instances navigating after the correct screen already acted
- realtime, `onAppear`, and `onChange` all trying to move the user at once

The router is the single navigation writer.  
This doc is about something different:

**who is allowed to decide that a transition should happen.**

---

## Core Rule

For any specific transition:

- one feature/view owns the transition decision
- router performs the route execution
- all other observers may support the decision, but must not become competing owners

Put simply:

**one owner decides, router executes**

---

## What “Owner” Means

A navigation owner is the part of the app that is allowed to say:

- “push this route now”
- “dismiss this overlay now”
- “pop now”
- “transition from lobby to gameplay now”

Ownership is about **decision authority**, not stack mutation.

That means:
- router owns execution
- owner owns decision
- other code may observe the same state change, but must not also navigate

---

## Why This Rule Exists

In SwiftUI apps, many things can observe the same transition:

- button tap handlers
- `onAppear`
- `onChange`
- async task completion
- realtime subscription reactions
- overlay state changes
- parent views
- child views
- service-layer callbacks

If more than one of those becomes a navigation owner, the app becomes fragile.

Typical symptoms:
- same screen pushed twice
- overlay dismisses and route pushes at the same time
- stale view instance navigates after a newer one already did
- one screen navigates while another still thinks it owns the flow
- replay transitions act from two different places

This rule exists to stop that.

---

## Router Is Not the Owner of Every Transition

Important distinction:

- router is the single navigation writer
- router is **not** automatically the semantic owner of every transition

For example:
- `RemoteGamesTab` may own the decision to push remote lobby
- `RemoteLobbyView` may own the decision to push remote gameplay
- an end-game replay flow may own the decision to push replay lobby or dismiss replay UI

Router still performs the actual push/pop.  
But router should not replace feature ownership.

---

## Good Ownership Model

A good transition looks like this:

1. one feature/view detects the transition should happen
2. that feature validates guards and authoritative state
3. that feature requests navigation through router
4. router executes the route change
5. all other observers stand down

This is the intended pattern.

---

## Bad Ownership Model

A bad transition looks like this:

1. realtime arrives
2. `onChange` notices status change
3. parent view also notices
4. child view is still alive and also notices
5. async task completion also fires
6. multiple places request the same push/dismiss

Even if duplicate-push protection catches some of it, the architecture is still wrong.

---

## Ownership in Dart Freak

The app already follows this pattern in important places.

Examples from your architecture:

- `RemoteGamesTab` is the owner of lobby-entry requests
- `RemoteLobbyView` is the owner of gameplay push requests
- router is the only executor of pushes/pops
- duplicate push protection exists as a safeguard, not as the primary owner model
- remote guards exist so stale or duplicate owners do not act

This is exactly the kind of pattern this rule should preserve.

---

## One Transition, One Owner

This is the practical version of the rule:

For any single transition, be able to answer:

- who owns it?
- what authoritative truth do they require?
- what guards must pass?
- what other observers are deliberately **not** owners?

If that is unclear, the transition is at risk of duplication.

---

## Good Examples

### Good: remote games tab owns lobby push
- user accepts/joins
- `RemoteGamesTab` validates processing/nav-in-flight state
- `RemoteGamesTab` requests `.remoteLobby(...)`
- router performs push
- other screens do not also push lobby

### Good: remote lobby owns gameplay push
- authoritative match becomes `in_progress`
- `RemoteLobbyView` validates active instance + guards
- `RemoteLobbyView` requests `.remoteGameplay(...)`
- router performs push once
- realtime and parents do not also push gameplay

### Good: replay overlay has one dismissal owner
- replay authoritative state changes
- one replay flow owner decides whether overlay should dismiss
- router/overlay system executes that dismissal
- other observers do not also dismiss

---

## Bad Examples

### Bad: realtime as owner
- realtime event arrives
- realtime handler pushes gameplay directly

Why bad:
- realtime should wake the app up, not own route transitions

### Bad: parent and child both own push
- parent observes state and pushes
- child `onChange` observes same state and pushes too

Why bad:
- duplicate ownership

### Bad: async completion plus view observer
- button tap launches async work
- completion handler pushes
- `onChange` on the same state also pushes

Why bad:
- same transition has two owners

### Bad: stale instance still owns transition
- old `RemoteLobbyView` is still alive
- new authoritative state arrives
- old instance still requests gameplay push

Why bad:
- ownership must belong to the current valid instance only

---

## Realtime Is Not a Navigation Owner

Realtime deserves its own explicit rule here.

Realtime may:
- trigger refetch
- wake a screen up
- cause an owner to re-evaluate navigation eligibility

Realtime must not:
- directly own the push
- directly own the dismiss
- become a second owner alongside the feature view

This is one of the most important anti-bug rules in remote flow.

---

## `onAppear` Is Not Automatically an Owner

`onAppear` is an especially dangerous place for ownership bugs.

Why:
- it may fire more than once
- stale instances may still get it
- it often overlaps with async state restoration
- it is tempting to put “if condition then navigate” inside it

Use `onAppear` carefully.

It may help an owner evaluate state.  
It must not casually become a second owner of a transition that already belongs elsewhere.

---

## `onChange` Is Not Automatically an Owner

Same warning for `onChange`.

`onChange` often sees important lifecycle changes:
- status became `in_progress`
- replay became ready
- overlay state changed
- authoritative match updated

But the presence of `onChange` does not mean the view should own navigation.

Before using it for navigation, confirm:
- this view is the designated owner
- no other view/observer owns the same transition
- stale-instance guards exist
- duplicate push guards remain intact

---

## Ownership vs Observation

A useful distinction:

### Observer
Can notice something changed.

### Owner
Can decide the route transition should happen.

Many bugs happen when observers accidentally become owners.

For example:
- parent sees a status change → observer
- child sees same status change → observer
- only one should be owner

If all observers can navigate, the architecture is unstable.

---

## Ownership and Guards Work Together

Ownership alone is not enough.

Even the correct owner must still validate:
- authoritative state
- match identity
- active instance validity
- nav-in-flight conditions
- duplicate-start latches
- terminal/unwind state if relevant

So the right pattern is:

**one owner + correct guards + router execution**

not just “one owner”

---

## Replay Ownership Rule

Replay needs special care because it can easily create multiple owners:

- replay overlay logic
- replay card logic
- end-game continuation flow
- realtime replay updates
- lobby-entry logic

For replay transitions, explicitly decide:
- who owns replay dismissal
- who owns replay lobby push
- who is only observing replay state

Do not let replay flow split ownership across multiple layers.

---

## Remote Flow Ownership Rule

Remote transitions must be especially strict.

Examples:
- remote games tab owns lobby entry request
- remote lobby owns gameplay push
- gameplay/end-game should have their own clear transition owners

Do not let:
- remote service callbacks
- realtime handlers
- parent tab containers
- stale child screens

all compete to move the user through remote flow.

Remote flow is where ownership bugs become expensive.

---

## How To Check Ownership Before Editing

Before changing navigation code, answer these questions:

1. what exact transition am I changing?
2. who currently owns that transition?
3. am I adding a second owner by accident?
4. could `onAppear`, `onChange`, realtime, or async callbacks also act here?
5. should this code observe, or actually own?
6. if this is the owner, what guards must remain?

If you cannot answer that, stop and map ownership first.

---

## Good Patterns

### Pattern: single feature owner
- one feature view decides
- router executes
- others only observe

### Pattern: owner re-evaluates after refetch
- realtime arrives
- owner gets authoritative update
- owner decides navigation is now valid
- router executes

### Pattern: guarded owner
- correct owner sees state
- stale-instance guard passes
- duplicate push guard passes
- authoritative status passes
- router executes once

---

## Bad Patterns

### Pattern: distributed ownership
- multiple places can push the same route
- whoever fires first wins
- router duplicate protection hides the mistake sometimes

### Pattern: observer drift
- a helper observer starts “just handling one edge case”
- now it also pushes/dismisses
- ownership is split

### Pattern: ownership by convenience
- developer adds navigation to the nearest `onChange`
- existing owner still exists elsewhere
- bug appears later under race conditions

---

## When To Use Other Docs

Use this doc to decide **who owns** a transition.

Then use:
- `router-architecture.md` for how execution works
- `remote-navigation-guards.md` for remote guard stack
- `authoritative-navigation-checks.md` for truth requirements
- `lifecycle-and-instance-guards.md` for stale instance protection
- `replay-navigation-rules.md` for replay-specific transition ownership

This doc answers **who decides**.  
Those docs answer **how they decide safely**.

---

## Bottom Line

In Dart Freak, not everyone who sees a transition gets to own it.

One owner decides.  
Router executes.  
Everyone else observes.