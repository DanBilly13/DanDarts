> Supporting reference for: swiftui-navigation  
> Apply when: reviewing or changing navigation code in Dart Freak, especially if a proposed fix feels “quick,” “simple,” or based on generic SwiftUI instincts rather than the app’s actual router and remote-flow rules  
> Do not apply to: pure layout work, non-navigation UI tweaks, or state changes that do not affect route transitions

# Navigation Anti-Patterns

## Purpose

This document lists the navigation patterns that should be avoided in Dart Freak.

It exists because many navigation bugs do not come from missing code.

They come from the wrong kind of code:
- generic SwiftUI shortcuts
- second navigation owners
- stale-instance route pushes
- payload-driven transitions
- “just add a delay” fixes
- bypassing the router because it feels faster

These anti-patterns often look reasonable in isolation.  
In Dart Freak, they are usually dangerous.

---

## Core Rule

If a navigation change bypasses:
- the router
- the one-owner model
- the remote guard stack
- authoritative truth checks
- instance validity checks

then it is probably the wrong fix.

---

## Anti-Pattern 1 — Direct `NavigationStack` Mutation from Feature Code

### Bad
A feature view directly mutates `NavigationPath`, appends routes itself, or creates its own stack mutation shortcut.

### Why it is bad
This breaks the centralized router model.

It creates:
- multiple navigation writers
- harder debugging
- inconsistent execution paths
- lost router logging
- lost duplicate-push protection

### Correct pattern
Features request navigation through `Router.shared`.  
`MainTabView` remains the stack owner.

---

## Anti-Pattern 2 — More Than One Owner for the Same Transition

### Bad
Two or more places can decide the same route transition.

Examples:
- parent and child both push the same route
- realtime and a view both trigger gameplay push
- overlay logic and end-game logic both own replay lobby entry
- `onAppear` and `onChange` both own the same transition

### Why it is bad
This creates:
- duplicate pushes
- races
- hard-to-reproduce bugs
- transition ownership confusion

### Correct pattern
One feature/view owns the transition decision.  
Router executes it.

---

## Anti-Pattern 3 — Realtime Payload as Navigation Authority

### Bad
A realtime payload arrives and the app navigates immediately from that payload alone.

Examples:
- payload says `in_progress` → push gameplay
- payload says `cancelled` → dismiss overlay
- payload says replay ready → push replay lobby

### Why it is bad
Realtime is a trigger, not truth.

Payloads are not enough to prove:
- the current screen is still valid
- authoritative state still agrees
- the right owner is acting
- the route change still belongs to the current flow

### Correct pattern
Realtime triggers authoritative re-check.  
Owner decides after authoritative truth confirms the transition.

---

## Anti-Pattern 4 — Treating `onAppear` as Automatic Navigation Authority

### Bad
A view uses `onAppear` as the main reason to navigate.

Example:
- `onAppear` fires
- condition is true
- push happens immediately

### Why it is bad
`onAppear` may:
- fire more than once
- fire in stale instances
- overlap with async work
- run before ownership/guard/truth are fully revalidated

### Correct pattern
`onAppear` may help observe or initialize.  
It must not casually bypass owner, guard, and authoritative checks.

---

## Anti-Pattern 5 — Treating `onChange` as Automatic Navigation Authority

### Bad
A view sees a state change in `onChange` and pushes immediately.

### Why it is bad
`onChange` is an observation point, not automatic permission to navigate.

Without extra checks, it can:
- fire in stale instances
- duplicate an existing owner
- react to state that has not been authoritatively confirmed enough
- race with another observer

### Correct pattern
Use `onChange` only inside the designated owner, and still require:
- active-instance validity
- ownership clarity
- authoritative truth
- duplicate-transition protection

---

## Anti-Pattern 6 — Removing Guards Because They “Look Redundant”

### Bad
A developer removes:
- `processingMatchId`
- `navInFlightMatchId`
- `matchesBeingStarted`
- `isViewActive`
- repeated authoritative checks
- flow identity checks

because router already has duplicate-push protection or because one check “should be enough.”

### Why it is bad
These guards solve different problems.

Examples:
- processing guard prevents duplicate requests
- nav-in-flight prevents stale async completion
- `isViewActive` prevents dead instances acting
- `matchesBeingStarted` prevents cross-instance duplicate gameplay push
- authoritative checks prevent premature remote transitions

### Correct pattern
Preserve the guard intent unless you can explicitly replace it with something equally protective.

---

## Anti-Pattern 7 — Using Router Duplicate Protection as the Main Strategy

### Bad
A feature emits duplicate navigation requests and relies on router duplicate filtering to absorb the damage.

### Why it is bad
Router duplicate protection is a safeguard, not the architecture.

It does not solve:
- wrong owner
- stale instance
- wrong-match async completion
- missing authoritative truth
- cross-instance duplicate logic

### Correct pattern
Prevent bad requests upstream.  
Let router duplicate filtering remain a last line of defense.

---

## Anti-Pattern 8 — “Just Add a Delay”

### Bad
A timing bug appears, and the proposed fix is:
- add `DispatchQueue.main.asyncAfter`
- wait 0.3 seconds
- wait 1 second before push
- wait “for SwiftUI to settle”

### Why it is bad
A delay often hides the real bug:
- wrong owner
- stale instance
- missing authoritative check
- bad guard timing
- replay overlay race
- old async completion

