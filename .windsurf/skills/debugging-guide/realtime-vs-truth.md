> Supporting reference for: debugging-guide  
> Apply when: debugging Dart Freak bugs where something “didn’t update,” one side changed and the other did not, a card/overlay/list looks stale, or it is unclear whether the problem is missing realtime handling or unchanged authoritative truth  
> Do not apply to: local-only bugs, pure styling issues, or cases where the authoritative state is already confirmed wrong and the issue is clearly not about update delivery

# Realtime vs Truth

## Purpose

This document explains one of the most important debugging distinctions in Dart Freak:

**did realtime fail, or did authoritative truth never actually change?**

A lot of debugging goes wrong because stale UI gets blamed on realtime immediately.

Symptoms like:
- card did not update
- one side changed and the other did not
- overlay stayed visible
- ready did not appear
- cancelled match still looks live
- replay UI feels stale

do **not** automatically mean the realtime layer is broken.

Sometimes:
- realtime worked fine
- but authoritative truth never changed

Sometimes:
- authoritative truth changed correctly
- but the current surface never received or rendered it

Sometimes:
- realtime delivered the signal
- but the app mapped the truth incorrectly

This document exists to separate those cases.

## Core Rule

Always ask these questions in order:

1. **Did the authoritative state actually change?**
2. **If yes, did the current surface receive that new truth?**
3. **If yes, did the UI interpret it correctly?**

In short:

**realtime is not the source of truth — it is only one way correct truth reaches the UI**

## The Three-Layer Model

When something looks stale, separate the problem into these layers:

### 1. Truth layer
Did the authoritative lifecycle state, field, or terminal reason actually change?

### 2. Delivery layer
Did the app receive, refetch, or surface that changed truth correctly?

### 3. Mapping layer
Did the UI interpret the updated truth correctly once it had it?

A good diagnosis places the bug in one of these layers.

## What Realtime Is For

Realtime is usually a **delivery mechanism**, not the truth itself.

Its job is typically to:
- notify the app that something changed
- trigger refetch or state reconciliation
- help surfaces converge on updated authoritative truth

Realtime is **not** usually the thing that proves:
- accept succeeded
- cancel succeeded
- match reached ready
- match reached lobby
- match reached in_progress
- replay got created
- terminal reason is correct

Those truths come from authoritative state.

## What Truth Is

Truth means:
- authoritative lifecycle stage
- authoritative remote fields
- authoritative transition completion
- authoritative terminal outcome
- authoritative replay match existence

Examples:
- pending → ready really happened
- ready → lobby really happened
- in_progress really happened
- completed really happened
- cancelled really happened
- expired really happened
- new replay match really exists

If truth is wrong or unchanged, realtime cannot fix that.

## The First Question

Whenever someone says:
- “it didn’t update”
- “the other side never changed”
- “the card is stale”
- “the overlay is stuck”

the first question is:

**Did the authoritative truth actually change?**

If the answer is no:
- this is not a realtime bug
- this is a truth or transition bug

If the answer is yes:
- continue to delivery/realtime diagnosis

This is the single most important rule in this document.

## Truth Bug vs Realtime Bug

### Truth bug
The expected authoritative state never changed.

Examples:
- receiver tapped accept, but authoritative state stayed pending
- join was attempted, but authoritative state stayed ready
- countdown happened visually, but authoritative state never became in_progress
- replay was requested, but no new replay match exists

In these cases, blaming realtime is wrong.  
Realtime cannot deliver a change that never happened.

### Realtime/delivery bug
The authoritative truth changed, but the relevant surface did not converge on it.

Examples:
- receiver sees ready, challenger still sees sent even though authoritative state is ready
- cancelled truth is correct, but overlay still shows actionable replay UI
- one list updated while another stayed stale
- one device converged, the other did not

In these cases, truth is correct and delivery is suspect.

## Mapping Bug vs Realtime Bug

Even if truth changed and the surface received it, the UI can still be wrong.

Examples:
- authoritative state is ready
- relevant view now has ready truth
- but UI still renders sent card

That is not a realtime bug.  
That is a mapping bug.

So the full order is:

1. did truth change?
2. did this surface get the changed truth?
3. if yes, is it rendering it correctly?

## The Realtime Diagnosis Test

Use this test whenever something looks stale.

### Question 1
What authoritative state should be true right now?

### Question 2
Is that state actually true in the authoritative source?

If no:
- truth/transition bug

If yes:
- continue

### Question 3
Did the current surface, list, overlay, or view receive that updated truth?

If no:
- delivery/realtime/refetch bug

If yes:
- continue

### Question 4
Given that updated truth, is the UI correct?

If no:
- mapping bug

That is the core classifier.

## Common Wrong Assumption

A very common wrong assumption is:

- user tapped a button
- UI did not update
- therefore realtime is broken

That is too early.

The button tap proves only that the action was attempted.  
It does **not** prove:
- the transition succeeded
- the authoritative state changed
- the app should already be showing the next state

So never debug from user action straight to realtime blame.

## Common Truth-Before-Realtime Examples

### Example 1 — Accept looks stale

Symptom:
- receiver tapped accept
- challenger still sees sent

First question:
- is the authoritative state now ready?

If no:
- this is a truth/transition bug

If yes:
- maybe delivery or mapping bug

### Example 2 — Join looks stale

Symptom:
- join tapped
- UI still looks ready

First question:
- did authoritative truth actually move into lobby?

If no:
- not a realtime bug

If yes:
- maybe current surface did not update

### Example 3 — Replay looks stale

Symptom:
- replay requested
- replay UI looks wrong

First question:
- was a new authoritative replay match actually created?

If no:
- truth bug

