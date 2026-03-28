> Supporting reference for: debugging-guide  
> Apply when: debugging Dart Freak bugs where it is unclear whether the problem is the authoritative lifecycle itself or only the UI interpretation of that lifecycle, especially wrong cards, wrong list placement, wrong actions, stale-looking surfaces, or one-side-correct / one-side-wrong remote behavior  
> Do not apply to: local-only UI bugs, pure styling/copy issues, or cases where the authoritative state is already confirmed to be wrong and the problem is clearly not a mapping issue

# Lifecycle vs Mapping

## Purpose

This document explains one of the most important debugging distinctions in Dart Freak:

**is the lifecycle truth wrong, or is the UI mapping wrong?**

A lot of wasted debugging time comes from confusing these two.

For example:
- the UI shows the wrong card
- one player still sees sent
- a completed match disappears
- countdown looks like gameplay
- a replay overlay stays visible

Those symptoms do **not** automatically mean the lifecycle is wrong.

Sometimes:
- the authoritative lifecycle is correct
- but the UI is interpreting it incorrectly

This document exists to make that distinction explicit.

## Core Rule

Always ask these two questions separately:

1. **What is the authoritative state really?**
2. **Given that state, is the UI mapping it correctly?**

In short:

**wrong truth and wrong interpretation are different bugs**

Do not fix one as if it were the other.

## What Is a Lifecycle Bug?

A lifecycle bug means the underlying authoritative match progression is wrong.

Examples:
- a match should have moved from pending to ready, but did not
- a match should be in lobby, but is still ready
- a match should be in_progress, but never authoritatively started
- a match should be completed, but terminal truth was never recorded
- a replay match should have been created, but no new match exists

In a lifecycle bug:
- the source-of-truth stage is wrong, missing, or stale
- the UI may actually be rendering correctly from bad truth

## What Is a Mapping Bug?

A mapping bug means the authoritative lifecycle is correct, but the visible UI derived from it is wrong.

Examples:
- authoritative state is ready, but challenger still sees sent
- authoritative state is completed, but the match is treated like hidden removal
- authoritative state is lobby, but the UI still behaves like a challenge card
- authoritative state is pending, but both users are shown the same role-insensitive card
- authoritative state is correct, but actions/buttons do not match that state

In a mapping bug:
- truth is right
- interpretation is wrong

## Why This Distinction Matters

If you mistake a mapping bug for a lifecycle bug, you will often:
- change the wrong server/client transition logic
- add unnecessary refetches
- blame realtime incorrectly
- add delays or reloads that mask the real issue

If you mistake a lifecycle bug for a mapping bug, you will often:
- patch the UI to match incorrect truth
- hide the symptom instead of fixing progression
- create inconsistent behavior across surfaces
- make one screen “look right” while the rest of the app stays wrong

So this distinction is not academic.  
It changes what code should be touched.

## The Diagnosis Test

Use this simple test:

### Question 1
Is the authoritative lifecycle state correct?

If no:
- this is a lifecycle bug

If yes:
- continue

### Question 2
Given that correct state, role, and surface, is the current UI what it should be?

If no:
- this is a mapping bug

That is the core classifier.

## Lifecycle Truth Comes First

Never classify a bug as mapping until you first confirm the authoritative state.

This is the correct order:

1. verify authoritative stage/status/truth
2. verify user role
3. verify current UI surface
4. verify what the correct UI should be
5. compare expected UI to actual UI

That is how you separate:
- incorrect progression
from
- incorrect presentation

## Common Lifecycle Bugs

These usually mean the lifecycle itself is wrong:

### Pending → Ready never happened
- receiver accepted
- but authoritative state stayed pending

### Ready → Lobby never happened
- join action occurred
- but authoritative truth never advanced into lobby/start-flow

### Lobby → In Progress never happened
- countdown or readiness looked close
- but authoritative in_progress never actually happened

### Replay match never created
- replay requested
- but no new replay match exists

### Wrong terminal reason
- match should be completed, but is marked/categorized as cancelled or expired
- or vice versa

These are truth/progression problems.

## Common Mapping Bugs

These usually mean truth is correct but interpretation is wrong:

### Ready shown as sent
- authoritative state is ready
- challenger UI still uses outgoing waiting card

### Completed shown as hidden
- authoritative state is completed
- UI treats it like a cancelled/expired removal instead of history/end-game

### Lobby shown as challenge list item
- authoritative state is lobby
- UI still acts like the match belongs in ready/pending card surfaces

### Countdown shown like gameplay
- authoritative state is still lobby
- UI behaves as if gameplay already started

### Role-insensitive pending UI
- authoritative pending is correct
- but both players are shown the same card/action set

These are interpretation problems.

## Lifecycle Bug Examples

### Example 1 — Accept did not advance the match

Symptom:
- receiver taps accept
- challenger still sees sent

Wrong conclusion:
- “challenger mapping is broken”

Better first question:
- did the authoritative state actually move from pending to ready?

If no:
- lifecycle bug

If yes:
- mapping or delivery bug

### Example 2 — Gameplay never really started

Symptom:
- countdown happened
- something about gameplay looks wrong

Wrong conclusion:
- “gameplay screen bug”

Better first question:
- did the authoritative lifecycle actually become in_progress?

If no:
- lifecycle bug

If yes:
- maybe mapping/navigation/delivery bug

## Mapping Bug Examples

### Example 1 — One side still sees sent after correct accept

