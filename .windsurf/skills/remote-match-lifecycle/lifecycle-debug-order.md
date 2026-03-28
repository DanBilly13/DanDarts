> Supporting reference for: remote-match-lifecycle  
> Apply when: debugging any remote match bug where the lifecycle seems wrong, the wrong card is shown, one player updates and the other does not, a match gets stuck between stages, or a remote match disappears, starts, or ends incorrectly  
> Do not apply to: local match bugs, pure styling issues, or generic realtime/navigation debugging unless the root problem is remote lifecycle interpretation

# Lifecycle Debug Order

## Purpose

This document defines the correct order for debugging remote match lifecycle bugs in Dart Freak.

The goal is to stop random guessing.

When a remote match bug appears, it is very easy to jump straight to:
- the visible card
- a stale overlay
- a missing button
- a router push
- a realtime event
- “the UI is wrong”

That is usually too shallow.

The correct approach is to debug from:

**authoritative stage → role → allowed transition → authoritative proof → UI mapping**

not from the visible symptom alone.

## Core Rule

Debug remote lifecycle bugs in this order:

1. what exact lifecycle moment is failing?
2. what authoritative stage is the match really in?
3. what role is the current user?
4. what transition was supposed to happen next?
5. what authoritative proof should confirm that transition?
6. what should each side be seeing from that truth?
7. only then inspect realtime, navigation, or UI timing details

Do not skip steps.

## Why Order Matters

A remote lifecycle bug can come from very different causes:

- wrong authoritative stage assumption
- role confusion
- wrong action allowed for the role
- correct DB truth but wrong UI mapping
- correct transition on one side but stale UI on the other
- replay being mistaken for old-match continuation
- terminal reason confusion
- UI disappearance being mistaken for lifecycle truth

If you start from the visible symptom, you can easily fix the wrong layer.

## Step 1 — What Exact Lifecycle Moment Is Failing?

Start by naming the lifecycle moment precisely.

Examples:
- challenge created but receiver never sees pending
- receiver accepted but challenger still sees sent
- ready match never progresses to lobby
- lobby reached but gameplay never starts
- receiver declined but challenger card stayed live
- replay request created but mapped to the wrong UI
- match completed but disappeared instead of moving to history
- expired challenge still appears actionable

Be exact.

Bad:
- “remote matches are broken”

Good:
- “pending → ready happened authoritatively, but challenger UI stayed in sent”
- “ready → lobby never happened after join”
- “cancel resolved for challenger but not receiver”

If you cannot name the lifecycle moment precisely, you will debug too broadly.

## Step 2 — What Authoritative Stage Is the Match Really In?

Before looking at the UI, identify the real lifecycle stage.

Ask:
- is the match pending?
- ready?
- lobby?
- in_progress?
- completed?
- cancelled?
- expired?
- decline-resolved in some implementation-specific way?

Also ask:
- is this a real persisted stage?
- or only a derived UI/presentation phase?

This is the most important step.

Many lifecycle bugs come from assuming the UI is telling the truth about stage when it is actually only showing a presentation layer.

## Step 3 — What Role Is the Current User?

Once the authoritative stage is clear, identify the current user’s role.

Ask:
- is this user the challenger?
- or the receiver?

This matters because the same authoritative stage may map differently by role.

Examples:
- pending may show as sent for challenger and pending for receiver
- early actions may be cancel for challenger vs accept/decline for receiver
- role-specific fields may explain why one side should progress differently

A lot of “wrong UI” bugs are really “wrong role interpretation” bugs.

## Step 4 — What Transition Was Supposed To Happen Next?

Now identify the expected lifecycle transition.

Examples:
- challenge creation → pending presentation
- pending → ready after accept
- pending → non-actionable after decline
- pending → non-actionable after cancel
- ready → lobby after join
- lobby → in_progress after readiness/countdown/start conditions
- in_progress → completed after gameplay end
- completed → replay request creates new replay match

Be clear about:
- what transition was expected
- whether it actually happened
- whether the system is stuck before, during, or after it

This prevents a common mistake:
seeing wrong UI and assuming the transition failed, when it may actually have succeeded and only the mapping is wrong.

## Step 5 — What Authoritative Proof Should Confirm That Transition?

For the expected transition, ask:

- what authoritative state change should prove it?
- what field/status/timestamp/result should exist if the transition succeeded?
- what source should I trust to verify it?

Examples:
- status moved from pending to ready
- status moved from ready to lobby
- per-player lobby-entered/readiness fields now exist
- status moved to in_progress
- terminal outcome recorded as completed/cancelled/expired
- new replay match exists

This step is critical because a lot of remote bugs come from confusing:
- user action
with
- authoritative transition completion

A tap is not proof.  
A route change is not proof.  
A label change is not proof.  
The authoritative result is proof.

## Step 6 — What Should Each Side Be Seeing From That Truth?

Only after you know the authoritative truth should you map the expected UI.

Ask:
- what should challenger see from this stage?
- what should receiver see from this stage?
- should the match still be actionable?
- should it be in sent/pending/ready/active/history/hidden?
- should there be a brief terminal presentation?
- should the overlay dismiss?
- should the card fade?

This step catches one of the most common bug classes:

**the authoritative lifecycle is correct, but the state-to-UI mapping is wrong**

## Step 7 — Is This a Lifecycle Bug or a Mapping Bug?

At this point, classify the failure.

### Lifecycle bug
Examples:
- authoritative stage never changed
- wrong terminal reason recorded
- match never really reached ready/lobby/in_progress
- replay new match never got created

### Mapping bug
Examples:
- authoritative stage is correct, but wrong card shown
- one side sees outdated sent/pending UI
- completed match hidden like a cancelled card
- countdown shown as gameplay too early
- overlay still visible after authoritative non-actionable truth

