> Supporting reference for: realtime-patterns  
> Apply when: debugging any remote realtime bug, especially stale cards, stale overlays, missed replay updates, wrong reload choice, or navigation that happens too early, too late, or not at all  
> Do not apply to: local matches or bugs not involving remote realtime subscriptions

# Realtime Debug Order

## Purpose

This document defines the correct debugging order for remote realtime bugs.

The goal is to stop random guessing.

When a remote UI bug appears after a realtime event, the temptation is to jump straight to:
- SwiftUI rendering
- navigation
- card state
- overlay behavior
- “realtime is broken”

That is usually the wrong starting point.

The correct approach is to debug in strict order from event → refetch decision → authoritative state → rendered UI.

---

## Core Rule

Debug realtime bugs in this order:

1. did the realtime event arrive
2. was it relevant
3. what reload path was chosen
4. did that reload actually run
5. what authoritative state came back
6. did the client models update from that state
7. did the UI render from the updated models
8. only then debug navigation or SwiftUI issues

Do not skip steps.

---

## Why Order Matters

A stale UI bug can be caused by very different failures:

- no realtime event
- event ignored incorrectly
- wrong reload choice
- reload skipped because of in-remote-flow rules
- authoritative state never changed
- arrays never updated
- flowMatch never updated
- UI rendered from stale local data
- navigation fired from the wrong owner

If you start too late in the chain, you can easily “fix” the wrong thing.

---

## Step 1 — Did the Realtime Event Arrive?

First confirm that the event actually arrived.

Check:
- did the subscription callback fire
- was the correct channel active
- was the event type what you expected
- did the match id or row id match the bugged item
- was the user/context correct

If the event never arrived, stop there.

This is not yet a rendering bug or a reload bug.

### Good question
- “Did the subscription receive an update for this exact match?”

### Bad question
- “Why didn’t the overlay dismiss?” before confirming the event existed

---

## Step 2 — Was the Event Considered Relevant?

An event arriving is not enough.

The client may correctly ignore it if it is:
- for another user
- for another match
- for another screen context
- replay-irrelevant
- filtered out by design

Check:
- relevance guards
- replay checks
- current user checks
- current match checks
- list/section relevance checks

If the event was ignored, determine whether that was correct or a bug.

### Good question
- “Why did the relevance filter reject this event?”

### Bad question
- “Realtime is broken” when the event was deliberately ignored

---

## Step 3 — What Reload Path Was Chosen?

Once the event was accepted as relevant, ask:

What authoritative reload path did the code choose?

Possible paths:
- `fetchMatch(...)`
- `loadMatches(...)`
- forced `loadMatches(...)`
- no reload
- deferred/throttled reload

This is one of the most important steps in the whole debug process.

A lot of realtime bugs are actually wrong reload-choice bugs.

### Good question
- “Did we choose `fetchMatch(...)` for a UI that was actually array-backed?”

### Bad question
- “The arrays are stale, so SwiftUI must be lagging”

---

## Step 4 — Did the Reload Actually Run?

Even if the correct path was chosen, it may not have actually executed.

Check:
- was it skipped because `isInRemoteFlow == true`
- was it throttled
- was it already in progress
- was it cancelled
- did a force reload flag fail to apply
- did polling/join reuse an existing in-flight request

This step matters because many bugs are not “wrong path chosen,” but “path chosen, then suppressed.”

### Common smells
- replay cancelled, but arrays never refreshed
- reload path logged, but skip/throttle prevented execution
- broad reload should have been forced but was not

### Good question
- “Was the reload suppressed by in-remote-flow rules?”

---

## Step 5 — What Authoritative State Came Back?

Once a reload ran, inspect the actual authoritative result.

Check:
- fetched match fields
- fetched arrays / bucket classification
- remote status
- countdown state
- current player
- replay visibility
- disappearance from arrays
- cancellation / ready / lobby / in_progress transitions

This is where you verify whether the backend truth actually changed.

Do not assume the server changed just because the realtime event arrived.

### Good question
- “Did the authoritative reload actually confirm the state transition?”

### Bad question
- “The payload said cancelled, so the server must have cancelled it”

---

## Step 6 — Did Client Models Update From That State?

Now check whether the authoritative result actually flowed into the client model layer.

Examples:
- did `flowMatch` update
- did service arrays update
- did card buckets reclassify
- did overlay source state update
- did replay state update
- did current-player state update

A lot of bugs happen here:
- reload worked
- authoritative data was correct
- but the model layer never published the correct state

### Good question
- “Did `loadMatches(...)` publish the updated arrays?”
- “Did `fetchMatch(...)` actually update the active match model?”

