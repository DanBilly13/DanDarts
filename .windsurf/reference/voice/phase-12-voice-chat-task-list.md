# Phase 12 — Peer-to-Peer Voice Chat for Remote Matches  
## Sequential Task List (Revised v2)

**Rule:** Each task must be completed, reviewed, and approved before the next task begins.  
**Purpose:** Keep implementation controlled, reviewable, and safe for git push checkpoints.

**Critical protection rule for this phase:**  
Voice must never destabilize remote matches. If a task causes any regression in accept/join/lobby/gameplay/navigation, stop immediately and revert or isolate the change before continuing.

---

## New Non-Negotiable Invariants

These are hard rules for every task in this phase:

- voice is subordinate to remote match flow and must never control it
- voice may observe remote flow state, but may not mutate navigation or remote match state
- normal in-flow screen transitions are **not** exits
- `Lobby -> Gameplay -> End Game -> Replay` must not tear down voice by themselves
- voice startup must be idempotent
- voice teardown must be idempotent
- stale async callbacks must not mutate a newer session
- a delayed teardown must never clear a newer active session
- remote matches must remain fully playable with voice disabled
- phase 12 is STUN-only
- TURN is not implemented now, but nothing in phase 12 may block TURN later
- no reconnect logic in phase 12 unless explicitly re-scoped later

---

## Required Safety Mechanisms

These are not optional polish items. They are core implementation constraints:

- **Feature flag / kill switch:** voice can be disabled without affecting remote flow
- **Session identity model:** voice session must be protected by more than just `matchId`
- **Flow-safe ownership:** voice belongs to the active remote flow, not any one SwiftUI view
- **Version-safe teardown:** old teardown cannot destroy a newer session
- **No navigation side effects from voice:** signalling / peer callbacks cannot push/pop screens
- **No optimistic UI lying:** “ready” only when truly justified by engine state

---

## Structure

This phase is split into sub-phases so there are natural review points and clean git push moments.

- **Sub-phase A — Foundation and Safety Rails**
- **Sub-phase B — Signalling**
- **Sub-phase C — Voice Engine**
- **Sub-phase D — UI and Flow Integration**
- **Sub-phase E — Flow-Lifecycle Hardening**
- **Sub-phase F — Validation and Polish**

---

# Sub-phase A — Foundation and Safety Rails

## Task 1 — Define architecture boundaries and invariants
Document the implementation boundary before coding.

Must explicitly state:
- voice is owned by the remote match flow, not any individual screen
- voice survives lobby -> gameplay -> end game -> replay
- voice terminates only when the user truly leaves the remote flow, or when disconnect/failure rules require teardown
- normal screen disappearance inside the same flow is not exit
- voice cannot push/pop navigation
- voice cannot mutate remote match state
- remote flow remains authoritative; voice is secondary and non-blocking
- phase 12 is STUN-only
- TURN is deferred, but design must remain TURN-ready

**Approval checkpoint:**  
Architecture ownership, lifecycle boundaries, and non-negotiable invariants agreed.

---

## Task 2 — Define the voice session identity and state model
Create the voice session model and enums, without wiring to UI yet.

Include:
- idle
- preparing
- connecting
- connected
- muted
- unavailable / failed
- ended

Also define:
- local mute state
- whether voice is available
- whether current session belongs to the active remote match
- whether current session belongs to the active remote flow instance
- whether session may persist across replay
- session generation / token / ownership version for stale-callback protection

Must explicitly define:
- repeated `startSession()` for same active session is a no-op
- repeated `endSession()` is a no-op
- stale async work must be ignored if session generation no longer matches

**Approval checkpoint:**  
State model and identity/versioning model reviewed and accepted.

---

## Task 3 — Create the service shell with safety rails only
Create the shared voice service / manager.

This task should establish only:
- service object
- ownership model
- dependency injection plan
- public interface shape
- idempotent start/stop contract
- generation/version guard shape
- feature flag / kill switch shape

No real signalling or WebRTC connection yet.

**Approval checkpoint:**  
Service shape approved, with idempotency and stale-callback defenses designed.

**Suggested git push point**

---

## Task 4 — Add a voice feature flag / kill switch
Implement a development-safe way to disable all voice behavior.

Requirements:
- disabling voice must leave remote matches untouched
- voice-disabled mode must not subscribe, signal, configure audio, or create peer connections
- remote accept/join/lobby/gameplay must behave exactly as before phase 12

This exists to protect the remote baseline while building.