Delays can make bugs rarer without making them correct.

### Correct pattern
Fix:
- ownership
- guard validity
- authoritative truth timing
- instance validity
- route sequencing

Only use delay if the design truly requires staged UX behavior, and still revalidate before acting.

---

## Anti-Pattern 9 — Navigating from Stale Async Completion

### Bad
Async work starts from one screen context, completes later, and pushes/dismisses without revalidation.

Examples:
- accept/join completion pushes old lobby
- replay entry completion pushes after ownership changed
- delayed overlay callback dismisses after overlay is no longer current

### Why it is bad
The request may no longer belong to:
- the same match
- the same screen
- the same owner
- the same flow

### Correct pattern
Before acting at async completion time, re-check:
- instance validity
- match identity
- nav request identity
- authoritative truth
- ownership

---

## Anti-Pattern 10 — Confusing Authoritative Truth with Request Validity

### Bad
Code checks only one of these:
- the match is `in_progress`
- or this view is still active

and assumes that is enough.

### Why it is bad
These are different questions:

- authoritative truth → should this transition exist at all?
- request validity → is this specific instance/request still allowed to perform it?

You need both.

### Correct pattern
Navigation should require:
- authoritative truth
- valid current instance/request
- router execution

---

## Anti-Pattern 11 — Treating Replay Like Ordinary Navigation

### Bad
Replay navigation is treated like:
- a simple card tap
- a simple local route push
- a normal overlay close
- a generic button-driven transition

### Why it is bad
Replay often combines:
- remote truth
- overlay state
- end-game context
- active flow unwinding
- voice session reuse
- list-backed replay state

That means replay needs:
- explicit ownership
- authoritative replay confirmation
- instance protection
- correct dismissal/push sequencing

### Correct pattern
Treat replay as guarded remote navigation, not as a normal local push.

---

## Anti-Pattern 12 — Letting Overlay Logic and Route Logic Fight

### Bad
An overlay is still acting like a navigation owner while another route transition is already taking over.

Examples:
- overlay dismisses while parent pushes
- overlay decides replay lobby push while parent also does
- delayed overlay callback acts after replay route already changed

### Why it is bad
This creates:
- double transitions
- weird race conditions
- broken replay UX
- hard-to-debug stale overlay bugs

### Correct pattern
Make overlay ownership and route ownership explicit.  
If one takes over, the other should stand down.

---

## Anti-Pattern 13 — Using Local UI State as Proof of Route Validity

### Bad
Code navigates because:
- a button was enabled
- a card looked joinable
- a local phase changed
- the screen “looked ready”

### Why it is bad
Local UI state may lag, lead, or drift from remote truth.

This is especially dangerous in:
- remote lobby transitions
- replay entry
- overlay dismissal
- gameplay start

### Correct pattern
Use local UI state as a signal to check truth, not as final proof of truth.

---

## Anti-Pattern 14 — Debugging Router First

### Bad
A navigation bug appears and the first assumption is:
- router is broken
- `NavigationStack` is weird
- SwiftUI pushed twice

### Why it is bad
Most navigation bugs are upstream:
- wrong owner
- stale instance
- missing guard
- bad authoritative check
- duplicate request generation

### Correct pattern
Debug in order:
1. transition
2. owner
3. guards
4. authoritative truth
5. instance validity
6. competing actors
7. router execution
8. stack behavior

---

## Anti-Pattern 15 — Refactoring Away App-Specific Navigation Defenses

### Bad
A change makes the code look “cleaner” by removing app-specific complexity:
- fewer latches
- fewer checks
- fewer ownership boundaries
- more generic SwiftUI navigation patterns

### Why it is bad
Much of that complexity exists because Dart Freak already hit these bugs in real life.

What looks redundant may actually be:
- stale-instance protection
- cross-instance protection
- replay sequencing protection
- wrong-match navigation protection

### Correct pattern
Refactor only if you can preserve the protection, not just the appearance of simplicity.

---

## Common Smells

If you see code like this, treat it as suspicious:

- “just push here too”
- “we can probably navigate right from this status change”
- “router will ignore duplicates anyway”
- “this is only from onAppear”
- “it’s just a replay card tap”
- “let’s wait 0.5 seconds before pushing”
- “we probably don’t need this guard anymore”
- “the payload already tells us the new state”

These are classic anti-pattern entry points.

---

## Good Replacement Mindset

When tempted by a shortcut, replace the thought with:

- who owns this transition?
- what authoritative truth must be true?
- is this instance still valid?
- what guard is protecting this request?
- could another actor also trigger this?
- should this code observe, or actually navigate?

That mindset avoids most of the anti-patterns in this doc.

---

## Relationship to Other Docs

This doc lists what **not** to do.

Use it with:
- `router-architecture.md` for correct structure
- `one-navigation-owner.md` for ownership
- `remote-navigation-guards.md` for guard stack
- `authoritative-navigation-checks.md` for remote truth requirements
- `lifecycle-and-instance-guards.md` for stale instance protection
- `replay-navigation-rules.md` for replay-specific route behavior
- `navigation-debug-order.md` for diagnosis flow

Those docs explain the intended model.  
This doc explains the shortcuts and habits that break it.

---

## Bottom Line

Most bad navigation fixes in Dart Freak fail for the same reason:

they bypass ownership, guards, truth, or instance validity in the name of convenience.

Do not take the convenient path.  
Take the correct one.