

# remote-matches-current-context-phase-12-voice-chat

## Project Overview

This project adds and stabilizes **Remote Matches** in an existing iOS darts app that already supports **Local Matches**.

A remote match is a turn-based asynchronous game backed by Supabase and existing remote-flow infrastructure. The app already supports:

- creating remote challenges
- accepting and joining matches
- playing remote turns with server-authoritative state
- showing end game and match history
- replaying from remote end game
- loading history lazily for performance

The next phase adds **peer-to-peer voice chat** for remote matches on iOS.

---

## Product Context

The app is a darts product with both local and remote play.

Relevant gameplay contexts:

- **Local matches**
  - same-device play
  - no voice feature in this phase

- **Remote matches**
  - asynchronous / remote multiplayer flow
  - lobby
  - gameplay
  - end game
  - replay
  - voice feature applies here only

Current remote game types already in active use include:

- Remote 301
- Remote 501

The broader app also supports non-remote game types such as:

- 301
- 501
- Knockout
- Killer
- Halve It
- Sudden Death

Voice in phase 12 is explicitly scoped to **remote matches only**.

---

## Current Status Before Phase 12

Recent phases achieved the following:

### Remote match history
- history list moved to lazy loading
- list uses lightweight summaries
- full detail is loaded on demand
- detail caching exists
- end-game and history-tab pipelines are now much more aligned

### Remote gameplay flow
- lobby → gameplay → end game → replay flow is functioning
- remote match lifecycle ownership is already a core concept in the codebase
- flow state and teardown behavior matter a lot
- navigation correctness has already been a major source of bugs, so new features should attach to the shared flow layer, not individual screens

### Important lesson from previous phases
A feature that appears “small” can become large if it is attached to the wrong layer.

That lesson directly applies to voice:
- **voice must be owned by the remote match flow**
- it must **not** be attached to a single screen

---

## Phase 12 Goal

Add **peer-to-peer voice chat for remote matches on iOS**.

Players should be able to talk during a remote match, continue talking through end game and replay, and have voice terminate only when either player exits the remote match context entirely.

---

## Core Architectural Rule

### Voice is a remote-flow feature, not a screen feature

Voice must belong to the **shared remote match flow layer** so it survives:

- lobby
- gameplay
- end game
- replay

It must not be owned by an individual SwiftUI screen.

This is the most important implementation rule for phase 12.

---

## Technical Direction

Phase 12 uses:

- **Supabase Realtime** for signalling
- **STUN-based direct WebRTC connectivity**
- **iOS audio session / voice chat configuration**

Phase 12 is intentionally:

- **STUN-first**
- **non-blocking**
- **TURN-ready**
- **no automatic reconnect**

TURN is not part of this phase, but the signalling/session design must allow TURN to be added later without rearchitecting the feature.

---

## Voice Lifecycle Rules

### Voice starts
- when the receiver enters the lobby after accepting the challenge

### Voice stays alive
- in lobby
- during gameplay
- on end game
- during replay

### Voice terminates
- when either player exits to the main games tab
- when either player abandons or disconnects
- when the remote match flow ends unexpectedly
- when existing remote disconnect handling tears the flow down

### Critical rule
Voice teardown must use the **same remote-flow lifecycle hooks and disconnect handling** as the rest of the remote match system.

Do not build a separate parallel disconnect system for voice.

---

## UX Rules for Phase 12

### Voice control placement
Use a compact voice control placed in the **top-left**.

Keep the existing help affordance on the **top-right**.

This applies to:
- lobby
- gameplay

### Icon language
Use SF Symbols:

- `microphone`
- `microphone.slash`

The control must read immediately as:
- voice
- mute
- unavailable voice state

Avoid symbols that look like:
- refresh
- reconnect
- retry
- sync

### Lobby status line
Under **Players Ready**, show an honest voice state line:

- **Connecting voice...**
- **Voice ready**
- **Voice not available**

This status line is important because it gives feedback without blocking the match.

### Failure behavior
If voice fails:
- match still starts normally
- no disruptive alert
- UI must still reflect the real state honestly
- voice failure must never block or delay countdown or match start

### Reconnect behavior
For phase 12:
- if voice drops, gameplay continues normally
- no automatic reconnect attempt
- show unavailable/disconnected honestly for the rest of that match flow

---

## Background Audio Rules

Voice should continue when the device screen locks during a remote match.

Requirements include:
- correct background audio capability
- correct AVAudioSession setup
- correct interruption handling
- correct route-change handling

This is not just a UI feature. It has audio-session and lifecycle implications.

---

## Implementation Strategy

Phase 12 has already been broken into a sequential task list with strict approval gates.

Rule:
- **the next task can only start after the previous task has been approved**

The work is divided into these sub-phases:

- **Sub-phase A — Foundation**
- **Sub-phase B — Signalling**
- **Sub-phase C — Voice Engine**
- **Sub-phase D — UI and Flow Integration**
- **Sub-phase E — End-to-End Lifecycle**
- **Sub-phase F — Validation and Polish**

These sub-phases are also intended to be natural git-push / review checkpoints.

---

## Key Product/Engineering Constraints

- iOS only
- remote matches only
- no new paid voice service for initial release
- no voice for local same-device matches
- no group voice
- no push-to-talk
- no recording
- no remote mute sync
- no TURN in phase 12
- no auto-reconnect in phase 12

---

## Success Criteria

Phase 12 is successful when:

- players can hear each other during a remote match
- on normal mobile networks, voice usually connects before the 5 second countdown ends
- lobby shows accurate voice status under Players Ready
- the control is top-left and help remains top-right
- the control uses clear microphone-based icon language
- mute correctly reflects local mute state
- the UI never shows a false connected state
- voice survives lobby → gameplay → end game → replay
- voice terminates for both players when either exits the remote flow
- voice failure never blocks or delays match start
- audio continues when the screen locks
- the design remains TURN-ready for a later reliability phase

---

## Important Implementation Warnings

### 1. Do not attach voice to a single view
This is the easiest way to create lifecycle bugs.

### 2. Do not let voice affect match progression
Voice is additive only. Remote match state always wins.

### 3. Do not show fake “connected” UI
Silent failure means “no disruptive alert,” not “pretend success.”

### 4. Keep the control visually secondary
It must not compete with primary gameplay controls like Save Score.

### 5. Keep phase 12 limited
TURN and reconnect are reliability follow-ups, not part of this scope.

---

## Relevant Phase 12 Documents

These docs already exist and should be treated as the main written references for this phase:

### Main phase proposal
`reference/voice/phase-12-peer-to-peer-voice-chat-remote-matches.md`

### Sequential task list
`reference/voice/phase-12-voice-chat-task-list.md`

These appear to live in the project reference area under:

- `reference/voice/`

This is a sensible home for the current phase documents and should be kept consistent.

---

## Suggested Working Convention for This Phase

When implementing phase 12:

1. check the main phase proposal first
2. follow the task list in strict order
3. stop for approval at each checkpoint
4. use sub-phase boundaries as likely git-push moments
5. do not begin later UI/lifecycle tasks before foundation/signalling work is approved

---

## One-Line Summary

**Phase 12 adds non-blocking, STUN-first, peer-to-peer voice chat to the shared remote match flow on iOS, with top-left microphone controls, honest status UI, and lifecycle ownership above individual screens.**
