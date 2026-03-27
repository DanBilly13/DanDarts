> Supporting reference for: swiftui-navigation  
> Apply when: working on navigation triggered from onAppear, onDisappear, onChange, async Tasks, delayed callbacks, or any remote flow where stale SwiftUI view instances could still react after they should be inactive  
> Do not apply to: generic router structure, non-navigation state changes, or local view lifecycle work that does not affect route transitions

# Lifecycle and Instance Guards

## Purpose

This document defines how Dart Freak protects navigation from stale SwiftUI view instances.

This is critical because SwiftUI lifecycle behavior can easily create navigation bugs if the app assumes:
- `onAppear` only fires once
- the latest visible view is the only instance still alive
- async work always completes while the originating view is still valid
- `onChange` only runs in the “current” screen instance

Those assumptions are unsafe.

This document exists to prevent:
- stale `RemoteLobbyView` instances pushing gameplay
- old async tasks navigating after the user already moved on
- multiple live instances reacting to the same state change
- duplicate transitions caused by repeated lifecycle events
- view-owned navigation happening after the view is no longer active

---

## Core Rule

A view instance may participate in navigation only while it is still the active, valid instance for that route context.

That means:
- lifecycle callbacks are not enough by themselves
- `onAppear` does not grant permanent authority
- `onChange` does not prove the instance is current
- delayed work must re-check instance validity before navigating

In short:

**if the instance may be stale, it must not navigate**

---

## Why This Rule Exists

SwiftUI can:
- recreate views
- keep old instances alive briefly
- trigger repeated `onAppear`
- trigger `onChange` from instances you do not expect
- allow async work to complete after the originating screen has already disappeared

That means lifecycle-driven navigation is dangerous unless guarded.

Without instance guards, the app can get:
- double gameplay pushes
- old lobby screens pushing after a new one took over
- replay flow navigating from the wrong overlay instance
- route changes from callbacks that no longer belong to the active screen

---

## Lifecycle Events Are Observation Points, Not Automatic Authority

Important mindset:

- `onAppear` is an observation point
- `onChange` is an observation point
- async completion is an observation point
- delayed callback is an observation point

None of these automatically means:
- “this instance should navigate now”

Before any of them leads to navigation, the instance must prove it is still the correct one.

---

## What Counts as Instance Validity

An instance is valid for navigation only if all of these are still true:

- the view is still active
- the view still represents the same match / route context
- the flow still belongs to that match
- the transition has not already been claimed elsewhere
- the authoritative state still supports the transition
- no newer screen/request has taken over ownership

This is stricter than “the callback still fired.”

---

## Primary Instance Guard Pattern

The main pattern is:

- give the view an instance identity
- track whether it is currently active
- set active on appear
- set inactive on disappear
- cancel navigation-related async work on disappear where appropriate
- guard every navigation trigger with active-instance checks

Typical ingredients:
- `instanceId`
- `isViewActive`
- task cancellation
- match-id revalidation
- owner/latch revalidation before push

This is already part of Dart Freak’s remote flow architecture and should be preserved.

---

## `isViewActive` Rule

`isViewActive` is one of the most important lifecycle guards in the app.

Use it to answer:

**is this view instance still allowed to act?**

Pattern:
- `onAppear` → set active
- `onDisappear` → set inactive
- all navigation triggers must guard on active state

### What it protects against
- stale lobby instance pushing gameplay
- old overlay instance dismissing or pushing after disappearance
- async callbacks from dead screens
- delayed callbacks firing after the view has gone away

### Important
If `isViewActive == false`, the view must not navigate.

That should be treated as a hard stop.

---

## `onAppear` Rule

`onAppear` is not guaranteed to mean:
- first appearance only
- unique appearance
- final surviving instance
- safe time to push without guard checks

Because of that:

### `onAppear` may
- initialize local active-state tracking
- start guarded async work
- request authoritative refresh
- mark this instance as active

### `onAppear` must not
- blindly push routes
- assume no other instance exists
- bypass stale-instance protection
- replace existing navigation owners

Bad pattern:
- `onAppear { if status == .inProgress { push gameplay } }`

Good pattern:
- `onAppear` marks active
- current owner reevaluates state
- active-instance check passes
- authoritative truth passes
- guarded navigation may then occur

---

## `onDisappear` Rule

`onDisappear` is where the instance should give up authority.

Typical responsibilities:
- mark instance inactive
- cancel navigation-related tasks
- stop delayed callbacks from later acting as if the screen were still live
- release view-scoped ownership where appropriate

### What it protects against
- outdated task completion
- delayed transition logic firing after route change
- old screen still competing with current screen

Important:
`onDisappear` is not just cleanup.
It is part of navigation safety.

---

## `onChange` Rule

`onChange` is useful, but dangerous.

It often sees exactly the kind of state that might lead to navigation:
- match status change
- replay readiness change
- overlay state change
- active match update

But `onChange` does not make the current view the correct owner automatically.

Before allowing navigation from `onChange`, confirm:
- this view is the designated owner
- `isViewActive == true`
- this match/route context is still the one being observed
- no other instance already claimed the transition
- authoritative state is still current

Bad pattern:
- `onChange(of: status) { if status == .inProgress { push } }`

