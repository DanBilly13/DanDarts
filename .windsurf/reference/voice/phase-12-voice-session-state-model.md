# Phase 12 — Voice Session Identity and State Model
## Task 2: State Model Definition

## Purpose

This document defines the voice session state model and identity protection mechanisms for Phase 12 peer-to-peer voice chat.

It establishes the state machine, session identity model, and safety contracts that will be implemented in Task 3 (service shell) and used throughout all subsequent voice implementation tasks.

---

## 1. Voice Session State Enum

### VoiceSessionState

```swift
enum VoiceSessionState: String, Equatable {
    case idle
    case preparing
    case connecting
    case connected
    case muted
    case unavailable
    case ended
}
```

### State Definitions

**`idle`**
- Initial state before any voice session has been requested
- No signalling active
- No audio session configured
- No peer connection exists
- Voice UI shows nothing or disabled state

**`preparing`**
- Voice session has been requested but not yet started
- May be configuring audio session
- May be validating flow state
- Not yet signalling
- Transient state before `connecting`

**`connecting`**
- Signalling active (offer/answer exchange in progress)
- ICE candidate exchange may be in progress
- Audio session configured
- Peer connection created but not yet established
- UI shows "Connecting voice..." with subtle pulse

**`connected`**
- Peer connection established
- Audio streams active
- Both players can hear each other
- Microphone is open (not muted)
- UI shows microphone icon (unmuted state)

**`muted`**
- Peer connection still established
- Audio streams still active
- Local microphone is muted
- Other player cannot hear this player
- This player can still hear other player
- UI shows microphone.slash icon
- **Note:** Mute is local-only in Phase 12 (no remote mute sync)

**`unavailable`**
- Voice connection failed or dropped
- Signalling may have failed
- Peer connection may have failed
- ICE negotiation may have failed
- Audio session may have failed
- Match continues normally (non-blocking)
- UI shows dimmed mic icon with unavailable treatment
- **Phase 12:** No automatic reconnect, state persists for remainder of flow

**`ended`**
- Voice session has been explicitly terminated
- Signalling stopped
- Peer connection closed
- Audio session deactivated
- Occurs on true remote flow exit
- Terminal state for this session instance

---

## 2. Session Identity Model

### VoiceSessionIdentity

A voice session must be uniquely identified by more than just `matchId` to prevent stale callbacks and cross-session contamination.

```swift
struct VoiceSessionIdentity: Equatable {
    let matchId: UUID
    let sessionToken: UUID
    let createdAt: Date
}
```

### Fields

**`matchId: UUID`**
- The remote match this session belongs to
- Links session to specific match flow
- Used for signalling channel subscription

**`sessionToken: UUID`**
- Unique token for this specific session instance
- Generated fresh on each `startSession()` call
- Used to reject stale async callbacks
- Prevents delayed teardown from clearing newer session

**`createdAt: Date`**
- Timestamp when session was created
- Useful for debugging and logging
- Can help identify session age in diagnostics

### Identity Protection Contract

**Rule 1: Token Validation**
- All async callbacks must validate `sessionToken` matches current active session
- If token doesn't match, callback is stale and must be ignored
- Example: Signalling message arrives for old session after new session started

**Rule 2: Generation Comparison**
- Teardown operations must check session token before clearing state
- If current session token differs from teardown token, abort teardown
- Prevents old teardown from destroying new session

**Rule 3: Match Association**
- Session is only valid if `matchId` matches current `flowMatchId`
- If flow exits and re-enters with different match, old session is invalid
- Prevents cross-match contamination

---

## 3. Session Ownership and Validity

### Active Session Concept

At any given time, there is at most **one active voice session** per remote flow.

```swift
// Conceptual model (actual implementation in Task 3)
private(set) var activeSession: VoiceSessionIdentity?
```

### Session Validity Rules

**A session is valid if:**
1. `activeSession` is not nil
2. `activeSession.matchId` equals current `flowMatchId`
3. Remote flow is active (`isInRemoteFlow == true`)
4. Session state is not `.ended`

**A session becomes invalid when:**
- Remote flow exits (`exitRemoteFlow()` called)
- Match changes (different `flowMatchId`)
- Session is explicitly ended
- Match is cancelled/abandoned

### Session Lifecycle

**Creation:**
```
startSession(matchId: UUID) {
    let newToken = UUID()
    activeSession = VoiceSessionIdentity(
        matchId: matchId,
        sessionToken: newToken,
        createdAt: Date()
    )
    state = .preparing
}
```

**Validation:**
```
func isSessionValid(_ identity: VoiceSessionIdentity) -> Bool {
    guard let active = activeSession else { return false }
    return active.sessionToken == identity.sessionToken &&
           active.matchId == identity.matchId
}
```

**Termination:**
```
endSession() {
    state = .ended
    activeSession = nil
    // Clean up signalling, peer connection, audio session
}
```

