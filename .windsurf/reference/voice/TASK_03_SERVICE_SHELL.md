# Task 3 — Voice Chat Service Shell
**Phase:** 12  
**Sub-phase:** A (Foundation)  
**Status:** Implemented  
**Date:** 2026-03-14

---

## Purpose

This task creates the voice service/manager structure that will own the state models defined in Task 2 and provide the public interface for voice session management. This is the shell only—no real signalling or WebRTC implementation yet.

---

## Implementation Summary

### File Created

**Location:** `/DanDart/Services/VoiceChatService.swift`

**Pattern:** Follows existing project service patterns (singleton, `@MainActor`, `ObservableObject`)

---

## Service Structure

### Singleton Pattern

```swift
@MainActor
class VoiceChatService: ObservableObject {
    static let shared = VoiceChatService()
    private init() { }
}
```

**Why singleton:**
- Matches existing service patterns in the project (`AuthService.shared`, `RemoteMatchService.shared`)
- Voice session must be globally accessible to remote match flow
- Only one voice session can be active at a time

**Why `@MainActor`:**
- All state mutations happen on main thread
- SwiftUI `@Published` properties require main thread updates
- WebRTC callbacks will dispatch to main before updating state

---

## Published State Properties

### Source of Truth

```swift
@Published private(set) var currentSession: VoiceSession?
```

- **Primary source of truth** for all session state
- All other properties are derived from this
- `private(set)` ensures only the service can mutate state

### Derived State Properties

```swift
@Published private(set) var connectionState: VoiceSessionState = .idle
@Published private(set) var muteState: VoiceMuteState = .unmuted
@Published private(set) var availability: VoiceAvailability = .notApplicable
```

- Extracted from `currentSession` for SwiftUI observation convenience
- Views can observe specific properties without re-rendering on unrelated changes
- Updated automatically when `currentSession` changes

### Derived UI States

```swift
@Published private(set) var uiState: VoiceUIState = .hidden
@Published private(set) var iconState: VoiceIconState = .hidden
```

- Pre-computed for UI efficiency
- Derived from availability + connection state + mute state
- Updated via derivation functions

---

## Public Interface

### Session Lifecycle

#### `startSession(for matchId: UUID) async throws`

**Purpose:** Initialize voice session for a remote match

**Behavior:**
- Validates no existing session for different match
- Terminates stale session if found
- Returns early if session already exists for this match
- Creates new session in idle state
- Updates all published properties

**Future implementation (later tasks):**
- Check microphone permissions
- Determine availability (remote vs local match)
- Create WebRTC offer
- Publish offer to Realtime channel

#### `endSession() async`

**Purpose:** Terminate the current voice session

**Behavior:**
- Returns early if no active session
- Updates session state to `.ended`
- Sets `endedAt` timestamp
- Clears session after brief delay (allows UI to show ended state)
- Updates all published properties

**Future implementation (later tasks):**
- Close WebRTC peer connection
- Send disconnect signal
- Clean up audio session

### Mute Control

#### `toggleMute()`

**Purpose:** Toggle between muted and unmuted states

**Behavior:**
- Guards: requires active session and connected state
- Toggles mute state
- Updates published properties
- Logs state change

**Future implementation:**
- Actually mute/unmute local audio track

#### `setMute(_ muted: Bool)`

**Purpose:** Set mute state explicitly

**Behavior:**
- Guards: requires active session and connected state
- Sets mute state to specific value
- Returns early if already in desired state
- Updates published properties
- Logs state change

**Future implementation:**
- Actually mute/unmute local audio track

### Session Validation

#### `isSessionValid(for matchId: UUID?) -> Bool`

**Purpose:** Check if current session belongs to the given match

**Returns:** `true` if session exists and matches the provided match ID

**Use case:** Remote match flow can validate session before using it

---

## Private State Management

### Single Point of Mutation

```swift
private func updateSession(_ session: VoiceSession)
```

**Purpose:** Update session and all derived states atomically

**Process:**
1. Update `currentSession` (source of truth)
2. Extract individual state properties
3. Recompute derived UI states
4. Publish changes (automatic via `@Published`)

