> Supporting reference for: realtime-patterns  
> Apply when: handling realtime subscriptions for remote matches, especially when the UI reacts to events but must still refetch authoritative state before updating long-lived UI

# Realtime as Trigger, Not Truth

## Purpose

This document defines the core client-side realtime rule for remote matches:

**realtime is a trigger layer, not the source of truth.**

Use it to prevent these common mistakes:
- trusting payloads as final state
- mutating long-lived UI directly from subscription events
- navigating from realtime alone
- skipping the authoritative refetch step

---

## Core Rule

When a realtime event arrives, it means:

**something may have changed**

It does **not** mean:

**the payload is the final authoritative truth the UI should trust on its own**

For remote matches, the client should treat realtime as a wake-up signal:
1. receive event
2. decide whether it is relevant
3. choose the correct refetch path
4. refetch authoritative state
5. update UI from the refetched result

---

## What Realtime Is Allowed To Do

Realtime may:
- wake up a screen
- tell the client to re-check match state
- tell the client to re-check match lists
- clear stale waiting states after authoritative refetch
- accelerate UI response by reducing polling delay

Realtime is useful for **awareness**.

It is not authoritative by itself.

---

## What Realtime Must Not Do

Realtime must not directly:
- become the long-lived match model
- decide final lifecycle state from payload alone
- drive gameplay/lobby navigation from payload alone
- replace `fetchMatch(...)`
- replace `loadMatches(...)`
- override authoritative row state with local assumptions

Bad pattern:
- subscription says `remote_status = cancelled`
- client directly sets local model to cancelled
- screen navigates/dismisses before refetch

Good pattern:
- subscription says something changed
- client refetches
- refetch confirms cancelled
- UI updates from authoritative state

---

## Why This Rule Exists

Realtime payloads can be:
- partial
- delayed
- duplicated
- out of order
- observed during awkward lifecycle moments
- inconsistent with what the current screen still has loaded

That means the payload is useful as a **signal**, but risky as **truth**.

If the app trusts the payload directly, it can easily produce:
- stale cards
- stale overlays
- wrong navigation
- flicker
- contradictory UI across screens
- local state that disagrees with the database

---

## Remote Match Truth Lives Elsewhere

For remote matches, long-lived truth should come from:
- canonical match row state
- authoritative related records
- refetched arrays / flow match state derived from those records

Not from:
- subscription payload alone
- temporary SwiftUI state
- card presentation state
- local booleans from an earlier lifecycle step

---

## Correct Realtime Pattern

The standard pattern is:

### Step 1: Event arrives
A realtime insert/update/delete comes in.

### Step 2: Relevance is checked
Confirm:
- is this for the current user?
- is this for the current match?
- is this for a list the user is viewing?
- is this replay-specific?
- is this ignorable noise?

### Step 3: Choose refetch path
Use the smallest correct authoritative reload:
- `fetchMatch(...)`
- `loadMatches(...)`
- forced `loadMatches(...)`

### Step 4: Refetch authoritative state
Refetch the match or the lists.

### Step 5: Update UI from authoritative result
The UI changes because the authoritative model changed, not because the payload arrived.

---

## Good Examples

### Good: active lobby match update
- realtime event arrives
- current screen sees event is for active match
- client runs `fetchMatch(...)`
- fetched match shows countdown started
- lobby enters countdown phase

### Good: sent/pending/ready card change
- realtime event arrives
- current screen sees list-backed sections may have changed
- client runs `loadMatches(...)`
- arrays reclassify match
- card moves/disappears correctly

### Good: replay overlay update
- realtime event arrives
- replay overlay depends on service arrays
- client forces `loadMatches(...)` if necessary
- authoritative arrays update
- overlay dismisses or changes state from refetched truth

---

## Bad Examples

### Bad: payload-driven card removal
- realtime says cancelled
- client removes card immediately
- arrays never reload
- another screen still shows old state

### Bad: payload-driven navigation
- realtime says in_progress
- client pushes gameplay immediately
- authoritative refetch later disagrees

### Bad: payload-driven countdown
- realtime suggests countdown began
- local screen changes phase without checking `lobby_countdown_started_at`

### Bad: stale overlay
- realtime event arrives
- client skips reload because “already in flow”
- overlay depends on stale arrays
- UI appears frozen even though the server changed

---

## Client vs Payload

### The payload tells you:
- an event happened
- which row or record may be relevant
- which broad category of change occurred

### The authoritative refetch tells you:
- what the state actually is now
- whether the current screen should react
- whether the card belongs in a different bucket
- whether navigation is now valid
- whether the match is actually cancelled / ready / lobby / in_progress

This distinction is critical.

---

## When This Rule Matters Most

This rule matters most when:
- the user is already inside remote flow
- the current screen depends on service arrays
- replay state changes
- cancellation or decline should remove something from UI
- lobby → countdown → gameplay transitions are involved
- multiple screens can observe the same match differently

If a bug looks like:
- “realtime arrived but nothing updated”
- “card vanished on one side but not the other”
- “overlay did not dismiss”
- “navigation happened too early”
- “UI and DB disagree”

this rule is probably being broken somewhere.

---

## Realtime Is Not an Instruction To Navigate

Realtime may tell the client to re-check state.

It may not directly instruct the client to:
- enter lobby
- leave lobby
- enter gameplay
- dismiss a replay overlay
- mark a match completed

Those actions should happen only after:
- authoritative refetch
- validation of the current screen context
- navigation guards confirm the screen is still valid

---

## Realtime Is Not a Substitute for Reload Strategy

A subscription event does not answer:
- should I fetch the active match?
- should I reload all list buckets?
- should I force reload even while in remote flow?

That is a **client decision** based on what part of the UI depends on the changed state.

Realtime is the trigger.
Reload strategy is the response.

---

## Debug Rule

When a realtime bug happens, do not ask:

- “why didn’t the payload fix the UI?”

Ask:

- did realtime arrive?
- was it treated as relevant?
- what authoritative reload path ran?
- was that reload skipped or throttled?
- did authoritative state actually change?
- did the UI render from the updated authoritative result?

That is the real debugging path.

---

## Client May / Must Not

### Client may
- listen to realtime
- filter irrelevant events
- choose the correct authoritative reload path
- use realtime to wake sleeping UI
- use realtime to reduce perceived lag

### Client must not
- trust payload alone as lifecycle truth
- mutate long-lived remote state from payload alone
- navigate solely because a payload arrived
- skip authoritative refetch when remote UI correctness depends on it

---

## What Good Looks Like

Good remote realtime handling has this property:

**if the subscription were delayed, duplicated, or reordered, the app would still become correct after authoritative refetch.**

That is the test.

If the app only works because the payload was trusted directly, the pattern is brittle.

---

## Bottom Line

Realtime is a signal to look again.

It is not the thing you were looking for.