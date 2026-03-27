> Supporting reference for: realtime-patterns  
> Apply when: working on navigation after remote realtime events, lobby/gameplay transitions, replay navigation, overlay dismissal, or any bug where the app navigates too early, too late, or from stale state  
> Do not apply to: local matches or navigation not triggered by remote realtime events

# Realtime Navigation Rules

## Purpose

This document defines how navigation should behave when remote realtime events arrive.

The goal is simple:

**realtime may wake navigation up, but realtime must not directly own navigation.**

This exists because one of the easiest mistakes in remote flows is:
- a payload arrives
- the client treats it as final truth
- the app navigates immediately
- authoritative state catches up later
- the UI gets out of sync or double-navigates

---

## Core Rule

Realtime can trigger a re-check.

Realtime cannot, by itself, justify navigation.

The correct order is:

1. realtime event arrives
2. determine whether it is relevant
3. refetch authoritative state
4. validate the current screen context
5. validate navigation guards
6. then navigate if authoritative state still supports it

---

## What Realtime May Do

Realtime may:
- wake up the current screen
- clear stale waiting states
- trigger `fetchMatch(...)`
- trigger `loadMatches(...)`
- trigger forced `loadMatches(...)` when needed
- make the client re-evaluate whether navigation should happen

Realtime is a trigger for navigation checks.

It is not navigation authority.

---

## What Realtime Must Not Do

Realtime must not directly:
- push lobby
- push gameplay
- pop or dismiss purely from payload
- mark the current screen as obsolete without refetch
- skip navigation guards because the payload “looked right”

Bad:
- payload says `in_progress`
- app immediately pushes gameplay

Good:
- payload arrives
- app refetches match
- match confirms `in_progress`
- current screen is still valid
- guards pass
- then gameplay navigation occurs

---

## Navigation Must Follow Authoritative State

Navigation should be driven by:
- authoritative fetched match state
- authoritative reloaded arrays when list-backed UI matters
- validated local screen/flow guards

Not by:
- subscription payload alone
- stale local route assumptions
- optimistic UI guesses
- old cached match objects

If navigation matters, refetch first.

---

## Standard Navigation Decision Order

When a realtime event might imply navigation:

### Step 1: relevance
Check:
- is this event for the current user?
- is this event for the current match?
- is this event relevant to the visible screen?
- is this replay-specific?

### Step 2: choose authoritative refetch path
Use:
- `fetchMatch(...)` for active match navigation decisions
- `loadMatches(...)` for list-backed / replay card truth
- forced `loadMatches(...)` if list-backed replay UI would otherwise stay stale

### Step 3: refetch truth
Refetch authoritative state.

### Step 4: validate current screen context
Confirm:
- the current screen instance is still the right one
- the user is still in the same flow
- the match identity still matches what the screen thinks it is showing

### Step 5: validate navigation guards
Examples:
- not already navigating
- not already in terminal unwind
- not already in gameplay
- active flow match still matches
- screen has not disappeared or been replaced

### Step 6: navigate once
Only after all of the above should navigation happen.

---

## Active Match Navigation Rule

For active lobby/gameplay transitions, navigation decisions should usually come from `fetchMatch(...)`.

Examples:
- lobby → gameplay
- lobby remains lobby
- completed/terminal transitions
- authoritative re-entry checks

If the current screen is driven by one match, use that match’s authoritative refetch as the navigation source.

Do not use list reloads as the primary navigation truth for active-match transitions unless the screen is actually list-backed.

---

## Replay Navigation Rule

Replay needs special care.

Replay navigation often happens near:
- overlays
- end-game screens
- list-backed replay cards
- replay lobby entry
- replay cancellation/dismissal

That means replay navigation should only happen after confirming whether the replay UI is:
- active-match-driven
- array-driven
- overlay-driven

Bad:
- realtime says replay is ready
- app pushes replay lobby immediately

Good:
- realtime triggers authoritative reload
- replay is confirmed ready in the correct authoritative source
- current overlay/screen context is still valid
- then navigation occurs

---

## Dismissal Is Navigation Too

Dismissal should follow the same rules as pushes.

Do not dismiss:
- replay overlays
- challenge overlays
- waiting states
- lobby screens

directly from realtime payload alone.

Dismiss after:
- authoritative state confirms the UI no longer belongs on screen
- current screen/overlay is still active
- dismissal guard passes

A replay disappearing from authoritative arrays after reload can be a valid dismissal signal.
A payload alone is not.

---

## Navigation Guards Matter

