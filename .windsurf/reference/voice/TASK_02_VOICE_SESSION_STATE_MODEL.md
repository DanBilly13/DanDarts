# Task 2 — Voice Session State Model
**Phase:** 12  
**Sub-phase:** A (Foundation)  
**Status:** Defined  
**Date:** 2026-03-14

---

## Purpose

This document defines the state model and enums that represent voice connection state, mute state, and session validity. This is the data model foundation that will be used by the voice service and observed by UI components.

---

## Core State Model

### VoiceSessionState Enum

Represents the overall connection state of the voice session.

```swift
enum VoiceSessionState: String, Codable {
    case idle           // No session exists yet for the current flow
    case connecting     // Handshake in progress
    case connected      // Peer connection established, audio active
    case disconnected   // Connection failed or dropped (covers both initial failure and post-connect drop)
    case ended          // Session existed and has been intentionally terminated
}
```

**State Descriptions:**

- **idle** — No voice session exists yet for the current remote match flow. This is the default state before a session is created.

- **connecting** — Voice session initialization has begun. WebRTC offer/answer exchange is in progress. ICE candidates are being exchanged. Audio is not yet active.

- **connected** — Peer connection is established and audio is flowing. Both players can hear each other (unless locally muted).

- **disconnected** — Connection is unavailable. This state covers both:
  - Initial connection failure (never successfully connected)
  - Post-connection drop (was connected, then lost connection)
  
  In Phase 12, this state persists for the remainder of the match flow (no automatic reconnect). The distinction between "never connected" vs "was connected" can be tracked via `connectedAt` timestamp if needed for debugging.

- **ended** — A session did exist and has now been intentionally terminated. This happens when the remote match flow exits or cleanup is triggered. This is semantically different from `idle` because it represents the end of a lifecycle rather than the absence of one.

---

## Mute State Model

### VoiceMuteState Enum

Represents the local microphone mute state.

```swift
enum VoiceMuteState: String, Codable {
    case unmuted        // Microphone is active, audio is being sent
    case muted          // Microphone is muted, no audio is being sent
}
```

**Important characteristics:**

- Mute state is **local only** — it affects only the local microphone
- Mute state does **not sync** to the other player
- The other player has no visibility into local mute state
- Mute can be toggled at any time when connection state is `.connected`

**Mute behavior by connection state:**

- **idle / ended** — Mute state is not applicable
- **connecting** — Mute state can be set, but has no effect until connected
- **connected** — Mute state controls local microphone
- **disconnected** — Mute state is preserved but has no effect

---

## Session Validity

### Match Binding Validation

Every voice session is bound to exactly one remote match via its `matchId`.

**Validation rule:**

A session is valid if and only if `session.matchId == currentActiveRemoteMatchId`.

**Purpose:**

This prevents stale voice sessions from lingering across match boundaries.

**Validation scenarios:**

- When entering a new remote match, check if existing session's `matchId` matches
- If `matchId` doesn't match, the session is invalid and must be terminated
- If no session exists, create a new one bound to the current match
- Only one voice session can be valid at a time

**Use cases:**

- Player exits match and immediately enters a new one
- App crashes and restarts mid-match
- Navigation edge cases where cleanup didn't complete

**Implementation note:**

This is a derived validation rule, not a separate stored object. The session stores `matchId`, and validity is determined by comparing it to the active flow's match ID.

---

## Availability State

### VoiceAvailability Enum

Represents whether voice is available for the current match context.

```swift
enum VoiceAvailability: String, Codable {
    case notApplicable      // Voice is not applicable in this context (e.g., local match)
    case available          // Voice is applicable and can be used
    case systemUnavailable  // Voice is applicable but system/device constraints prevent use
    case permissionDenied   // Microphone permission explicitly denied by user
}
```

**Availability determination:**

- **notApplicable** — Voice is not applicable in this context. This is a local match or other non-remote scenario. Voice UI should be hidden.

- **available** — Voice is applicable (remote match) and can be used. Microphone permission granted, device supports audio, no system constraints.