**Approval checkpoint:**  
Voice can be turned off and remote matches still behave exactly like pre-phase-12 baseline.

---

# Sub-phase B — Signalling

## Task 5 — Define signalling message contract
Define the signalling payloads sent over Supabase Realtime.

Include:
- offer
- answer
- ICE candidate
- disconnect / teardown
- match identifier
- session identifier / generation identifier
- sender identity
- minimum filtering fields needed to reject stale, foreign, or cross-match messages

Keep the contract minimal and TURN-ready.

Must explicitly protect against:
- cross-match contamination
- stale session contamination
- duplicate delivery side effects

**Approval checkpoint:**  
Signalling contract approved before implementation.

---

## Task 6 — Implement signalling send/receive layer in isolation
Implement the Supabase Realtime signalling path in isolation.

This task should cover:
- publishing signalling messages
- receiving signalling messages
- filtering to active match only
- filtering to active session generation only
- ignoring stale / foreign / duplicate messages safely
- disconnect signalling

Do not yet connect actual audio.

Must explicitly guarantee:
- signalling events cannot alter navigation
- signalling events cannot alter remote match state
- repeated subscription attempts for same active session are harmless

**Approval checkpoint:**  
Signalling layer tested and approved in isolation.

---

## Task 7 — Wire lobby-side signalling entry points without audio
Attach signalling start points to the existing remote flow:

- receiver enters stable lobby state -> may create/send offer
- challenger enters stable lobby state -> may wait for offer / send answer

Important:
- not during accept edge call
- not during join edge call
- not during router transition
- not during unstable state bouncing between pending/ready/lobby

Still keep this signalling-only. No audio validation yet.

**Approval checkpoint:**  
Lobby-side signalling entry points reviewed and confirmed not to destabilize remote flow.

**Suggested git push point**

---

# Sub-phase C — Voice Engine

## Task 8 — Configure audio session correctly
Implement AVAudioSession configuration for voice chat.

Include:
- correct category / mode
- interruption hooks
- route-change hooks
- background / locked-screen expectations
- activation / deactivation rules

Must explicitly define:
- audio session setup failure cannot break match flow
- audio session teardown cannot run just because a view disappeared inside the same flow

No UI work yet.

**Approval checkpoint:**  
Audio session configuration reviewed and confirmed non-blocking.

---

## Task 9 — Create peer connection wrapper
Implement the WebRTC peer connection wrapper.

Include:
- peer connection setup
- local audio track setup
- remote audio handling
- STUN server configuration
- hooks for future TURN
- safe close / teardown path

Must explicitly guarantee:
- wrapper can be created once per active session
- duplicate creation attempts are safely rejected/no-op
- closed wrapper cannot emit state into a newer session

Do not yet fully bind it to match flow.

**Approval checkpoint:**  
Peer connection layer approved.

---

## Task 10 — Connect signalling to peer connection
Join Sub-phase B and C:

- signalling offer/answer drives peer connection
- ICE candidate exchange works
- connection state updates feed the voice state model
- stale message/session protection remains in force

At this stage, aim for a functioning technical connection, even if UI is still minimal.

Must explicitly verify:
- signalling does not affect remote navigation
- peer callbacks do not affect remote match state
- failed connection leaves match flow intact

**Approval checkpoint:**  
Basic technical connection demonstrated and approved.

**Suggested git push point**

---

# Sub-phase D — UI and Flow Integration

## Task 11 — Add lobby voice status line
Add the lobby voice status line underneath “Players Ready”.

States:
- Preparing voice...
- Connecting voice...
- Voice ready
- Voice unavailable

Rules:
- honest state only
- no blocking
- no disruptive alert
- countdown behavior unchanged
- no optimistic “ready” before real justification
- unavailable must not imply match failure

**Approval checkpoint:**  
Lobby voice status UX approved.

---

## Task 12 — Add top-left voice control in lobby
Add the compact voice control to the top-left of lobby.

Use SF Symbols:
- `microphone`
- `microphone.slash`

Help remains top-right.

Behavior:
- local mute toggle only
- state-driven icon appearance
- connecting / connected / muted / unavailable treatment
- no extra navigation side effects
- no duplicate startup from view refreshes/rebuilds

**Approval checkpoint:**  
Lobby control placement and state behavior approved.

---

## Task 13 — Add top-left voice control in gameplay
Carry the same control into gameplay, in the same top-left position.