Authoritative state is necessary, but not sufficient.

The app must also guard against:
- double push
- push after screen disappearance
- navigation from stale screen instances
- competing navigation owners
- terminal unwind collisions
- flow mismatch

Examples of useful guard categories:
- current match id still matches
- not already transitioning
- screen instance still active
- flow owner still correct
- destination not already on stack

Realtime bugs often become navigation bugs because these guards are skipped.

---

## One Navigation Owner Rule

Even after authoritative refetch, navigation should still have one owner.

Realtime may cause that owner to re-evaluate.

Realtime must not become a second owner.

Bad:
- realtime handler directly pushes
- view onChange also pushes
- router observes both
- duplicate navigation occurs

Good:
- realtime triggers authoritative refetch
- one owner sees authoritative change
- one owner decides whether to navigate

This is especially important in lobby/gameplay and replay flows.

---

## Good Patterns

### Good: lobby to gameplay
- realtime event arrives
- active lobby screen refetches match
- match confirms `in_progress`
- current screen instance is still active
- navigation latch/guard passes
- gameplay push happens once

### Good: replay overlay dismissal
- realtime event arrives
- arrays reload authoritatively
- replay no longer exists or is cancelled
- overlay is still visible
- dismissal happens once from authoritative result

### Good: challenge card to lobby
- authoritative status becomes ready/joinable
- UI refetches the right source
- user action or validated flow logic initiates navigation
- no direct payload-driven push

---

## Bad Patterns

### Bad: payload-driven push
- realtime says `in_progress`
- push gameplay immediately

### Bad: payload-driven dismiss
- realtime says cancelled
- dismiss overlay before arrays or active match confirm it

### Bad: double-navigation architecture
- realtime handler pushes
- view state observer also pushes
- both see the same transition

### Bad: stale-screen navigation
- refetch completes
- screen is no longer active
- navigation still fires from old context

### Bad: list reload used as gameplay truth
- gameplay navigation depends on broad list churn instead of authoritative active match

---

## In-Remote-Flow Navigation Rule

When already inside remote flow:
- prefer authoritative active-match refetch for navigation decisions
- avoid broad reload-driven navigation unless the visible UI is actually list-backed

If replay/list-backed UI is visible, then:
- forced list reload may be needed
- but navigation or dismissal still must come from the authoritative result, not the raw realtime event

---

## Terminal State Rule

Terminal or unwind navigation must be especially careful.

If a realtime event suggests a terminal transition:
- refetch authoritative state
- confirm terminal status
- confirm current screen should still respond
- ensure terminal handling has not already started
- then unwind/dismiss/navigate

Do not let realtime payloads trigger terminal behavior directly.

Terminal transitions are high-risk for duplicate or stale navigation.

---

## Logging Rule

Log navigation decisions at the decision point.

Useful logs:
- realtime event received
- relevance decision
- chosen refetch path
- authoritative state after refetch
- current screen/match identity
- which navigation guard passed or blocked
- whether navigation was skipped or performed
- whether navigation owner already acted

Bad logs:
- “navigating”
- “skipped”
- no match id
- no reason
- no distinction between payload and authoritative state

If a navigation bug appears, logs should make it obvious whether the problem was:
- no refetch
- wrong refetch
- stale screen
- missing guard
- duplicate navigation owner

---

## Debug Order

When navigation after realtime is wrong, debug in this order:

1. did the realtime event arrive
2. was it relevant
3. what authoritative refetch path ran
4. what authoritative state came back
5. was the current screen still valid
6. did the correct navigation owner observe the state
7. did a guard block navigation
8. did multiple owners try to navigate
9. did dismissal/push happen from payload instead of authoritative state

Do not start with router code if the authoritative confirmation never happened.

---

## Client May / Must Not

### Client may
- let realtime wake up navigation checks
- refetch before navigating
- use explicit navigation latches/guards
- dismiss overlays from authoritative disappearance or confirmed status
- keep one clear navigation owner

### Client must not
- navigate directly from payload
- dismiss directly from payload
- let realtime become a second navigation owner
- bypass guards because the subscription event looked convincing
- treat stale local route state as proof that navigation is safe

---

## What Good Looks Like

Good realtime navigation has this property:

**if the realtime payload were delayed, duplicated, or slightly reordered, navigation would still happen correctly because the app waited for authoritative confirmation and valid screen context.**

That is the standard.

---

## Bottom Line

Realtime may tell the app to check whether it should navigate.

It may not tell the app to navigate.