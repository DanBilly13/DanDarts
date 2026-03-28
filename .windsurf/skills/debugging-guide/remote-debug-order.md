> Supporting reference for: debugging-guide  
> Apply when: debugging remote match bugs in Dart Freak, especially cases involving sent/pending/ready confusion, one-side-updates and the other does not, stale challenge cards, replay bugs, countdown/gameplay start issues, or terminal-state mismatches  
> Do not apply to: local match bugs, pure styling issues, or generic app debugging where the problem is not specifically in remote lifecycle behavior

# Remote Debug Order

## Purpose

This document defines the correct order for debugging **remote-match bugs** in Dart Freak.

Remote bugs are expensive because the visible symptom is often not the real failure.

A bug that looks like:
- wrong card
- stale overlay
- missing button
- broken replay
- lobby not progressing
- gameplay starting too early
- one player updating while the other stays stale

may actually be caused by any of these layers:
- authoritative truth
- lifecycle transition
- role interpretation
- UI mapping
- delivery/update path
- navigation/overlay timing
- stale instance or stale async work

This document exists to force the right diagnostic order before suggesting a fix.

## Core Rule

Debug remote bugs in this order:

1. identify the exact remote lifecycle moment
2. identify the authoritative state that should be true
3. identify the user role
4. identify the expected transition or expected UI mapping
5. identify the authoritative proof that should confirm it
6. identify whether the failure is:
   - lifecycle
   - mapping
   - delivery
   - navigation
   - stale actor
   - terminal interpretation
7. only then suggest code changes

In short:

**remote bugs should be debugged from authoritative lifecycle truth forward, not from the visible card backward**

## The Remote Debug Ladder

Use this exact ladder for remote bugs:

### 1. Lifecycle moment
What exact moment in the remote lifecycle is failing?

### 2. Authoritative state
What remote state should actually be true right now?

### 3. Role
Is this user challenger or receiver?

### 4. Expected result
What should happen next, or what should be visible right now?

### 5. Proof
What authoritative field/result/log should prove that?

### 6. Failure classification
Is this:
- truth
- transition
- mapping
- delivery
- navigation
- stale actor
- terminal interpretation

### 7. Fix
What is the smallest correct change at that layer?

Do not reorder this ladder.

## Step 1 — Identify the Exact Lifecycle Moment

Start by naming the remote moment precisely.

Examples:
- challenge created but receiver never sees pending
- receiver accepted but challenger still sees sent
- ready card appears but join does nothing
- match entered lobby but countdown never starts
- countdown appeared but authoritative state never reached in_progress
- receiver declined but challenger still sees actionable outgoing card
- replay request created but maps to wrong UI
- match completed but vanished instead of moving to history
- expired match still looks actionable

Bad:
- “remote matches are broken”
- “replay is weird”
- “it didn’t update”

Good:
- “pending → ready happened authoritatively, but challenger UI stayed in sent”
- “ready → lobby did not complete after join”
- “lobby sub-phase advanced, but gameplay was shown before authoritative in_progress”
- “decline resolved on receiver side but not on challenger side”

If you cannot name the remote moment precisely, you are debugging too broadly.

## Step 2 — Identify the Authoritative State

Before interpreting the UI, identify the authoritative lifecycle state.

Typical questions:
- is the match pending?
- ready?
- lobby?
- in_progress?
- completed?
- cancelled?
- expired?

Also ask:
- is the thing I am looking at a real persisted stage?
- or only a derived UI phase like sent, countdown, or brief declined presentation?

This is the most important step.

Many remote bugs come from assuming:
- visible card = true lifecycle state
- overlay visible = replay still active
- countdown visible = gameplay already started

That is often wrong.

## Step 3 — Identify the Current User Role

Remote debugging is impossible without role clarity.

Ask:
- is this user the challenger?
- or the receiver?

This matters because the same authoritative state may map differently by role.