Goals:
- consistent placement
- no interference with scoring UI
- same state model as lobby
- same mute behavior
- gameplay entry must not restart or tear down an already-valid session

This task must explicitly prove the earlier bug is prevented:
- lobby disappearing during gameplay push must not end voice

**Approval checkpoint:**  
Gameplay control approved, and lobby -> gameplay transition confirmed safe.

**Suggested git push point**

---

# Sub-phase E — Flow-Lifecycle Hardening

## Task 14 — Persist voice across lobby -> gameplay -> end game -> replay
Ensure the voice session survives navigation changes inside the same remote match flow.

Must remain active through:
- lobby
- gameplay
- end game
- replay

Replay should be treated according to explicit flow rules:
- if replay remains inside the same remote flow, voice session persists
- if replay creates a truly new flow identity, a fresh session is allowed only by explicit design

Must explicitly verify:
- screen disappearance is not treated as exit
- recreated SwiftUI views do not create duplicate sessions
- `onAppear` / `onDisappear` churn does not destabilize session ownership

**Approval checkpoint:**  
Cross-screen continuity approved.

---

## Task 15 — Implement clean teardown on true remote flow exit
Terminate voice when:
- either player exits to main games tab
- either player abandons
- remote match flow ends unexpectedly
- disconnect handling requires teardown
- explicit end-of-flow route is reached

This must use remote-flow lifecycle hooks, not arbitrary screen lifecycle hooks.

Must explicitly protect against:
- lobby `onDisappear` ending voice during gameplay push
- delayed teardown from old screen clearing current session
- end-game/replay transitions being mistaken for flow exit

**Approval checkpoint:**  
Teardown behavior approved.

---

## Task 16 — Implement failure behavior for phase 12 scope
Finalize the non-blocking failure rules:

- voice failure never blocks match start
- dropped voice does not affect gameplay
- no automatic reconnect in phase 12
- unavailable state is shown honestly for the remainder of the flow unless user explicitly re-enters a fresh flow
- failure in audio/signalling/peer setup must not mutate remote match state

Must explicitly define what happens when failure occurs during:
- lobby startup
- gameplay
- replay
- teardown

**Approval checkpoint:**  
Failure behavior approved.

**Suggested git push point**

---

# Sub-phase F — Validation and Polish

## Task 17 — Locked-screen and interruption validation
Test and refine:
- screen lock behavior
- app backgrounding expectations
- phone call interruption behavior
- Siri / audio interruption handling
- route changes

This task is for validation and fixes only, not architecture changes.

Must explicitly verify that interruption handling:
- does not break remote navigation
- does not falsely trigger full flow exit
- does not clear a live session unless required by rules

**Approval checkpoint:**  
Audio lifecycle validation signed off.

---

## Task 18 — Stabilize visual states and transitions
Polish UI behavior:
- no flicker in icon state transitions
- subtle pulse only for connecting
- muted state clearly readable
- unavailable state calm, not dramatic
- control remains visually quieter than primary gameplay actions
- no false transitions caused by transient screen rebuilds

**Approval checkpoint:**  
Final UI polish approved.

---

## Task 19 — Regression-proof end-to-end QA pass
Run a full sequential QA pass covering:
- baseline remote match flow with voice feature flag OFF
- receiver accepts
- challenger joins
- lobby voice state
- gameplay mute/unmute
- lobby -> gameplay continuity
- gameplay -> end game continuity
- replay continuity
- back to games teardown
- abandon / unexpected exit teardown
- failure path
- locked-screen continuity
- stale teardown protection
- duplicate start/stop safety

Document any follow-up items separately.

**Approval checkpoint:**  
Phase 12 implementation accepted.

**Suggested final git push point**

---

# Notes for Implementation

- Do not start a new task before approval of the previous one.
- Do not collapse multiple tasks into one implementation step without approval.
- If a task reveals architectural problems, stop and resolve them before continuing.
- TURN support is not part of phase 12, but no phase-12 decision should block TURN from being added later.
- Reconnect logic is explicitly deferred unless re-scoped later.
- Every git checkpoint should verify that remote matches still work with voice disabled.
- Any task that touches navigation, flow ownership, or teardown requires extra regression testing before approval.

---

# Expected Review Rhythm

A healthy cadence would be:
- complete 1–2 tasks when touching lifecycle / teardown / navigation
- complete 2–3 tasks when work is isolated and low-risk
- review
- approve
- git push

That keeps progress visible without allowing voice work to silently destabilize remote matches.