If yes:
- maybe delivery or mapping bug

## Common Delivery/Realtimե Examples

### Example 1 — One side updates, the other does not

Symptom:
- authoritative state is correct
- one player UI changed
- the other player UI did not

This is a strong sign of:
- delivery/realtime/refetch problem
- stale list or stale overlay problem
- one surface not converging on new truth

### Example 2 — One surface updates, another does not

Symptom:
- history/list/overlay disagreement
- one part of the app reflects the new truth
- another part still shows stale actionable UI

This often means:
- truth is correct
- but not all surfaces are receiving or consuming it correctly

### Example 3 — Replay overlay stays stale

Symptom:
- authoritative replay state says it is no longer actionable
- overlay still shows old replay UI

This may be:
- delivery bug
- stale overlay source bug
- stale surface consuming old truth

Not necessarily:
- a truth bug

## Common Mapping-After-Delivery Examples

### Example 1 — Correct truth, wrong card

Symptom:
- authoritative ready is correct
- view has received ready truth
- card still renders sent

This is a mapping bug, not a realtime bug.

### Example 2 — Correct completed truth, wrong terminal presentation

Symptom:
- match is completed
- current surface has updated truth
- UI treats it like hidden removal instead of history/end-game

This is a mapping bug.

### Example 3 — Countdown treated like gameplay

Symptom:
- current surface has lobby truth
- UI behaves like in_progress

Again, mapping bug.

## Realtime Is a Trigger, Not Proof

A good rule of thumb:

Realtime may tell you:
- go check the latest truth

Realtime does not tell you:
- the lifecycle definitely advanced
- the UI definitely should already look different
- the transition definitely succeeded

That distinction matters everywhere in remote flow:
- accept
- cancel
- decline
- ready
- lobby
- countdown
- gameplay start
- replay
- terminal outcomes

## When Realtime Is Probably Not the Problem

Realtime is probably **not** the main problem when:
- authoritative state never changed
- expected lifecycle transition never completed
- role interpretation is wrong
- UI mapping is wrong even with correct current truth
- the same surface consistently misrenders the same state

Those are usually truth or mapping problems first.

## When Realtime/Delivery Probably Is the Problem

Realtime/delivery is more likely when:
- authoritative truth is definitely correct
- one side updated and the other did not
- one list updated and one overlay did not
- stale state survives only on specific surfaces
- the same truth exists but is not reaching all relevant consumers

Even then, the word “realtime” is still slightly too narrow sometimes.

The real bug may be:
- refetch not triggered
- refetch triggered but ignored
- correct state not published to right surface
- stale local cache/list/overlay still being used

So often the better label is:

**delivery bug**

with realtime as one part of delivery.

## The Delivery Checklist

When truth is correct but UI is stale, ask:

1. did the app get a signal that truth changed?
2. did the right refetch/reload happen?
3. did the correct surface subscribe to the updated source?
4. did this list/view/overlay replace stale data with fresh truth?
5. is one surface still reading old local state?
6. is this actually mapping wrong after fresh truth arrived?

This keeps delivery and mapping separate.

## One-Side Updated / Other-Side Stale

This is one of the most important remote debugging patterns.

If:
- one side is correct
- one side is stale

then ask in this order:
1. is authoritative truth correct?
2. is the stale side definitely receiving the new truth?
3. if yes, is the stale side mapping it wrongly?

Do **not** jump straight to:
- “realtime broken”
without checking truth and mapping first.

## Replay-Specific Warning

Replay bugs are especially easy to misclassify as realtime bugs because replay often has:
- extra overlays
- extra visibility rules
- old completed match context
- new replay match lifecycle

So if replay looks stale, first ask:
1. am I looking at old-match UI context or new replay-match truth?
2. did the new replay match actually change as expected?
3. is the replay surface receiving that new truth?
4. is the replay UI mapping it correctly?

That order prevents a lot of wasted debugging.

## Good Questions To Ask

Ask:
- what authoritative truth should be true right now?
- is it actually true?
- if yes, does this surface have the updated truth?
- if yes, is the surface rendering it correctly?
- is this a truth bug, delivery bug, or mapping bug?

These questions produce real diagnosis.

## Bad Questions To Ask

Avoid starting with:
- “should we just force reload every time?”
- “did realtime break again?”
- “can we add another delay?”
- “can we just dismiss the overlay manually?”
- “should we make the card hide faster?”

Those often skip the most important question:
- did truth actually change?

## Good Debug Examples

### Good example: accept looked stale

- expected truth checked: ready
- authoritative truth checked: still pending
- diagnosis: truth/transition bug, not realtime

### Good example: cancel looked stale on one side

- expected truth checked: cancelled/non-actionable
- authoritative truth checked: correct
- challenger updated
- receiver stayed stale
- diagnosis: delivery bug, not truth bug

### Good example: correct truth, wrong UI

- authoritative truth checked: ready
- current surface has updated truth
- UI still renders sent
- diagnosis: mapping bug, not realtime bug

## Relationship to Other Docs

Use this doc when the symptom is basically:

**something didn’t update**

Use it with:
- `remote-debug-order.md` for the full remote debug ladder
- `lifecycle-vs-mapping.md` to distinguish truth bugs from UI interpretation bugs
- `navigation-vs-lifecycle.md` when the stale symptom looks like a route problem
- `evidence-and-logging.md` for what proof to gather
- `remote-match-lifecycle` docs for what the truth should actually be

This doc answers:

**did realtime fail, or did authoritative truth never actually change?**

## Bottom Line

In Dart Freak, stale UI does not automatically mean realtime is broken.

First verify the truth changed.  
Then verify the surface received it.  
Then verify the UI interpreted it correctly.