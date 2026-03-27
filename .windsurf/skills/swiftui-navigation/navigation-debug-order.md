> Supporting reference for: swiftui-navigation  
> Apply when: debugging any Dart Freak navigation bug, especially duplicate pushes, stale-instance navigation, replay route issues, premature gameplay entry, failed lobby entry, or any case where the app navigates twice, too early, too late, or not at all  
> Do not apply to: pure state bugs that do not affect route changes, generic layout issues, or non-navigation realtime debugging unless it directly leads to a navigation failure

# Navigation Debug Order

## Purpose

This document defines the correct order for debugging navigation bugs in Dart Freak.

The goal is to stop random guessing.

When navigation breaks, it is very easy to jump straight to:
- Router
- SwiftUI
- `NavigationStack`
- `onAppear`
- `onChange`
- “the router is pushing twice”
- “SwiftUI is weird”

That is usually too late in the chain.

The correct approach is to debug from:

**owner → guards → authoritative truth → instance validity → router execution**

not from the visual symptom alone.

---

## Core Rule

Debug navigation bugs in this order:

1. what exact transition failed
2. who owned that transition
3. what guards were supposed to protect it
4. what authoritative truth was required
5. whether the acting instance was still valid
6. whether another instance or owner also acted
7. what the router actually executed
8. only then inspect SwiftUI stack behavior

Do not skip steps.

---

## Why Order Matters

A navigation bug can come from very different causes:

- wrong owner
- two owners
- stale view instance
- stale async completion
- missing guard
- authoritative truth not actually confirmed
- router got duplicate requests
- overlay and route logic racing each other
- `NavigationStack` behavior after a bad upstream decision

If you start at the bottom, you can easily “fix” the wrong layer.

---

## Step 1 — What Exact Transition Failed?

Start by naming the transition precisely.

Examples:
- remote games tab → remote lobby
- remote lobby → remote gameplay
- replay overlay → replay lobby
- replay overlay dismissal
- gameplay → end game
- end game → replay lobby
- popToRoot + push replay lobby

Be exact.

Bad:
- “navigation is broken”

Good:
- “remote lobby → gameplay happened twice”
- “replay overlay did not dismiss after cancellation”
- “accept challenge completed but lobby never pushed”

If you cannot name the transition precisely, you will debug too broadly.

---

## Step 2 — Who Owned the Transition?

Once the transition is clear, identify the owner.

Ask:
- which feature/view is supposed to decide this transition?
- is that still the intended owner?
- did some observer accidentally become a second owner?

Examples:
- `RemoteGamesTab` owns lobby entry
- `RemoteLobbyView` owns gameplay push
- replay flow owner owns replay lobby entry or overlay dismissal

This is one of the highest-value steps.

A lot of navigation bugs are ownership bugs, not router bugs.

---

## Step 3 — What Guards Were Supposed To Protect It?

Next, identify the guard stack for that transition.

Possible guards include:
- `processingMatchId`
- `navInFlightMatchId`
- `cancelledMatchIds`
- `matchesBeingStarted`
- `isViewActive`
- flow identity checks
- match identity checks
- duplicate-push protection
- overlay visibility checks
- terminal/unwind guards

Ask:
- which guards should have blocked a bad request?
- which guard should have allowed a good request?
- did one guard silently no-op the transition?

If you do not know the guard stack, you are not ready to debug the failure.

---

## Step 4 — What Authoritative Truth Was Required?

Before navigation should happen, what had to be authoritatively true?

Examples:
- match really `in_progress`
- replay really ready/joinable
- replay really cancelled or missing from arrays
- match still valid for lobby entry
- current route context still belongs to the same match

Ask:
- what source was supposed to confirm the transition?
- `fetchMatch(...)`?
- `loadMatches(...)`?
- forced `loadMatches(...)`?
- active `flowMatch`?
- authoritative replay arrays?

This is critical because a lot of navigation bugs are really truth-validation bugs.

---

## Step 5 — Was the Acting Instance Still Valid?

Now check whether the thing trying to navigate was still the correct live instance.

Ask:
- was `isViewActive == true`?
- had the view already disappeared?
- did the callback come from a stale instance?
- did the match identity still match?
- did the flow still belong to this match?
- was a delayed callback or async completion acting too late?

This is where many SwiftUI-specific bugs actually live.

Not in the stack itself — in stale instances still trying to act.

---

## Step 6 — Did Another Owner or Instance Also Act?

Before blaming the router, check whether multiple actors requested the same transition.

Examples:
- parent and child both pushed
- `onAppear` and `onChange` both pushed
- realtime woke one owner, but a stale instance also pushed
- overlay dismissed while parent pushed new route
- old async completion fired after a new request had already taken over

Ask:
- did one owner request the route once?
- or did multiple owners/instances request it?

This is especially important in remote and replay flows.

