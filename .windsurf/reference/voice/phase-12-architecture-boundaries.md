# Phase 12 — Architecture Boundaries and Invariants
## Peer-to-Peer Voice Chat for Remote Matches

## Purpose

This document defines the implementation boundary for peer-to-peer voice chat in Remote Matches before any Phase 12 code is written.

It exists to prevent the failures seen in the first attempt, where voice work destabilized otherwise-stable remote gameplay. The purpose of this document is to make voice a strictly subordinate, flow-owned feature that cannot interfere with remote match navigation, state progression, or gameplay reliability.

---

## Core Principle

**Voice is a remote-flow feature, not a screen feature.**

Voice must be owned by the shared remote match flow layer, not by `RemoteLobbyView`, `RemoteGameplayView`, `RemoteGameEndView`, or any other individual SwiftUI screen.

Voice must survive normal in-flow navigation:

- Lobby -> Gameplay
- Gameplay -> End Game
- End Game -> Replay

Normal screen transitions are not exits.

---

## 1. Ownership Model

### Voice owner

Voice is owned at the **flow layer**, specifically by the remote match flow authority, centered around:

- `RemoteMatchService` 

This means:

- voice session state belongs to the active remote flow
- voice survives view recreation and navigation transitions inside that flow
- SwiftUI views only render voice state and invoke safe public commands
- SwiftUI views do not own voice lifecycle

### What voice may observe

Voice may observe remote-flow state such as:

- active `matchId` 
- active `flowMatchId` 
- current remote match status
- challenger / receiver identities
- flow entry / exit
- current flow validity

### What voice must never do

Voice must **not**:

- push or pop navigation
- call router transitions
- mutate remote match state
- alter accept / join / start-match logic
- block lobby countdown
- block gameplay
- decide whether match flow may continue
- become the source of truth for remote match lifecycle

### Lifecycle authority

Voice lifecycle is controlled by **remote flow lifecycle hooks**, not by arbitrary screen lifecycle events.

That means:

- the flow layer decides when voice may start
- the flow layer decides when voice must end
- a screen `onAppear` may request or observe voice state, but does not own it
- a screen `onDisappear` must not be treated as voice teardown authority unless it corresponds to a true remote-flow exit

---

## 2. Lifecycle Boundaries

## Voice starts

Voice may start only when the remote flow reaches a **stable lobby state**.

The canonical initial start condition is:

- receiver has accepted the challenge
- join flow has completed
- the match is in a stable lobby state
- the active remote flow is valid
- the flow layer determines that voice is allowed to bootstrap

Voice must **not** start:

- during the accept edge call
- during the join edge call
- during router transition
- during unstable pending/ready/lobby churn
- from raw SwiftUI screen construction alone
- from a transient `onAppear` before flow validity is confirmed

## Voice stays alive

Once validly started, voice remains alive throughout the same remote flow during:

- lobby countdown
- gameplay
- end game
- replay, if replay remains part of the same remote flow

Normal in-flow screen transitions must not end voice.

## Voice terminates

Voice terminates only on **true flow exit** or explicit failure/termination conditions.

Canonical termination conditions:

- either player exits back to main games tab
- remote flow truly exits (`exitRemoteFlow()` or equivalent)
- match is abandoned / cancelled
- match expires
- remote flow fails validation and is terminated
- disconnect / teardown rules explicitly require shutdown

## Critical lifecycle rule

**Normal screen transitions are not exits.**

The following are **not** valid teardown triggers by themselves:

- Lobby `onDisappear` 
- Gameplay `onDisappear` 
- End Game `onDisappear` 
- Replay view transitions
- SwiftUI view rebuilds
- route changes within the same remote flow

Only true flow exit may terminate voice.

---

## 3. Non-Negotiable Invariants

These invariants apply to every Phase 12 task.

## 3.1 Flow subordination

Voice is subordinate to the remote match flow.

Rules:

- remote match state always wins
- remote navigation always wins
- voice may observe flow state but never mutate it
- voice failure must never block or delay match progression
- gameplay must continue even if voice fails, drops, or never connects

## 3.2 Session identity protection

Voice session identity must be protected by more than `matchId`.

A valid voice session must also be associated with session identity/versioning such as:

- session token, generation, or UUID
- active flow instance identity
- ownership version or lifecycle generation

This is required to prevent:

- stale async callbacks mutating current session state
- delayed teardown clearing a newer valid session
- cross-match contamination
- repeated start/stop races corrupting state

## 3.3 Navigation safety

Voice may not drive navigation.

Rules:

- signalling callbacks cannot push/pop screens
- peer connection callbacks cannot push/pop screens
- voice state changes cannot trigger router transitions
- voice UI updates cannot interfere with match navigation

## 3.4 State honesty

Voice UI must reflect actual engine state.

Rules:

- no optimistic "connected" state before real justification
- "silent failure" means no disruptive alert, not fake success
- unavailable must be shown honestly when connection fails
- UI must not imply voice success when engine is idle or failed

## 3.5 Feature independence

Remote matches must remain fully playable with voice disabled.

Rules:

- voice-disabled mode behaves exactly like pre-Phase-12 remote matches
- signalling/audio/peer connection work must be fully bypassable
- voice feature failure must not damage core remote match flow

## 3.6 Idempotent lifecycle

Voice start and stop operations must be safe to call repeatedly.

Rules:

- repeated `startSession()` for same active session is a no-op
- repeated `endSession()` for already-ended session is a no-op
- duplicated lifecycle triggers must not corrupt ownership