This is a crucial distinction.

Do not debug a mapping bug like a server transition bug.  
Do not debug a transition bug like a copy/layout issue.

## Step 8 — Only Then Check Realtime / Navigation / Timing Layers

Once you know:
- the correct lifecycle stage
- the correct role
- the expected transition
- the authoritative proof
- the correct UI mapping

only then inspect whether the problem is being caused by:
- stale realtime-driven refresh
- stale service arrays
- wrong navigation timing
- overlay dismissal timing
- fade timing
- stale view instance
- delayed UI cleanup

These layers matter, but they are downstream.

They should not be your starting point for lifecycle debugging.

## The Standard Lifecycle Debug Ladder

Use this exact ladder:

### 1. Lifecycle moment
What exact remote lifecycle moment is failing?

### 2. Authoritative stage
What stage is the match really in?

### 3. Role
Is the user challenger or receiver?

### 4. Expected transition
What should have happened next?

### 5. Authoritative proof
What field/result should prove that it happened?

### 6. Correct UI mapping
What should each side now see?

### 7. Bug type
Is this a lifecycle bug or a mapping bug?

### 8. Delivery/timing layer
Only now check realtime, navigation, overlay timing, fade timing, or stale instance issues.

Do not reorder this ladder.

## Debugging by Symptom

## Symptom: “Challenger still sees sent after receiver accepted”

Check in order:
1. did the authoritative stage really move from pending to ready?
2. is the current user correctly treated as challenger?
3. should challenger now still see sent, or should they see ready?
4. is this a mapping bug or did the authoritative transition fail?
5. only then check whether one side’s data refresh is stale

Usually this is either:
- mapping wrong
- or one side failed to refresh after a correct authoritative change

## Symptom: “Receiver declined and their card disappeared, but challenger still sees the outgoing card”

Check in order:
1. what authoritative result was actually recorded for the decline?
2. should the challenger still see anything actionable from that result?
3. is the challenger UI mapping stale?
4. is the decline being treated as presentation-only on one side and terminal on the other?
5. only then inspect realtime/list refresh timing

Usually this is a cross-player mapping/update problem, not a stage-definition problem.

## Symptom: “Ready match never reaches lobby”

Check in order:
1. is the match still authoritatively ready?
2. did the expected ready → lobby transition actually happen?
3. what authoritative proof should exist if lobby entry succeeded?
4. is the UI still showing ready because the transition failed, or because it is not being mapped/refreshed correctly?
5. only then inspect join flow timing or navigation timing

Usually this is a transition-proof problem before it is a navigation problem.

## Symptom: “Countdown started but gameplay seems wrong”

Check in order:
1. is the match still authoritatively lobby, or already in_progress?
2. is countdown being shown as a lobby sub-phase or incorrectly mapped as gameplay?
3. did authoritative in_progress actually happen?
4. should gameplay UI be shown yet?
5. only then inspect navigation timing or stale route behavior

Usually this is a stage-vs-sub-phase confusion bug.

## Symptom: “Completed match disappeared instead of showing end-game/history”

Check in order:
1. did the authoritative state really become completed?
2. is the match being treated like a terminal removal instead of successful completion?
3. should the current surface map completed to end-game/history instead of hidden?
4. is this a completed-vs-cancelled/expired mapping mistake?

Usually this is a terminal-state mapping bug.

## Symptom: “Replay feels broken”

Check in order:
1. am I looking at the old completed match or the new replay match?
2. was a new authoritative replay match actually created?
3. what stage is the new replay match in?
4. what should requester see vs recipient see?
5. is replay being treated like shortcut gameplay instead of new lifecycle entry?
6. only then inspect replay overlay or replay navigation timing

Usually replay bugs come from mixing old-match context and new-match lifecycle truth.

## Good Debug Questions

Ask questions like:
- what stage is the match really in?
- is that stage persisted or only presented?
- what role is this user?
- what should that role see now?
- what authoritative proof would confirm the transition?
- is the truth wrong, or is the UI mapping wrong?
- is the match terminal, or merely hidden from this surface?

These questions isolate the real layer of failure.

## Bad Debug Questions

Avoid starting with:
- “why is this card blue?”
- “should we add a delay?”
- “can we just hide it?”
- “should we force a reload every time?”
- “can we just treat this as cancelled?”
- “maybe ready should behave like gameplay?”

Those questions are too downstream and often hide the real lifecycle issue.

## Logging Rule for Lifecycle Debugging

Good logs should support the lifecycle debug ladder directly.

You want logs that show:
- authoritative stage/value
- role
- transition attempt
- authoritative proof of transition
- UI mapping result
- terminal reason where relevant

If logs only show:
- button tap
- card visible
- onAppear
- reload happened
- push happened

then lifecycle debugging will be slow and expensive.

## Relationship to Other Docs

This doc is about the **order of diagnosis**.

Use it with:
- `lifecycle-stages.md` for canonical stage reasoning
- `challenger-vs-receiver-rules.md` for role asymmetry
- `create-accept-decline-cancel.md` for early challenge-phase transitions
- `ready-lobby-gameplay-flow.md` for start-flow reasoning
- `expiry-and-terminal-states.md` for terminal meanings
- `authoritative-state-and-ui-mapping.md` for UI interpretation
- `replay-lifecycle-rules.md` for replay-specific lifecycle behavior

Those docs explain the rules.  
This doc explains how to find which rule broke.

## What Good Looks Like

Good lifecycle debugging has this property:

**you can point to the exact broken layer — stage, role, transition, proof, or mapping — instead of only describing the visual symptom**

That is the standard.

## Bottom Line

Do not debug remote lifecycle from the card backward.

Debug it from authoritative stage truth forward.