---

## 4. Local Mute State

### Mute Model

Mute is **local-only** in Phase 12.

```swift
private(set) var isMuted: Bool = false
```

### Mute Rules

**Local Effect Only:**
- Muting affects only this player's microphone
- Does not notify other player
- Does not sync mute state to server
- Other player's audio continues playing

**State Interaction:**
- Mute only applies when state is `.connected`
- Cannot mute in `.idle`, `.preparing`, `.connecting`, `.unavailable`, `.ended`
- When muted, state becomes `.muted`
- When unmuted, state returns to `.connected`

**Persistence:**
- Mute state does NOT persist across sessions
- New session always starts unmuted
- User must manually mute again if desired

### Mute Operations

**Toggle Mute:**
```
func toggleMute() {
    guard state == .connected || state == .muted else { return }
    
    isMuted.toggle()
    
    if isMuted {
        state = .muted
        // Disable local audio track
    } else {
        state = .connected
        // Enable local audio track
    }
}
```

---

## 5. Idempotency Contracts

### Start Session Idempotency

**Contract:**
- Calling `startSession(matchId:)` when a session is already active for the same `matchId` is a **no-op**
- Does not create duplicate session
- Does not reset session token
- Does not restart signalling

**Implementation Rule:**
```
func startSession(matchId: UUID) {
    // Guard: Already active for this match
    if let active = activeSession, active.matchId == matchId {
        print("⚠️ Session already active for match \(matchId)")
        return // NO-OP
    }
    
    // Proceed with new session creation
    // ...
}
```

### End Session Idempotency

**Contract:**
- Calling `endSession()` when no session is active is a **no-op**
- Calling `endSession()` multiple times is safe
- Does not throw errors
- Cleanup operations are safe to call multiple times

**Implementation Rule:**
```
func endSession() {
    // Guard: No active session
    guard activeSession != nil else {
        print("⚠️ No active session to end")
        return // NO-OP
    }
    
    // Proceed with teardown
    // ...
}
```

---

## 6. Stale Callback Protection

### Problem

Async operations (signalling, peer connection, audio session) may complete after:
- Session has been ended
- New session has been started
- Match has changed
- Flow has exited

Stale callbacks must not mutate current state.

### Protection Mechanism

**Capture Session Identity:**
```
func sendSignallingMessage() {
    guard let session = activeSession else { return }
    
    Task {
        // Capture session identity
        let capturedSession = session
        
        // Perform async work
        let result = await performSignalling()
        
        // Validate session still active
        guard isSessionValid(capturedSession) else {
            print("⚠️ Stale callback - session changed")
            return // IGNORE
        }
        
        // Safe to mutate state
        handleSignallingResult(result)
    }
}
```

### Validation Points

**Before State Mutation:**
- Always validate session identity before updating state
- Always validate session identity before updating UI
- Always validate session identity before triggering side effects

**Example Scenarios:**

**Scenario 1: Session Ended During Signalling**
1. Session A starts signalling
2. User cancels match (session ends)
3. Signalling completes
4. Callback validates: session A != nil (current is nil)
5. Callback ignored ✅

**Scenario 2: New Session Started**
1. Session A (token: UUID-1) starts connecting
2. Connection fails, session A ends
3. User retries, Session B (token: UUID-2) starts
4. Session A's delayed callback arrives
5. Callback validates: UUID-1 != UUID-2
6. Callback ignored ✅

**Scenario 3: Match Changed**
1. Session for Match A starts
2. User abandons, starts new Match B
3. Session for Match B starts (new token)
4. Match A callbacks arrive
5. Callback validates: matchId-A != matchId-B
6. Callback ignored ✅

---

## 7. State Transition Rules

### Valid Transitions

```
idle → preparing → connecting → connected
                              ↓
                            muted ↔ connected
                              ↓
                         unavailable
                              ↓
                            ended

idle → preparing → connecting → unavailable → ended

Any state → ended (on explicit termination)
```

### Transition Constraints

**From `idle`:**
- Can only transition to `preparing` (on startSession)

**From `preparing`:**
- Can transition to `connecting` (audio session ready)
- Can transition to `unavailable` (preparation failed)
- Can transition to `ended` (session cancelled)

**From `connecting`:**
- Can transition to `connected` (peer connection established)
- Can transition to `unavailable` (connection failed)
- Can transition to `ended` (session cancelled)

**From `connected`:**
- Can transition to `muted` (user mutes)
- Can transition to `unavailable` (connection dropped)
- Can transition to `ended` (session terminated)

**From `muted`:**
- Can transition to `connected` (user unmutes)
- Can transition to `unavailable` (connection dropped)
- Can transition to `ended` (session terminated)

**From `unavailable`:**
- Can only transition to `ended` (cleanup)
- **Phase 12:** No transition back to `connecting` (no auto-reconnect)