## 3.7 View independence

Voice cannot depend on one particular view instance remaining alive.

Rules:

- view rebuilds must not create duplicate voice sessions
- view disappearance inside the same flow must not tear down voice
- screen-local lifecycle churn must not destabilize voice ownership

## 3.8 No voice authority over match progression

Voice must never become a prerequisite for starting or continuing a match.

Rules:

- no gating of lobby countdown on voice connection
- no gating of gameplay turn system on voice status
- no gating of replay or end-game transitions on voice status

---

## 4. Integration Points (Read-Only)

Voice may observe remote flow state from the existing flow model.

Primary integration points include concepts represented by:

### From `RemoteMatchService` 

- `isInRemoteFlow: Bool` 
- `flowMatchId: UUID?` 
- `flowMatch: RemoteMatch?` 
- remote flow entry hooks
- remote flow exit hooks
- internal flow depth / active flow ownership concepts

### From `RemoteMatch` 

- `status` 
- `challengerId` 
- `receiverId` 
- `currentPlayerId` 

## Critical constraint

Voice is a **read-only observer** of these values.

Voice must not modify:

- remote match status
- current player
- match progression
- accept/join/start transitions
- router path
- flow ownership state

---

## 5. Technical Direction

## Phase 12 scope

Phase 12 is:

- peer-to-peer voice chat for remote matches
- STUN-first
- Supabase Realtime signalling
- iOS WebRTC audio transport
- `AVAudioSession` configured for voice chat usage

Phase 12 explicitly does **not** include:

- TURN relay
- automatic reconnect
- architecture changes to remote match flow
- any coupling that makes voice mandatory for matches

## TURN-ready requirement

TURN is deferred, but Phase 12 must remain TURN-ready.

This means:

- signalling contract must support future ICE expansion cleanly
- session model must allow alternate connection paths later
- connection state machine must not assume STUN-only forever
- nothing in Phase 12 should require re-architecting ownership to add TURN later

---

## 6. Failure Behavior

## Non-blocking principle

Voice failure must never block match flow.

If voice fails:

- lobby countdown continues
- gameplay continues
- end game continues
- replay continues
- user can still complete the match normally

## Honest status principle

Voice failure must be shown honestly but calmly.

Expected UX states include:

- Preparing voice...
- Connecting voice...
- Voice ready
- Voice not available

Rules:

- no disruptive blocking alert for standard connection failure
- no fake success UI
- unavailable may persist for the remainder of the active flow in Phase 12
- no automatic reconnect in this phase unless later re-scoped

---

## 7. UI Placement Rules

## Control placement

Voice control appears in the **top-left** of:

- Lobby
- Gameplay

Help affordance remains top-right.

## Symbols

Use SF Symbols:

- `microphone` 
- `microphone.slash` 

## Visual hierarchy

Voice control is secondary to primary gameplay UI.

Rules:

- muted state must be clearly readable
- connecting may use subtle pulse
- unavailable must appear calm, not dramatic
- control must not visually compete with scoring or primary gameplay actions

---

## 8. State Model Preview

Detailed state design belongs to Task 2, but the required boundary is established here.

Required states include:

- `idle` 
- `preparing` 
- `connecting` 
- `connected` 
- `muted` 
- `unavailable` / `failed` 
- `ended` 

Required identity protections include:

- match association
- flow association
- session generation / token / version protection

Muted is local-only for Phase 12 unless explicitly re-scoped.

---

## 9. Required Safety Mechanisms

These are required architecture protections, not optional polish.

## 9.1 Feature flag / kill switch

Voice must be globally disable-able.

When disabled:

- no signalling subscriptions
- no audio session work
- no peer connection creation
- remote matches behave exactly like pre-Phase-12 baseline

## 9.2 Session versioning

Each active voice session must have versioned identity protection.

Purpose:

- stale callbacks must not mutate newer session state
- delayed teardown must not clear a newer active session
- repeated async completions must be safely ignored if obsolete

## 9.3 Idempotency

Voice lifecycle APIs must be idempotent.

Purpose:

- repeated start/stop requests remain harmless
- duplicate lifecycle triggers do not destabilize ownership

## 9.4 Flow-safe ownership

Voice belongs to the active remote flow, not to any one screen.

Purpose:

- view rebuilds do not duplicate session ownership
- `onAppear` / `onDisappear` churn does not destabilize session state
- lobby -> gameplay transition does not tear down voice

---

## 10. What This Task Does Not Include

This task is documentation only.

It does not implement:

- voice state model details
- service shell
- signalling contract
- WebRTC engine
- UI controls
- audio session code
- peer connection code

Those belong to later tasks.

---

## Approval Checkpoint

Task 1 is complete only when the following are explicitly accepted:

- voice is owned by `RemoteMatchService` / remote flow layer, not by views
- lifecycle boundaries are flow-level, not screen-level
- normal screen transitions are not exits
- voice is subordinate to remote match flow and cannot mutate it
- safety mechanisms are required, not optional
- remote matches must remain fully playable with voice disabled
- the invariants in this document are treated as non-negotiable for all later Phase 12 work

---

## Summary

This document establishes the foundational contract for Phase 12:

- voice is flow-owned
- voice is non-blocking
- voice is read-only with respect to remote match flow
- voice cannot control navigation
- voice must survive normal in-flow transitions
- only true remote-flow exit may terminate voice
- safety/versioning/idempotency are mandatory from the start

Any later implementation that violates these boundaries should be rejected or revised before proceeding.