Examples:
- pending may map to sent for challenger and pending for receiver
- challenger may be allowed to cancel while receiver is allowed to accept/decline
- role-specific fields may explain why one side is correctly gated while the other is not

A lot of “wrong card” bugs are really “wrong role interpretation” bugs.

## Step 4 — Identify the Expected Result

Now decide what should happen from the authoritative truth and role.

There are two main possibilities:

### Expected transition
Examples:
- pending → ready
- ready → lobby
- lobby → in_progress
- in_progress → completed
- completed → replay creates new match

### Expected mapping
Examples:
- pending + challenger → sent card
- pending + receiver → pending card
- ready → ready card
- lobby → lobby/start-flow screen
- completed → end-game/history, not hidden
- cancelled/expired → not actionable

This step is crucial because some bugs are:
- transition failures
while others are:
- correct transition, wrong UI mapping

## Step 5 — Identify the Authoritative Proof

For the expected transition or state, ask:

- what authoritative result should prove this?
- what field, status, or persisted fact should exist?
- what source should I trust to verify it?

Examples:
- status moved from pending to ready
- status moved from ready to lobby
- lobby-related per-player fields are set
- status moved to in_progress
- completed was recorded
- new replay match was created
- terminal reason is cancelled or expired

Important rule:

A button tap is not proof.  
A local UI change is not proof.  
A route push is not proof.  
The authoritative result is proof.

## Step 6 — Decide Whether This Is a Lifecycle Bug or a Mapping Bug

This is the most important classification step.

### Lifecycle bug
The authoritative remote state is wrong, missing, or never advanced.

Examples:
- accept did not actually move pending to ready
- join did not actually move ready to lobby
- gameplay never actually became in_progress
- replay new match never actually got created
- terminal reason recorded incorrectly

### Mapping bug
The authoritative remote state is correct, but the wrong UI is being shown.

Examples:
- pending still shown after authoritative ready
- challenger still sees sent after correct accept
- completed treated like hidden removal
- countdown shown like gameplay
- replay overlay still visible after replay is no longer actionable

Many remote bugs are mapping bugs, not truth bugs.

Do not confuse them.

## Step 7 — Decide Whether This Is a Delivery Bug

If the authoritative truth is correct and the mapping rules are also clear, ask whether the problem is really delivery/update.

Typical signs:
- one player updated correctly, the other did not
- stale list data still present
- overlay still showing old match state
- correct state exists, but current surface never refreshed into it

This is common in remote flow because the same match truth may need to reach:
- challenger
- receiver
- card lists
- overlays
- active route contexts

### Key rule

A delivery bug means:
- truth changed correctly
- but the current surface did not converge on that truth

That is different from a transition bug.

## Step 8 — Only Then Inspect Navigation / Overlay / Stale Actor Layers

Only after truth, role, transition, mapping, and delivery are understood should you inspect:
- navigation timing
- overlay dismissal timing
- stale view instances
- stale async requests
- route pushes that happened from correct or incorrect lifecycle truth

These layers matter, but they are downstream.

Do not start here unless the lifecycle truth is already clear.

## Remote Bug Classification Guide

Use this fast classifier:

### Truth bug
Authoritative state is wrong.

### Transition bug
Expected stage change never completed.

### Mapping bug
Truth is right, UI interpretation is wrong.

### Delivery bug
Truth is right, but current surface did not update.

### Navigation bug
Route behavior is wrong after truth/mapping should already be known.

### Stale actor bug
Old view or old async request is still acting after ownership changed.

### Terminal interpretation bug
The match is non-actionable, but the app is using the wrong reason or wrong surface behavior.

A strong remote diagnosis names one of these explicitly.

## Debugging by Common Remote Symptoms

## Symptom: “Challenger still sees sent after receiver accepted”