**From `ended`:**
- Terminal state, no transitions
- New session requires fresh `startSession()` call

### Invalid Transitions

These transitions are **not allowed**:

- `unavailable` → `connecting` (no auto-reconnect in Phase 12)
- `ended` → any other state (terminal)
- `connected` → `preparing` (illogical)
- `muted` → `preparing` (illogical)

---

## 8. Session Lifecycle Hooks

### Flow Integration Points

Voice session lifecycle must integrate with remote flow lifecycle.

**On Remote Flow Entry:**
```
RemoteMatchService.enterRemoteFlow(matchId:) {
    // Flow layer may request voice session start
    // But only after reaching stable lobby state
    // Not immediately on flow entry
}
```

**On Remote Flow Exit:**
```
RemoteMatchService.exitRemoteFlow() {
    // Voice session must end
    voiceService.endSession()
}
```

**On Match Status Change:**
```
// Observe match status
if match.status == .cancelled || match.status == .completed {
    // End voice session
    voiceService.endSession()
}
```

### View Lifecycle Independence

**Critical Rule:**
- View `onAppear` / `onDisappear` must NOT directly control session lifecycle
- Views may observe session state
- Views may request mute/unmute
- Views may render session state
- But views do NOT own session lifecycle

**Example - Lobby View:**
```
RemoteLobbyView.onAppear {
    // ❌ WRONG: Do not start session here
    // voiceService.startSession(matchId: match.id)
    
    // ✅ CORRECT: Observe state only
    // Session is started by flow layer when appropriate
}

RemoteLobbyView.onDisappear {
    // ❌ WRONG: Do not end session here
    // voiceService.endSession()
    
    // ✅ CORRECT: Do nothing
    // Session persists through navigation
}
```

---

## 9. Error Handling Model

### Error Types

```swift
enum VoiceSessionError: Error {
    case audioSessionFailed
    case signallingFailed
    case peerConnectionFailed
    case iceNegotiationFailed
    case notInRemoteFlow
    case matchIdMismatch
    case sessionAlreadyActive
    case noActiveSession
}
```

### Error Handling Strategy

**Non-Blocking Principle:**
- Errors must not throw exceptions that crash the app
- Errors must not block match progression
- Errors transition state to `.unavailable`
- Errors are logged for debugging
- UI shows unavailable state calmly

**Error Flow:**
```
func handleConnectionError(_ error: VoiceSessionError) {
    print("❌ Voice error: \(error)")
    
    // Transition to unavailable
    state = .unavailable
    
    // Do NOT:
    // - Show blocking alert
    // - Prevent match from starting
    // - Crash the app
    // - Retry automatically (Phase 12)
}
```

---

## 10. State Observation

### Published State

Voice state must be observable by SwiftUI views.

```swift
@Published private(set) var state: VoiceSessionState = .idle
@Published private(set) var isMuted: Bool = false
@Published private(set) var activeSession: VoiceSessionIdentity?
```

### UI Binding

Views bind to state for rendering:

```swift
// Lobby status line
switch voiceService.state {
case .idle, .preparing:
    Text("Preparing voice...")
case .connecting:
    Text("Connecting voice...")
case .connected, .muted:
    Text("Voice ready")
case .unavailable:
    Text("Voice not available")
case .ended:
    EmptyView()
}

// Voice control icon
Image(systemName: voiceService.isMuted ? "microphone.slash" : "microphone")
```

---

## 11. What This Task Does Not Include

This task defines the **model** only.

It does not implement:

- Service class structure (Task 3)
- Feature flag (Task 4)
- Signalling logic (Sub-phase B)
- Audio session code (Sub-phase C)
- Peer connection code (Sub-phase C)
- UI components (Sub-phase D)

---

## 12. Approval Checkpoint

Task 2 is complete when the following are accepted:

- ✅ State enum covers all required states (idle, preparing, connecting, connected, muted, unavailable, ended)
- ✅ Session identity model includes matchId, sessionToken, createdAt
- ✅ Session validity rules prevent stale callbacks
- ✅ Idempotency contracts defined for start/end operations
- ✅ Stale callback protection mechanism specified
- ✅ State transition rules are clear and enforce constraints
- ✅ Mute is local-only (no remote sync in Phase 12)
- ✅ Error handling is non-blocking
- ✅ Session lifecycle integrates with flow hooks (not view lifecycle)
- ✅ Model is ready for implementation in Task 3

---

## Summary

This state model establishes:

- **7 distinct states** with clear definitions
- **Session identity protection** via token-based validation
- **Idempotent lifecycle** operations (safe to call repeatedly)
- **Stale callback rejection** mechanism
- **Local-only mute** state (no remote sync)
- **Non-blocking error handling** (unavailable state)
- **Flow-level lifecycle** integration (not view-level)
- **Observable state** for SwiftUI binding

This model will be implemented in Task 3 (service shell) and used throughout all subsequent voice implementation work.