- **systemUnavailable** — Voice is applicable (remote match) but cannot currently be used due to device or system constraints (e.g., audio hardware unavailable, iOS audio session failure). Voice UI should show as unavailable.

- **permissionDenied** — User has explicitly denied microphone access. Voice UI should show permission-needed state with option to open Settings.

**Relationship to connection state:**

- Availability is checked **before** attempting connection
- If availability is not `.available`, connection should not be attempted
- Availability can change during a session (e.g., user revokes permission in Settings)

---

## Combined Session Model

### VoiceSession

The complete state model for a voice session.

```swift
struct VoiceSession {
    // Identity
    let id: UUID
    let matchId: UUID
    
    // State
    var connectionState: VoiceSessionState
    var muteState: VoiceMuteState
    var availability: VoiceAvailability
    
    // Metadata
    let createdAt: Date
    var connectedAt: Date?
    var disconnectedAt: Date?
    var endedAt: Date?
    
    // Error tracking
    var lastError: VoiceSessionError?
}
```

**Field descriptions:**

- **id** — Unique identifier for this session instance
- **matchId** — The remote match this session belongs to (used for validity checking)
- **connectionState** — Current WebRTC connection state
- **muteState** — Current local microphone state
- **availability** — Whether voice is available in this context
- **createdAt** — When session initialization began
- **connectedAt** — When peer connection was established (nil if never connected)
- **disconnectedAt** — When connection was lost (nil if never disconnected)
- **endedAt** — When session was terminated (nil if still active)
- **lastError** — Most recent error encountered (nil if no errors)

**Note on validity:**

Session validity is determined by comparing `matchId` to the current active remote match ID, not stored as a separate field.

---

## Error Model

### VoiceSessionError Enum

Represents initial expected error categories that can occur during voice session lifecycle. This enum may be refined during implementation as we learn which cases actually matter in practice.

```swift
enum VoiceSessionError: Error {
    // Permission errors
    case microphonePermissionDenied
    case microphonePermissionRestricted
    
    // Connection errors
    case connectionTimeout
    case connectionFailed(reason: String)
    case iceConnectionFailed
    case peerConnectionFailed
    
    // Signalling errors
    case signallingTimeout
    case signallingFailed(reason: String)
    case invalidSignallingMessage
    
    // Audio session errors
    case audioSessionConfigurationFailed
    case audioSessionInterrupted
    case audioSessionRouteChangeFailed
    
    // Session errors
    case sessionInvalid
    case sessionAlreadyActive
    case sessionNotActive
    
    // Unknown
    case unknown(Error)
}
```

**Error categories:**

1. **Permission errors** — User has denied or restricted microphone access
2. **Connection errors** — WebRTC peer connection failures
3. **Signalling errors** — Offer/answer/ICE exchange failures
4. **Audio session errors** — iOS audio system failures
5. **Session errors** — Lifecycle/state management errors
6. **Unknown** — Unexpected errors wrapped for debugging

**Error handling philosophy:**

- Errors should be logged for debugging
- Errors should update session state appropriately
- Errors should NOT show disruptive alerts (except permission requests)
- Errors should NOT block match flow

---

## State Transitions

### Valid State Transitions

```
idle → connecting → connected → disconnected → ended
  ↓                      ↓           ↓
  └──────────────────────┴───────────┴────────→ ended
```

**Transition rules:**

- **idle → connecting** — Session initialization begins (receiver enters lobby)
- **connecting → connected** — Peer connection established successfully
- **connecting → disconnected** — Connection attempt failed
- **connecting → ended** — Session terminated before connection completed
- **connected → disconnected** — Connection dropped mid-session
- **connected → ended** — Session terminated while connected
- **disconnected → ended** — Session terminated after failure
- **Any state → ended** — Cleanup can happen from any state

**Invalid transitions:**

- **disconnected → connected** — No reconnect in Phase 12
- **ended → any other state** — Ended is terminal
- **connected → idle** — Must go through ended
- **disconnected → connecting** — No retry in Phase 12

---

## Mute State Transitions

