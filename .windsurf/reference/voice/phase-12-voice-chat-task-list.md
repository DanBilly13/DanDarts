# Phase 12 — Peer-to-Peer Voice Chat for Remote Matches
## Sequential Task List

**Rule:** Each task must be completed, reviewed, and approved before the next task begins.  
**Purpose:** Keep implementation controlled, reviewable, and safe for git push checkpoints.

---

## Structure

This phase is split into sub-phases so there are natural review points and clean git push moments.

- **Sub-phase A — Foundation**
- **Sub-phase B — Signalling**
- **Sub-phase C — Voice Engine**
- **Sub-phase D — UI and Flow Integration**
- **Sub-phase E — End-to-End Lifecycle**
- **Sub-phase F — Validation and Polish**

---

# Sub-phase A — Foundation

## Task 1 — Define architecture boundaries
Document the implementation boundary before coding:
- voice is owned by the remote match flow, not any individual screen
- voice survives lobby → gameplay → end game → replay
- voice terminates when either player exits the remote match flow
- phase 12 is STUN-only
- TURN is not implemented now, but the design must remain TURN-ready

**Approval checkpoint:** Architecture ownership and lifecycle rules agreed.

---

## Task 2 — Define the voice session state model
Create the voice session state model and enums, without wiring to UI yet.

Include:
- idle
- connecting
- connected
- muted
- unavailable / failed
- ended

Also define:
- local mute state
- whether voice is available
- whether the current session belongs to the currently active remote match
- whether the session is allowed to remain alive across replay

**Approval checkpoint:** State model reviewed and accepted.

---

## Task 3 — Create the service shell
Create the shared voice service / manager that will own the voice session for the remote match flow.

This task should only establish:
- the service object
- ownership model
- dependency injection plan
- public interface shape

No real signalling or WebRTC connection yet.

**Approval checkpoint:** Service shape approved.

**Suggested git push point**

---

# Sub-phase B — Signalling

## Task 4 — Define signalling message contract
Define the signalling payloads sent over Supabase Realtime.

Include:
- offer
- answer
- ICE candidate
- disconnect / teardown
- any minimal match/session identifiers needed to prevent cross-match contamination

Keep the contract minimal and TURN-ready.

**Approval checkpoint:** Signalling contract approved before implementation.

---

## Task 5 — Implement signalling send/receive layer
Implement the Supabase Realtime signalling path in isolation.

This task should cover:
- publishing signalling messages
- receiving signalling messages
- filtering to the active match only
- safely ignoring stale or foreign messages
- disconnect signalling

Do not yet connect actual audio.

**Approval checkpoint:** Signalling layer tested and approved.

---

## Task 6 — Wire lobby-side signalling entry points
Attach signalling start points to the existing remote flow:
- receiver enters lobby → may create/send offer
- challenger enters lobby → may receive/send answer

Still keep this at signalling level only. No full audio validation yet.

**Approval checkpoint:** Lobby signalling flow reviewed.

**Suggested git push point**

---

# Sub-phase C — Voice Engine

## Task 7 — Configure audio session correctly
Implement AVAudioSession configuration for voice chat.

Include:
- correct category / mode
- interruption handling hooks
- route-change handling hooks
- background audio expectations for locked screen behavior

No UI work yet.

**Approval checkpoint:** Audio session configuration reviewed.

---

## Task 8 — Create peer connection wrapper
Implement the WebRTC peer connection wrapper.

Include:
- peer connection setup
- local audio track setup
- remote audio handling
- STUN server configuration
- hooks for later TURN support

Do not yet fully bind it to match flow.

**Approval checkpoint:** Peer connection layer approved.

---

## Task 9 — Connect signalling to peer connection
Join Sub-phase B and C:
- signalling offer/answer drives peer connection
- ICE candidate exchange works
- connection state updates feed the voice state model

At this stage, aim for a functioning technical connection, even if UI is still minimal.

**Approval checkpoint:** Basic connection path demonstrated and approved.

**Suggested git push point**

---

# Sub-phase D — UI and Flow Integration

## Task 10 — Add lobby voice status line
Add the lobby voice status line underneath “Players Ready”.

States:
- Connecting voice...
- Voice ready
- Voice not available

Rules:
- honest state only
- no blocking
- no disruptive alert
- countdown behavior unchanged

**Approval checkpoint:** Lobby status UX approved.

---

## Task 11 — Add top-left voice control in lobby
Add the compact voice control to the **top-left** of lobby.

Use SF Symbols:
- `microphone`
- `microphone.slash`

Help remains top-right.

Behavior:
- local mute toggle
- state-driven icon appearance
- connecting / connected / muted / unavailable treatment

**Approval checkpoint:** Lobby control placement and state behavior approved.

---

## Task 12 — Add top-left voice control in gameplay
Carry the same control into gameplay, in the same top-left position.

Goals:
- consistent placement
- no interference with scoring UI
- same state model as lobby
- same mute behavior

**Approval checkpoint:** Gameplay control approved.

**Suggested git push point**

---

# Sub-phase E — End-to-End Lifecycle

## Task 13 — Persist voice across gameplay → end game → replay
Ensure the voice session survives navigation changes inside the same remote match flow.

Must remain active through:
- gameplay
- end game
- replay

Replay should be treated as continuing inside the same voice session.

**Approval checkpoint:** Cross-screen continuity approved.

---

## Task 14 — Implement clean teardown on remote flow exit
Terminate voice when:
- either player exits to main games tab
- either player abandons
- remote match flow ends unexpectedly
- disconnect handling triggers teardown

This must use the same remote-flow lifecycle hooks, not a separate parallel mechanism.

**Approval checkpoint:** Teardown behavior approved.

---

## Task 15 — Implement failure behavior for phase 12 scope
Finalize the non-blocking failure rules:
- voice failure never blocks match start
- dropped voice does not affect gameplay
- no automatic reconnect in phase 12
- unavailable state is shown honestly for the remainder of the match flow

**Approval checkpoint:** Failure behavior approved.

**Suggested git push point**

---

# Sub-phase F — Validation and Polish

## Task 16 — Locked-screen and interruption validation
Test and refine:
- screen lock behavior
- app backgrounding expectations
- phone call interruption behavior
- Siri / audio interruption handling
- route changes

This task is for validation and fixes only, not architecture changes.

**Approval checkpoint:** Audio lifecycle validation signed off.

---

## Task 17 — Stabilize visual states and transitions
Polish UI behavior:
- no flicker in icon state transitions
- subtle pulse only for connecting
- muted state clearly readable
- unavailable state calm, not dramatic
- control remains visually quieter than primary gameplay actions

**Approval checkpoint:** Final UI polish approved.

---

## Task 18 — End-to-end QA pass
Run a full sequential QA pass covering:
- receiver accepts
- challenger joins
- lobby voice state
- match start
- gameplay mute/unmute
- end game continuation
- replay continuation
- exit teardown
- failure path
- locked-screen continuity

Document any follow-up items separately.

**Approval checkpoint:** Phase 12 implementation accepted.

**Suggested final git push point**

---

# Notes for Implementation

- Do not start a new task before approval of the previous one.
- Do not collapse multiple tasks into one implementation step without approval.
- If a task reveals architectural problems, stop and resolve them before continuing.
- TURN support is not part of phase 12, but no phase-12 decision should block TURN from being added later.
- Reconnect logic is explicitly deferred unless re-scoped later.

---

# Expected Review Rhythm

A healthy cadence would be:
- complete 2–3 tasks
- review
- approve
- git push

That keeps progress visible without making branches too large or too noisy.