Symptom:
- receiver accepted
- authoritative truth is ready
- receiver sees ready
- challenger still sees sent

This is not a lifecycle bug anymore.  
It is most likely:
- mapping bug
or
- delivery/update bug

### Example 2 — Completed match treated like terminal disappearance

Symptom:
- gameplay ended normally
- authoritative truth is completed
- UI removes the match as if it were cancelled/expired

That is usually a mapping bug:
- completed truth is correct
- surface interpretation is wrong

## Lifecycle vs Mapping by Layer

### Lifecycle layer answers:
- what stage is the match really in?
- what authoritative transition happened?
- what terminal reason is real?
- did the new replay match actually get created?

### Mapping layer answers:
- what card should be shown?
- what list should it be in?
- what actions should be available?
- should it be visible, hidden, faded, in history, or in an active route?
- what should challenger see vs receiver see?

If your question starts with:
- “what should it show?”
that is usually mapping.

If your question starts with:
- “what is it really?”
that is usually lifecycle.

## Role Matters in Mapping

A lot of mapping bugs are actually role-mapping bugs.

Examples:
- pending + challenger should show sent
- pending + receiver should show pending
- same authoritative state, different UI

So if the lifecycle truth is correct but the UI looks wrong, check:
- is the current user role being interpreted correctly?
- is the mapping flattening challenger/receiver into one shared model?

A role bug often looks like a mapping bug because it is one.

## Surface Matters in Mapping

The same authoritative lifecycle state may map differently by surface.

Examples:
- completed in history
- completed in end-game context
- cancelled in a list
- cancelled in an overlay
- lobby in active flow
- pending in outgoing vs incoming lists

So after confirming the lifecycle truth, also ask:
- which surface is rendering this state?

A surface mismatch can create a mapping bug even when the lifecycle is correct.

## Terminal-State Confusion

Terminal bugs are especially easy to misclassify.

Examples:
- card disappeared
- overlay dismissed
- item left actionable lists

Those symptoms do **not** tell you whether the lifecycle bug is:
- completed
- cancelled
- expired
- decline-resolved

First verify the terminal reason.  
Then verify whether the UI maps that reason correctly.

Otherwise you will confuse:
- lifecycle truth
with
- presentation outcome

## Replay Confusion

Replay bugs are also often misclassified.

Common mistake:
- old completed match context and new replay match lifecycle get mixed together

Examples:
- replay overlay still visible
- replay request card looks wrong
- replay seems to skip stages

The right order is:
1. am I looking at the old match or the new replay match?
2. what authoritative lifecycle state is the new replay match in?
3. is the UI mapping that replay state correctly?

That prevents a lot of replay debugging confusion.

## Delivery vs Mapping

Sometimes truth is correct and the mapping rules are also correct on paper, but the screen is still wrong because the latest truth never reached that surface.

That is a **delivery bug**, not purely a mapping bug.

Typical signs:
- one user updated correctly, the other did not
- one list updated, another did not
- overlay still shows stale data after truth changed

So once you confirm:
- lifecycle is correct
- intended mapping is correct

ask one more question:
- did this surface actually receive and render the latest truth?

That tells you whether the issue is:
- mapping
or
- delivery

## The Fast Classifier

Use this quick classifier:

### Step 1
Verify authoritative lifecycle truth.

If wrong:
- lifecycle bug

If correct:
- continue

### Step 2
Verify correct expected UI for:
- role
- surface
- temporary presentation rules

If actual UI differs:
- mapping bug

If expected mapping is right on paper but current surface did not update:
- delivery bug

This is the simplest reliable split.

## Good Questions To Ask

Ask:
- what is the match really, authoritatively?
- what role is this user?
- what surface is showing this?
- given that truth, what should this role see here?
- is the state wrong, or only the interpretation wrong?
- if the interpretation rules are correct, did this surface simply fail to update?

These questions separate the layers properly.

## Bad Questions To Ask

Avoid starting with:
- “can we just change the label?”
- “can we just hide the card?”
- “maybe ready should behave like gameplay”
- “should we make sent and pending the same?”
- “why does this screen not feel right?”

Those questions blur lifecycle and mapping together too early.

## Good Debug Examples

### Good example: ready but wrong card

- authoritative state checked: ready
- role checked: challenger
- expected UI: ready card, not sent
- actual UI: sent
- diagnosis: mapping bug

### Good example: accept never completed

- authoritative state checked: still pending
- receiver tapped accept, but no authoritative advancement
- diagnosis: lifecycle/transition bug

### Good example: correct truth, stale surface

- authoritative state checked: cancelled
- intended mapping: removed from actionable UI
- one surface updated, another still shows live card
- diagnosis: delivery bug, not lifecycle bug

## Relationship to Other Docs

Use this doc when the main debugging question is:

**is the truth wrong, or is the UI interpretation wrong?**

Use it with:
- `remote-debug-order.md` for the full remote-specific debug ladder
- `realtime-vs-truth.md` when the symptom is “didn’t update”
- `navigation-vs-lifecycle.md` when the symptom looks like a route problem
- `evidence-and-logging.md` for what proof to gather
- `remote-match-lifecycle` docs for how the feature is supposed to behave

This doc answers:

**how do I distinguish a lifecycle bug from a mapping bug?**

## Bottom Line

In Dart Freak, a wrong UI does not automatically mean wrong lifecycle truth.

First verify what the match really is.  
Then verify whether the UI is interpreting that truth correctly.