### Valid Mute Transitions

```
unmuted ⇄ muted
```

**Transition rules:**

- Mute can toggle freely when connection state is `.connected`
- Mute state persists across connection state changes
- Mute state is reset when session ends

**Behavior by connection state:**

| Connection State | Mute Toggle Allowed | Audio Effect |
|-----------------|---------------------|--------------|
| idle            | No                  | N/A          |
| connecting      | Yes (pre-set)       | None yet     |
| connected       | Yes                 | Immediate    |
| disconnected    | Yes (preserved)     | None         |
| ended           | No                  | N/A          |

---

## UI State Derivation

### Derived States for UI Display

The UI needs to display different states than the raw connection state. Here are the derived states:

```swift
enum VoiceUIState {
    case hidden             // Voice not applicable (local match) - UI completely hidden
    case connecting         // "Connecting voice..." - shown in remote match lobby
    case ready              // "Voice ready" (connected, unmuted)
    case readyMuted         // "Voice ready" (connected, muted)
    case unavailable        // "Voice not available" - shown when connection failed in remote match
    case permissionNeeded   // "Microphone permission needed" - shown when permission denied
}
```

**Critical UI boundaries:**

- **hidden** — Used for local matches or non-applicable contexts. Voice UI is completely hidden.
- **unavailable** — Used for remote matches where voice failed. Voice UI is shown but indicates unavailability.
- **permissionNeeded** — Used when microphone permission is denied. Voice UI shows permission prompt.

These boundaries must remain crisp to avoid confusion between "not applicable" and "applicable but failed".

**Derivation logic:**

```swift
func deriveUIState(
    availability: VoiceAvailability,
    connectionState: VoiceSessionState,
    muteState: VoiceMuteState
) -> VoiceUIState {
    
    // Check availability first
    if availability == .notApplicable {
        return .hidden  // Local match - hide completely
    }
    
    if availability == .permissionDenied {
        return .permissionNeeded  // Remote match - show permission needed
    }
    
    if availability == .systemUnavailable {
        return .unavailable  // Remote match - show unavailable
    }
    
    // availability == .available, check connection state
    switch connectionState {
    case .idle:
        return .hidden
        
    case .connecting:
        return .connecting  // Remote match - show connecting
        
    case .connected:
        return muteState == .muted ? .readyMuted : .ready
        
    case .disconnected:
        return .unavailable  // Remote match - show unavailable
        
    case .ended:
        return .hidden
    }
}
```

---

## Icon State Derivation

### Derived States for Voice Control Icon

The voice control button needs to show different icons based on state:

```swift
enum VoiceIconState {
    case hidden                     // No icon shown
    case connecting                 // microphone with pulse
    case active                     // microphone
    case muted                      // microphone.slash
    case unavailable                // microphone with warning treatment
    case permissionNeeded           // microphone with alert treatment
}
```

**Icon mapping:**

| UI State         | Icon State        | SF Symbol                  |
|-----------------|-------------------|----------------------------|
| hidden          | hidden            | (none)                     |
| connecting      | connecting        | microphone (pulsing)       |
| ready           | active            | microphone                 |
| readyMuted      | muted             | microphone.slash           |
| unavailable     | unavailable       | microphone (dimmed/warning)|
| permissionNeeded| permissionNeeded  | microphone (alert tint)    |

---

## Observable State Model

### Published Properties for SwiftUI

The voice service will publish these properties for SwiftUI observation:

```swift
@Published private(set) var currentSession: VoiceSession?
@Published private(set) var connectionState: VoiceSessionState = .idle
@Published private(set) var muteState: VoiceMuteState = .unmuted
@Published private(set) var availability: VoiceAvailability = .notApplicable
@Published private(set) var uiState: VoiceUIState = .hidden
@Published private(set) var iconState: VoiceIconState = .hidden
```

**Source of truth:**

- `currentSession` is the **primary source of truth** for all session state
- Individual published properties (`connectionState`, `muteState`, `availability`) are **derived views** extracted from `currentSession` for SwiftUI observation convenience
- Derived UI states (`uiState`, `iconState`) are **computed from the session state**
- All properties are `private(set)` — only the service can mutate them