**Why this pattern:**
- Ensures state consistency
- Prevents partial updates
- Single place to add logging/debugging
- Easy to add validation or side effects

### Derived State Computation

```swift
private func updateDerivedStates()
private func deriveUIState(...) -> VoiceUIState
private func deriveIconState(...) -> VoiceIconState
```

**Purpose:** Compute UI states from raw session state

**Logic:**
- Availability checked first (determines if voice is applicable)
- Connection state checked second (determines current status)
- Mute state checked last (only relevant when connected)

**UI State Boundaries:**
- `notApplicable` → `hidden` (local match)
- `permissionDenied` → `permissionNeeded` (show permission prompt)
- `systemUnavailable` → `unavailable` (show unavailable)
- `available` + connection state → connecting/ready/unavailable

---

## Placeholder Methods

### Documented for Future Tasks

```swift
// TODO: Task 4-6 (Signalling)
// - setupSignalling()
// - sendOffer()
// - sendAnswer()
// - sendICECandidate()
// - handleIncomingSignal()

// TODO: Task 7-9 (Voice Engine)
// - configureAudioSession()
// - createPeerConnection()
// - addLocalAudioTrack()
// - handleRemoteAudioTrack()
// - handleConnectionStateChange()

// TODO: Task 13-15 (Lifecycle)
// - Integration with remote match flow lifecycle
// - Cleanup on flow exit
// - Session validation on navigation
```

**Purpose:** Document future implementation points without implementing them now

---

## Dependency Injection Strategy

### Current Approach

Service is a singleton accessed via `VoiceChatService.shared`

### Integration Points

**Where the service will be injected:**
- Remote match flow coordinator/manager (same level as `RemoteMatchService`)
- Accessible to lobby, gameplay, end game, and replay views
- Observable by UI components for state display

**How views will access it:**
```swift
@StateObject private var voiceService = VoiceChatService.shared
// or
@EnvironmentObject var voiceService: VoiceChatService
```

**Decision deferred to Task 13-15:**
- Exact injection point in remote match flow
- Whether to use `@StateObject` or `@EnvironmentObject`
- How to coordinate with `RemoteMatchService` lifecycle

---

## Thread Safety

### Main Actor Enforcement

```swift
@MainActor
class VoiceChatService: ObservableObject
```

**Guarantees:**
- All state mutations happen on main thread
- SwiftUI observation works correctly
- No race conditions on published properties

### Future WebRTC Integration

**Pattern for background callbacks:**
```swift
// WebRTC callback (background thread)
func onConnectionStateChange(newState: RTCPeerConnectionState) {
    Task { @MainActor in
        // Dispatch to main thread before updating state
        updateConnectionState(newState)
    }
}
```

---

## Logging Strategy

### Current Logging

- Session lifecycle events (create, end)
- Mute state changes
- Validation checks
- Error conditions

**Format:**
```
🎤 [VoiceChatService] <action>: <details>
✅ [VoiceChatService] Success: <details>
⚠️ [VoiceChatService] Warning: <details>
❌ [VoiceChatService] Error: <details>
```

### Future Logging

- Connection state transitions
- Signalling message exchange
- Audio session events
- Performance metrics (time-to-connect)

---

## State Model Integration

### All Task 2 Models Included

- ✅ `VoiceSessionState` enum
- ✅ `VoiceMuteState` enum
- ✅ `VoiceAvailability` enum
- ✅ `VoiceSessionError` enum
- ✅ `VoiceSession` struct
- ✅ `VoiceUIState` enum
- ✅ `VoiceIconState` enum

### Models Located

All state models are defined in `VoiceChatService.swift` above the service class.

**Rationale:**
- Keeps related types together
- Easy to import entire module
- Follows Swift best practices for small enums/structs

**Alternative considered:**
- Separate files for each model
- Decided against to avoid file proliferation for simple types

---

## Testing Strategy

### Manual Testing (Current)

```swift
// Create session
try await VoiceChatService.shared.startSession(for: matchId)

// Check state
print(VoiceChatService.shared.connectionState) // .idle
print(VoiceChatService.shared.uiState) // .hidden or .connecting

// Toggle mute (will fail until connected)
VoiceChatService.shared.toggleMute()

// End session
await VoiceChatService.shared.endSession()
```