---

## Step 7 — Did the UI Render From the Updated Models?

Only now do you look at the UI layer.

Check:
- is the screen actually reading the updated model
- is it rendering from stale cached state instead
- is the overlay/card driven by arrays or by a cached object
- did local fade/cache state override the new truth
- did the right computed presentation state run

At this stage, SwiftUI/rendering bugs are finally a fair suspect.

But not before.

### Good question
- “The model updated correctly — is the view rendering from a stale cache?”

### Bad question
- “The card didn’t disappear, so reload must have failed” without checking the model layer

---

## Step 8 — Only Then Debug Navigation

If the bug involves push/pop/dismiss:
- first confirm authoritative refetch happened
- then confirm model state updated
- only then inspect navigation ownership and guards

Check:
- correct navigation owner
- stale screen instance
- in-flight navigation guard
- global latch / single-owner rule
- terminal unwind guards
- replay overlay dismissal guards

Many “navigation bugs” are really earlier realtime/refetch bugs.

---

## The Standard Debug Ladder

Use this exact ladder:

### 1. Event
Did the realtime event arrive?

### 2. Relevance
Did the client accept or reject it correctly?

### 3. Path choice
Did the client choose the right authoritative reload path?

### 4. Execution
Did that reload actually run, or was it skipped/throttled/cancelled?

### 5. Authoritative truth
What did the server-backed fetch actually return?

### 6. Model update
Did flowMatch / arrays / overlay sources update from the fetched truth?

### 7. UI render
Did the visible screen render from the updated model?

### 8. Navigation/dismissal
Did the right navigation owner act, once, after authoritative confirmation?

Do not reorder this ladder.

---

### Debugging by Symptom

## Symptom: “Realtime arrived but nothing updated”
Check in order:
1. was event relevant
2. what reload path was chosen
3. was reload skipped/throttled
4. did authoritative state actually change

Usually this is not a SwiftUI problem.

---

## Symptom: “Card updated on one side but not the other”
Check in order:
1. did both devices receive relevant events
2. did both choose reload
3. did one device skip `loadMatches(...)`
4. did array classification update on both devices

Usually this is a list-reload asymmetry problem.

---

## Symptom: “Replay overlay did not dismiss”
Check in order:
1. did replay event arrive
2. was it recognized as replay-relevant
3. was forced reload needed
4. did arrays update
5. did overlay read from arrays or stale cached replay state

Usually this is a stale-array or stale-overlay-source problem.

---

## Symptom: “Lobby/gameplay navigation happened at the wrong time”
Check in order:
1. did authoritative `fetchMatch(...)` confirm the transition
2. did the active match update
3. did the right owner observe it
4. did a guard fail or get bypassed
5. did navigation happen from payload instead of authoritative state

Usually this is a premature navigation-owner problem.

---

## Symptom: “Countdown started but UI stayed connecting”
Check in order:
1. did authoritative row show countdown started
2. did `fetchMatch(...)` run
3. did active match update from fetch
4. did lobby phase derive from authoritative countdown field

Usually this is not a voice problem once authoritative countdown is present.

---

## Good Debug Questions

Ask questions like:
- which step in the pipeline failed?
- did the event arrive?
- was the reload choice correct?
- was the reload suppressed?
- what authoritative state did we fetch?
- did the model layer publish that state?
- what source is the UI actually rendering from?

These questions isolate the bug.

---

## Bad Debug Questions

Avoid vague questions like:
- “Why is realtime broken?”
- “Is SwiftUI lagging?”
- “Should we add more refreshes?”
- “Can we just force reload everything?”
- “Should we navigate directly from the event?”

These usually skip the actual decision chain.

---

## Logging Rule for Debugging

To make this debug order usable, logs should exist at these points:

- event received
- relevance decision
- chosen reload path
- skipped/throttled/forced reason
- authoritative fetch result
- model update result
- navigation/dismissal decision

If logs only show payloads and no decisions, debugging will be slow and expensive.

---

## Client May / Must Not

### Client may
- debug strictly from event to UI
- stop early once the broken step is found
- use authoritative fetch results as the main debug truth
- differentiate active-match bugs from array-backed bugs

### Client must not
- jump straight to UI assumptions
- blame navigation before confirming refetch
- add force reloads before proving the path choice was wrong
- treat subscription arrival as proof of authoritative change

---

## What Good Looks Like

Good realtime debugging has this property:

**you can point to the exact broken step in the pipeline, instead of describing the bug only by its visible symptom.**

That is the standard.

---

## Bottom Line

Do not debug remote realtime bugs from the screen backward.

Debug them from the event forward.