Good pattern:
- `onChange` observes
- active-instance guard passes
- ownership guard passes
- authoritative checks pass
- router push occurs once

---

## Async Task Rule

Async work is one of the biggest stale-instance risks.

Examples:
- accept/join flow
- replay entry flow
- delayed authoritative checks
- timer-based delayed transitions
- post-refresh navigation logic

Any async work that may lead to navigation must revalidate before acting.

Check again at the end:
- is this instance still active?
- does this request still belong to the current match?
- did a newer request take over?
- does authoritative truth still support the route?

Do not assume that because a task started from a valid screen, it will complete in a valid screen context.

---

## Delayed Callback Rule

Delayed callbacks are even riskier than immediate async completion.

Examples:
- `DispatchQueue.main.asyncAfter(...)`
- delayed overlay dismissals
- delayed replay transitions
- staged transition sequences

Before a delayed callback navigates:
- re-check active instance
- re-check ownership
- re-check match identity
- re-check authoritative truth if the route depends on it

Bad pattern:
- set a 1-second delay
- callback pushes/dismisses no matter what happened in that second

Good pattern:
- delayed callback revalidates everything before acting

---

## Match Identity Guard

Even if an instance is still active, it must still belong to the correct match context.

That means checking things like:
- current match id still matches expected match id
- current flow match id still matches this screen
- nav request still belongs to the initiating match
- replay overlay still belongs to the replay being observed

Without this, a still-active instance can still navigate for the wrong match.

---

## Flow Identity Guard

In remote flow, instance validity also depends on flow ownership.

An instance should not navigate if:
- `flowMatchId` has changed to another match
- remote flow ownership moved elsewhere
- the view belongs to an old route context that is no longer current

This matters because remote flow can outlive or overlap view recreation in subtle ways.

So the question is not only:
- “is this view active?”

It is also:
- “is this view active for the correct current flow?”

---

## Cross-Instance Rule

More than one instance may be alive at once.

That means instance validity is not only local.

For high-risk transitions like gameplay push, you also need:
- cross-instance duplicate protection
- one instance claiming the transition
- all others standing down

This is why lifecycle guards and transition latches work together.

Lifecycle guards answer:
- **is this particular instance still allowed to act?**

Cross-instance guards answer:
- **even if this instance is active, has another instance already claimed this transition?**

They solve different problems.

A stale-instance guard like `isViewActive` stops dead or outdated views from navigating.  
A cross-instance guard like `matchesBeingStarted` stops multiple still-alive instances from all navigating at once.

You need both.

Lifecycle guards alone do not stop two active-looking instances from both trying to push.

---

## Good Patterns

### Good: active lobby instance pushes gameplay
- `onChange` sees authoritative `in_progress`
- instance is active
- match identity still matches
- cross-instance guard passes
- authoritative checks pass
- router push happens once

### Good: disappearing instance stands down
- screen disappears
- `isViewActive = false`
- async callback completes later
- callback re-checks active state
- no navigation occurs

### Good: delayed dismiss revalidates
- overlay schedules delayed dismiss
- callback fires
- overlay is still active and relevant
- dismissal proceeds safely

---

## Bad Patterns

### Bad: lifecycle event equals authority
- `onAppear` fires
- code assumes this instance should navigate

### Bad: task completion without revalidation
- task started on old view
- task finishes later
- old view still pushes/dismisses

### Bad: stale `onChange`
- state change observed
- old instance and new instance both react
- duplicate transition occurs

### Bad: disappearance without cancellation
- view disappears
- outstanding task still holds navigation closure
- later completion still acts

### Bad: active-state-only thinking
- `isViewActive == true`
- but match identity/flow ownership already changed
- wrong navigation still happens

---

## What To Preserve When Editing

When editing navigation-sensitive SwiftUI views, preserve:

- instance identity where it exists
- `isViewActive` semantics
- `onDisappear` invalidation
- task cancellation on disappearance where relevant
- revalidation before async completion navigates
- match-id and flow-id rechecks
- cross-instance protections for high-risk transitions

Do not remove these because the code looks defensive.
It is defensive for a reason.

---

## Debugging Lifecycle/Instance Bugs

When a stale-instance navigation bug appears, debug in this order:

1. which view instance actually requested navigation?
2. was that instance still active?
3. had it already disappeared?
4. did a task/callback complete after disappearance?
5. did match identity still match?
6. did flow ownership still match?
7. did another instance already own the transition?
8. did authoritative truth still support the route?

Usually the bug is one of:
- old instance
- old task
- old match context
- missing cross-instance guard

---

## Relationship to Other Docs

This document is about:

**is this view instance still allowed to act?**

That is different from:

- `one-navigation-owner.md` → who owns the transition
- `remote-navigation-guards.md` → what broader remote guard stack must pass
- `authoritative-navigation-checks.md` → what must be true in remote state
- `router-architecture.md` → who executes the navigation

You need all of them.

A view can fail navigation safety because:
- it is not the owner
- it is stale
- the request is stale
- the truth is stale
- router execution is duplicated

This doc covers the **instance stale** part.

---

## Bottom Line

In SwiftUI, a callback firing does not prove the view is still the right one to navigate.

Only the current, active, still-valid instance gets to act.