---

## Step 7 — What Did the Router Actually Execute?

Only now should you inspect router execution.

Check:
- did router receive one push or several?
- did duplicate-push protection drop one?
- did `popToRoot` run before the next push?
- what was the path depth before and after?
- did router logging confirm the expected sequence?

At this stage, router logs are very useful.

But they are not the first place to start, because router may only be showing the downstream effect of a bad upstream owner/guard decision.

---

## Step 8 — Only Then Inspect SwiftUI Stack Behavior

Once you know:
- the right owner
- the right guard stack
- the right authoritative truth
- the right live instance
- the router execution sequence

only then inspect `NavigationStack` behavior itself.

This is the final layer, not the first one.

Examples of true stack-level issues:
- path not mutating as expected
- push/pop ordering issues
- transition modifier side effects
- animation quirks
- stack depth inconsistency after correct route execution

These do happen, but much less often than ownership/guard/truth bugs.

---

## The Standard Debug Ladder

Use this exact ladder:

### 1. Transition
What exact route change failed?

### 2. Owner
Who was supposed to decide it?

### 3. Guards
What should have allowed or blocked it?

### 4. Authoritative truth
What server-backed or authoritative state had to be confirmed?

### 5. Instance validity
Was the acting instance still current and active?

### 6. Competing actors
Did another owner/instance also request the same transition?

### 7. Router execution
What did router actually execute?

### 8. Stack behavior
Did SwiftUI stack behavior behave correctly after valid execution?

Do not reorder this ladder.

---

## Debugging by Symptom

### Symptom: “Lobby pushed twice”
Check in order:
1. who owned lobby entry
2. did two owners request it
3. did `processingMatchId` / `navInFlightMatchId` fail
4. did router receive duplicate push requests
5. did duplicate-push protection mask a deeper bug

Usually this is not a `NavigationStack` problem.

---

### Symptom: “Gameplay never pushed”
Check in order:
1. did `RemoteLobbyView` still own gameplay transition
2. was `isViewActive` true
3. did `matchesBeingStarted` block it
4. did authoritative `in_progress` checks pass
5. did router actually receive a push request

Usually this is a guard or authoritative truth problem.

---

### Symptom: “Replay overlay did not dismiss”
Check in order:
1. who owned replay dismissal
2. what authoritative replay source should have confirmed dismissal
3. did authoritative state actually change
4. was overlay instance still active
5. did a competing route transition also happen

Usually this is ownership + authoritative-source confusion.

---

### Symptom: “Replay lobby pushed too early”
Check in order:
1. who owned replay lobby push
2. was replay truth actually confirmed
3. did a payload or voice event get mistaken for navigation authority
4. did a stale overlay or callback push
5. did router simply execute a bad upstream request

Usually this is an authoritative-check failure.

---

### Symptom: “Nothing happened after accept/join”
Check in order:
1. who owned lobby entry
2. did processing guard remain stuck
3. did nav-in-flight token change
4. did authoritative state still support lobby entry
5. did router get the push request at all

Usually this is request validity or guard failure, not visual navigation failure.

---

## Good Debug Questions

Ask questions like:
- what exact transition failed?
- who owned this decision?
- what guard should have stopped or allowed it?
- what authoritative source was required?
- was the acting instance still valid?
- did another owner also act?
- what did router actually do?

These isolate the real layer of failure.

---

## Bad Debug Questions

Avoid starting with:
- “Is SwiftUI just bugging?”
- “Should we add another delay?”
- “Can we force the push?”
- “Should we move this into onAppear?”
- “Can router just ignore duplicates?”
- “Why didn’t the animation work?”

Those questions are too downstream and often hide the real problem.

---

## Logging Rule for Navigation Debugging

Good navigation logs should support this debug order directly.

You want logs that show:
- transition requested
- owner identity
- guard pass/fail
- authoritative status/source
- instance activity
- router push/pop execution
- final navigation result

If logs only show:
- “push”
- “dismiss”
- “onAppear fired”
- “status changed”

then debugging will be slow and expensive.

---

## Relationship to Other Docs

This doc is about the **order of diagnosis**.

Use it with:
- `router-architecture.md` for execution model
- `one-navigation-owner.md` for ownership
- `remote-navigation-guards.md` for guard stack
- `authoritative-navigation-checks.md` for truth requirements
- `lifecycle-and-instance-guards.md` for stale instance protection
- `replay-navigation-rules.md` for replay-specific transitions

Those docs explain the rules.  
This doc explains how to find which rule broke.

---

## What Good Looks Like

Good navigation debugging has this property:

**you can point to the exact broken layer — owner, guard, truth, instance, or router — instead of only describing the visual symptom.**

That is the standard.

---

## Bottom Line

Do not debug navigation from the animation backward.

Debug it from the transition owner forward.