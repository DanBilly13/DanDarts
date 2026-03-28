> Supporting reference for: remote-match-lifecycle  
> Apply when: starting work on remote match behavior and needing the high-level mental model before changing detailed stage logic, player-role behavior, or UI mapping  
> Do not apply to: local match flow, generic realtime architecture, or deep implementation details where a stage-specific reference is more appropriate

# Remote Match Overview

## Purpose

This document gives the high-level mental model for remote matches in Dart Freak.

It exists so lifecycle work starts from the right frame:

**a remote match is not just a game screen with network sync.**  
It is a staged, server-authoritative workflow with asymmetric player behavior and derived client presentation.

If that mental model is wrong, the detailed lifecycle logic will usually drift too.

---

## Core Mental Model

A remote match in Dart Freak is an **asynchronous, server-authoritative match flow** between two players:

- challenger
- receiver

The match progresses through a sequence of lifecycle stages stored and derived from authoritative remote match state.

The client does not invent the lifecycle.  
The client observes it, requests valid transitions, and presents it appropriately for each player.

---

## Remote vs Local

This is the most important boundary.

### Local match
A local match is primarily client-owned gameplay flow.

### Remote match
A remote match is a **shared lifecycle system** with:
- challenge creation
- role asymmetry
- list/card presentation
- lobby progression
- readiness/countdown gates
- gameplay start
- completion / replay / terminal handling

Use `supabase-patterns` for server-authoritative write rules, `realtime-patterns` for subscription/refetch handling, and this skill for the lifecycle model that sits between them.

---

## Database-Authoritative Lifecycle

The remote match lifecycle is anchored in authoritative remote state.

That means:
- the lifecycle stage is not defined by what card is visible
- the lifecycle stage is not defined by which screen the user is currently on
- the lifecycle stage is not defined by what one client believes should happen next

Instead:
- authoritative match fields define the real stage
- the client derives UI from that truth
- the client may request transitions, but does not own the stage model

This is the foundation of all remote lifecycle reasoning.

---

## UI Is Derived, Not Primary

One of the easiest mistakes is to reason from the UI first.

For example:
- “the challenger sees a sent card, so the match must be in sent state”
- “the receiver sees pending, so the match is pending for them only”
- “the replay overlay still exists, so the replay must still be active”

That is backwards.

The correct order is:

1. what authoritative stage is the match in?
2. what player role is viewing it?
3. what UI should be derived from that combination?

The UI is an effect, not the source of truth.

---

## Same Match, Different UI

Remote matches are intentionally asymmetric.

That means the same authoritative match can produce different UI for:

- challenger
- receiver

Typical examples:
- one authoritative state may show as **sent** for challenger and **pending** for receiver
- both may see **ready**, but the surrounding context may differ
- terminal outcomes may disappear immediately, fade briefly, or move to history depending on context

This asymmetry is normal.  
It is not automatically a bug.

So lifecycle work must always ask:

**which player is looking at this state?**

---

## Remote Lifecycle Is Staged

A remote match is not just:

challenge → game → done

It usually moves through multiple stages such as:
- challenge creation / waiting
- accepted / ready
- lobby entry
- readiness/countdown gating
- active gameplay
- completion or other terminal outcomes
- replay creation/entry

That staged structure matters because bugs often come from:
- skipping a stage mentally
- collapsing two distinct stages into one
- assuming a visible UI implies later lifecycle progress than the server has actually confirmed

---

## Role of the Client

The client has an important role, but it is not the lifecycle owner.

The client should:
- render the correct UI for the current stage and player role
- let the user perform actions that are valid for that stage
- request valid transitions
- refetch/re-render based on authoritative state
- avoid inventing lifecycle meaning locally

The client should not:
- derive business truth from presentation state
- skip authoritative stage checks
- treat local convenience as lifecycle truth
- assume “the next obvious UI state” means the transition already happened

---

## Role of Server-Owned Transitions

Remote lifecycle transitions are typically owned by server-backed logic:
- edge functions
- RPC-backed gameplay writes
- authoritative DB field changes
- server-owned expiry/validation logic

This matters because a client action such as:
- accept
- cancel
- join
- confirm readiness
- start flow

is not the same thing as a completed lifecycle transition.

The real transition is only proven when authoritative state changes accordingly.

---

## Challenge Stage vs Start Stage

It helps to think of remote lifecycle in two broad halves:

### 1. Challenge lifecycle
This covers:
- creation
- waiting
- sent/pending asymmetry
- accept/decline/cancel
- ready state

### 2. Match-start lifecycle
This covers:
- lobby eligibility
- lobby entry
- ready/view-entered/voice-ready gates
- countdown/start gating
- gameplay start

A lot of bugs happen because code treats the start-stage flow like it begins immediately at acceptance.

It does not.

Acceptance and gameplay are separated by important intermediate lifecycle rules.

---

## Replay Reuses the Lifecycle, But Is Still Special

Replay is not a completely separate lifecycle model.

Most of the broad lifecycle logic still applies:
- challenge-like creation
- ready state
- lobby entry
- gameplay progression
- terminal handling

But replay is still special because it may begin from:
- end-game context
- replay overlays
- replay-specific ownership and visibility rules
- replay-specific race conditions and UI issues

So replay should be treated as:
- same broad lifecycle family
- special-case entry and handling rules

not as:
- ordinary first-time remote flow
- or a totally separate product

---

## Terminal States Matter

Not all “ended” outcomes mean the same thing.

Remote matches may end or disappear from actionable UI because of things like:
- completion
- cancellation
- decline behavior
- expiry
- replay replacement or removal behavior
- hidden/non-actionable states

So lifecycle logic must distinguish:
- authoritative terminal reason
- expected UI result
- whether the match moves to history, fades, disappears, or remains visible in another context

Do not reduce all non-active outcomes to one generic “done” concept.

---

## The Most Important Questions

When working on remote lifecycle behavior, keep coming back to these questions:

1. what authoritative stage is the match really in?
2. which player is viewing it?
3. what UI should that role see for that stage?
4. what actions are valid right now?
5. what server-owned transition should happen next?
6. what authoritative state change would prove that it really happened?

These questions prevent most lifecycle drift.

---

## Common Wrong Mental Models

Avoid these:

### Wrong: “the card state is the lifecycle”
Card state is presentation, not the lifecycle source of truth.

### Wrong: “both players should always see the same thing”
Not true. Remote flow is role-asymmetric by design.

### Wrong: “accept means the match is basically started”
Not true. There are more lifecycle gates after acceptance.

### Wrong: “replay is just a second copy of the same match”
Not true. Replay reuses the lifecycle family, but has its own entry/ownership issues.

### Wrong: “if the UI looks ready, it is ready”
Not necessarily. Authoritative state decides that.

---

## What This Overview Is For

Use this overview when:
- starting lifecycle work
- trying to understand why remote is different from local
- explaining the feature to another developer
- resetting to the right model before looking at stage-specific rules

Then move to the more specific docs:
- `lifecycle-stages.md`
- `challenger-vs-receiver-rules.md`
- `create-accept-decline-cancel.md`
- `ready-lobby-gameplay-flow.md`
- `authoritative-state-and-ui-mapping.md`

This document is the mental foundation, not the detailed rulebook.

---

## Bottom Line

A remote match in Dart Freak is a staged, database-authoritative workflow.

The lifecycle is authoritative.  
The UI is derived.  
The player role matters.  
And every transition should be reasoned from server-backed stage truth first.