**Update pattern:**

When underlying state changes:
1. Update `currentSession` fields (source of truth)
2. Extract and publish individual state properties from `currentSession`
3. Recompute and publish derived UI states
4. All changes publish automatically via `@Published`

**Why this structure:**

- Single source of truth (`currentSession`) prevents state inconsistencies
- Individual properties optimize SwiftUI observation (views only re-render when their specific property changes)
- Derived states are pre-computed for UI efficiency

---

## Session Lifecycle Tracking

### Session Lifecycle Events

Track key lifecycle events for debugging and analytics:

```swift
enum VoiceSessionEvent {
    case sessionCreated(matchId: UUID)
    case connectionStarted
    case connectionEstablished(duration: TimeInterval)
    case connectionFailed(error: VoiceSessionError, duration: TimeInterval)
    case connectionDropped(duration: TimeInterval)
    case muteToggled(muted: Bool)
    case sessionEnded(totalDuration: TimeInterval, wasConnected: Bool)
}
```

**Event tracking purpose:**

- Debugging connection issues
- Understanding connection success rates
- Measuring time-to-connect
- Identifying common failure modes
- Future analytics for TURN necessity

---

## Match Association

### Ensuring Session-Match Binding

Every voice session must be bound to exactly one remote match via its `matchId` field.

**Validation function:**

```swift
func isSessionValid(session: VoiceSession?, currentMatchId: UUID?) -> Bool {
    guard let session = session,
          let currentMatchId = currentMatchId else {
        return false
    }
    return session.matchId == currentMatchId
}
```

**Binding rules:**

- Session is created with a specific `matchId`
- Session is only valid for that `matchId`
- If user navigates to a different match, session must be terminated
- If match ends and replay starts, session remains valid (same `matchId`)

**Simplified approach:**

No separate binding struct is needed. The `matchId` stored in `VoiceSession` plus a simple validation function is sufficient.

---

## State Persistence

### What Should NOT Be Persisted

Voice session state should **not** be persisted across app launches:

- No saving to UserDefaults
- No saving to disk
- No restoration after app restart

**Rationale:**

- Voice sessions are ephemeral and tied to active network connections
- WebRTC peer connections cannot be serialized/restored
- Attempting to restore would create invalid state
- Simpler to start fresh on each app launch

**Exception:**

- User preferences (like default mute state) could be persisted
- But active session state should not be

---

## Thread Safety

### Concurrency Model

Voice session state will be accessed from multiple contexts:

- Main thread (UI updates)
- Background threads (WebRTC callbacks)
- Realtime subscription threads (signalling)

**Thread safety strategy:**

```swift
@MainActor
class VoiceSessionStateManager: ObservableObject {
    @Published private(set) var currentSession: VoiceSession?
    
    // All state mutations must happen on main actor
    func updateConnectionState(_ newState: VoiceSessionState) {
        // Safe to update @Published properties
    }
}
```

**Key points:**

- Use `@MainActor` for the state manager
- All state mutations happen on main thread
- WebRTC callbacks dispatch to main thread before updating state
- SwiftUI observation works correctly with main thread updates

---

## Success Criteria for Task 2

This task is complete when:

- ✅ VoiceSessionState enum is defined with all connection states
- ✅ VoiceMuteState enum is defined
- ✅ VoiceAvailability enum is defined
- ✅ VoiceSession struct is defined with all necessary fields
- ✅ VoiceSessionError enum covers all error cases
- ✅ State transition rules are documented
- ✅ UI state derivation logic is defined
- ✅ Icon state derivation logic is defined
- ✅ Observable state model is specified
- ✅ Session validity model is defined
- ✅ Match binding rules are established
- ✅ Thread safety strategy is documented

**Approval checkpoint:** State model reviewed and accepted before Task 3 begins.

---

## Next Task

**Task 3:** Create the service shell

This will create the voice service/manager structure that will own these state models and provide the public interface for voice session management.