### Future Testing

- Unit tests for state derivation logic
- Integration tests with mock WebRTC
- UI tests for control interactions

---

## Design Decisions

### Decision 1: Singleton vs Dependency Injection

**Chosen:** Singleton pattern

**Rationale:**
- Matches existing project patterns
- Only one voice session can be active
- Simpler for Phase 12 scope

**Trade-off:**
- Less testable than pure DI
- Acceptable for this use case

### Decision 2: Single Source of Truth

**Chosen:** `currentSession` is primary, others are derived

**Rationale:**
- Prevents state inconsistencies
- Clear mutation point
- Easy to add validation

**Alternative considered:**
- Flat published properties as canonical
- Rejected: harder to keep consistent

### Decision 3: State Models in Same File

**Chosen:** All models in `VoiceChatService.swift`

**Rationale:**
- Simple types, low complexity
- Easy to import
- Reduces file count

**Alternative considered:**
- Separate `VoiceSessionModels.swift` file
- May refactor later if models grow

### Decision 4: Async/Await for Public Methods

**Chosen:** `startSession` and `endSession` are async

**Rationale:**
- Future-proof for network operations
- Matches modern Swift patterns
- Allows awaiting cleanup

**Trade-off:**
- Slightly more complex call sites
- Worth it for cleaner async flow

---

## Limitations (By Design)

### What This Task Does NOT Include

- ❌ No actual WebRTC implementation
- ❌ No signalling logic
- ❌ No audio session configuration
- ❌ No permission checking
- ❌ No Realtime integration
- ❌ No connection state transitions beyond manual updates

### Why These Are Deferred

- Task 3 is shell only
- Real implementation comes in Tasks 4-9
- This establishes the interface contract
- Allows UI integration (Tasks 10-12) to proceed in parallel once approved

---

## Integration with Remote Match Flow

### Where Voice Service Lives

The voice service should be injected at the same layer as `RemoteMatchService`:
- Lives in the shared remote match flow layer
- Survives lobby → gameplay → end game → replay transitions
- Accessible to all remote match views

### Lifecycle Coordination

**Voice session lifecycle will be triggered by:**
- Remote match flow entry (receiver enters lobby)
- Remote match flow exit (either player leaves)
- Existing disconnect handling

**Voice session will NOT:**
- Create its own parallel lifecycle system
- Have separate disconnect detection
- Manage navigation independently

**Integration point (Task 13-15):**
```swift
// In RemoteMatchService or flow coordinator
func enterRemoteFlow(matchId: UUID) {
    // Existing flow setup...
    
    // Start voice session
    Task {
        try? await VoiceChatService.shared.startSession(for: matchId)
    }
}

func exitRemoteFlow() {
    // End voice session
    Task {
        await VoiceChatService.shared.endSession()
    }
    
    // Existing flow cleanup...
}
```

---

## Success Criteria for Task 3

This task is complete when:

- ✅ Service shell created following project patterns
- ✅ Singleton pattern implemented with `@MainActor`
- ✅ All Task 2 state models included
- ✅ Published properties defined with source of truth pattern
- ✅ Public interface methods defined (startSession, endSession, toggleMute, setMute, isSessionValid)
- ✅ State derivation logic implemented
- ✅ Placeholder comments for future tasks
- ✅ Logging strategy established
- ✅ Thread safety strategy documented
- ✅ No real WebRTC or signalling implementation (by design)

**Approval checkpoint:** Service shell reviewed and accepted before Task 4 begins.

---

## Next Steps

### Task 4: Define Signalling Message Contract

This will define the exact message payloads for:
- WebRTC offer
- WebRTC answer
- ICE candidates
- Disconnect signals

### Suggested Git Push Point

After Task 3 approval, this is a natural checkpoint for:
```
git add DanDart/Services/VoiceChatService.swift
git add .windsurf/reference/voice/TASK_03_SERVICE_SHELL.md
git commit -m "Phase 12 Task 3: Create voice chat service shell"
git push
```

Sub-phase A (Foundation) will be complete after Task 3 approval.