Check in order:
1. did the authoritative state actually move to ready?
2. is the current user correctly treated as challenger?
3. should challenger now still see sent, or should they see ready?
4. if truth is correct, is the mapping wrong?
5. if mapping is correct on paper, is the challenger surface stale?

Usually this is:
- mapping wrong
or
- delivery stale after a correct authoritative change

## Symptom: “Receiver declined, but challenger card stayed live”

Check in order:
1. what authoritative outcome was actually recorded?
2. should the challenger still see any actionable outgoing card?
3. is the decline outcome being interpreted correctly on both sides?
4. did the challenger surface fail to update?

Usually this is:
- cross-player delivery/mapping failure
or
- decline reason/presentation confusion

## Symptom: “Join tapped, but lobby never happened”

Check in order:
1. is the match still authoritatively ready?
2. what authoritative proof should exist if lobby entry succeeded?
3. did that proof ever appear?
4. if yes, is this now a UI/navigation issue?
5. if no, this is a transition/truth issue

Usually this is:
- transition not completed
before it is
- navigation wrong

## Symptom: “Countdown started, but gameplay feels wrong”

Check in order:
1. is the match still authoritatively lobby or already in_progress?
2. is countdown being treated as a lobby sub-phase or as gameplay?
3. should gameplay UI be shown yet?
4. did authoritative in_progress actually happen?

Usually this is:
- stage-vs-sub-phase confusion
or
- premature gameplay mapping

## Symptom: “Completed match disappeared”

Check in order:
1. did the match actually complete?
2. should this surface show end-game/history instead of removal?
3. is this surface incorrectly treating completed like cancelled/expired?
4. is it a mapping bug rather than a transition bug?

Usually this is:
- terminal-state mapping wrong

## Symptom: “Replay is broken”

Check in order:
1. am I reasoning about the old completed match or the new replay match?
2. was a new replay match actually created?
3. what lifecycle stage is that new replay match in?
4. what should requester see vs recipient see?
5. is replay being treated like shortcut gameplay instead of new lifecycle entry?
6. only then inspect replay overlay or replay navigation timing

Usually replay bugs come from:
- mixing old-match context with new-match lifecycle truth

## Good Remote Debug Questions

Ask:
- what stage is the match really in?
- is that stage persisted or only presented?
- what role is the current user?
- what should that role see from this truth?
- what authoritative result should prove the transition?
- is the truth wrong, or only the UI mapping?
- did one side update and the other fail to converge?
- is this replay old-match context or new-match lifecycle?

These questions produce useful diagnosis.

## Bad Remote Debug Questions

Avoid starting with:
- “can we just hide the card?”
- “should we force refresh more often?”
- “should we add a delay?”
- “can we just treat this as cancelled?”
- “maybe the replay overlay should dismiss sooner”
- “can we just push the next screen when it looks ready?”

Those are often symptom patches, not diagnoses.

## Logging Rule for Remote Debugging

Good logs for remote bugs should show:
- authoritative stage/status
- player role
- expected transition
- authoritative proof of transition
- correct/incorrect UI mapping
- terminal reason where relevant
- whether one side updated and the other did not

Weak logs only show:
- button taps
- screen appearances
- route pushes
- card visibility

Those are useful, but not enough to debug remote lifecycle correctly.

## Relationship to Other Docs

Use this doc when the bug is specifically in remote match behavior.

Use it with:
- `debug-order-overview.md` for the general app-wide ladder
- `lifecycle-vs-mapping.md` to separate truth bugs from UI interpretation bugs
- `realtime-vs-truth.md` when the symptom is “didn’t update”
- `navigation-vs-lifecycle.md` when the symptom looks route-related
- `evidence-and-logging.md` for what proof to gather
- `remote-match-lifecycle` skill docs for how the feature is supposed to behave

This doc answers:

**what order should I debug remote-match bugs in?**

## Bottom Line

Do not debug remote bugs from the visible card backward.

Debug them from authoritative lifecycle truth, role, and expected transition forward.