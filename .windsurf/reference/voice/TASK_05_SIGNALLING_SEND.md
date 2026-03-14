# Task 5 — Signalling Send Implementation
**Phase:** 12  
**Sub-phase:** B (Signalling)  
**Status:** Implemented  
**Date:** 2026-03-14

---

## Purpose

This task implements the methods to send offer/answer/ICE candidates over Supabase Realtime using the contract defined in Task 4. This is the outbound signalling implementation only—receiving is Task 6.

---

## Implementation Summary

### File Modified

**Location:** `/DanDart/Services/VoiceChatService.swift`

**Changes:**
- Added Supabase import
- Added signalling message type definitions (see note below on location)
- Added signalling channel management
- Added send methods for all message types
- Added generic message sending infrastructure

### Contract Type Location Review

**Current implementation:** Signalling message types are defined inside `VoiceChatService.swift`

**Consideration for future refactoring:**
- These are protocol contract types, not just service internals
- Task 6 receive will also depend on them
- A shared `VoiceSignallingContract.swift` or similar may be cleaner than embedding them in the service file

**Decision:** Keep in service file for now to maintain momentum, but this should be reviewed intentionally before Task 6 if it would improve clarity. The types are conceptually shared contract definitions, not service-private implementation details.

---

## Message Type Definitions

### Signalling Message Envelope

```swift
struct VoiceSignallingMessage: Codable {
    let type: VoiceSignallingMessageType
    let from: UUID
    let to: UUID
    let matchId: UUID
    let timestamp: Date
    let payload: [String: AnyCodable]
}
```

**Note:** Uses `[String: AnyCodable]` for payload to work with Supabase Realtime's JSON serialization.

### Message Type Enum

```swift
enum VoiceSignallingMessageType: String, Codable {
    case voice_offer
    case voice_answer
    case voice_ice_candidate
    case voice_disconnect
}
```

### Payload Structs

All payload types from Task 4 contract implemented:
- `VoiceOfferPayload` (sdp, sessionId)
- `VoiceAnswerPayload` (sdp, sessionId)
- `VoiceICECandidatePayload` (candidate, sdpMid, sdpMLineIndex, sessionId)
- `VoiceDisconnectPayload` (reason, sessionId)
- `VoiceDisconnectReason` enum (user_exit, session_ended, error)

### AnyCodable Helper

```swift
struct AnyCodable: Codable
```

**Purpose:** Transport bridge for Supabase Realtime JSON serialization.

**Architecture note:**
- **Typed payload structs remain the source model** (VoiceOfferPayload, VoiceAnswerPayload, etc.)
- `[String: AnyCodable]` is the **transport bridge** used for Realtime serialization
- This is an implementation detail to work with Realtime's JSON-like dictionary format
- Future code should not drift toward "everything is untyped dictionaries"

**Supports:** String, Int, Double, Bool, Dictionary, Array

---

## Channel Management

### Setup Channel

```swift
private func setupSignallingChannel(matchId: UUID, otherPlayerId: UUID) async throws
```

**Behavior:**
- Creates channel name: `voice_match_{matchId}`
- Stores `otherPlayerId` for message routing (see trust boundary note below)
- Creates Realtime channel with `receiveOwnBroadcasts = false`
- Subscribes to channel
- Handles subscription status (subscribed, timedOut, channelError)
- Throws `VoiceSessionError.signallingTimeout` or `.signallingFailed` on error

**Subscription semantics:**
- Successful subscription means channel subscription acknowledged by Realtime layer
- This does NOT mean peer signalling path is fully usable yet
- End-to-end voice readiness requires successful offer/answer exchange (Task 7-9)

**Trust boundary for otherPlayerId:**
- `otherPlayerId` comes from known active remote match context (passed as parameter)
- It is NOT derived from incoming signalling data
- This preserves the rule that routing identity comes from trusted match state, not peer-provided payloads

**Channel naming:**
- Follows Task 4 contract: `voice_match_{matchId.uuidString}`
- Comment notes alignment with existing remote match pattern if present

### Teardown Channel

```swift
private func teardownSignallingChannel() async
```

**Behavior:**
- Unsubscribes from channel
- Clears `signallingChannel` reference
- Clears `otherPlayerId`
- Logs teardown process

---

## Send Methods

### Send Offer

```swift
private func sendOffer(_ sdp: String) async throws
```

**Guards:**
- Active session exists
- Other player ID is set
- Current user is authenticated

**Process:**
1. Create `VoiceOfferPayload` with SDP and session ID
2. Call generic `sendMessage` with `.voice_offer` type
3. Log send action

**Throws:** `VoiceSessionError.sessionNotActive` or `.signallingFailed`

### Send Answer

```swift
private func sendAnswer(_ sdp: String) async throws
```

**Guards:**
- Active session exists
- Other player ID is set
- Current user is authenticated

**Process:**
1. Create `VoiceAnswerPayload` with SDP and session ID
2. Call generic `sendMessage` with `.voice_answer` type
3. Log send action

**Throws:** `VoiceSessionError.sessionNotActive` or `.signallingFailed`

### Send ICE Candidate

```swift
private func sendICECandidate(candidate: String, sdpMid: String, sdpMLineIndex: Int) async throws
```

**Guards:**
- Active session exists
- Other player ID is set
- Current user is authenticated

**Process:**
1. Create `VoiceICECandidatePayload` with candidate details and session ID
2. Call generic `sendMessage` with `.voice_ice_candidate` type
3. Log send action

**Throws:** `VoiceSessionError.sessionNotActive` or `.signallingFailed`

### Send Disconnect

```swift
private func sendDisconnect(reason: VoiceDisconnectReason) async throws
```

**Guards:**
- Active session exists (returns early if not)
- Other player ID is set (returns early if not)
- Current user is authenticated (returns early if not)

**Process:**
1. Create `VoiceDisconnectPayload` with reason and session ID
2. Call generic `sendMessage` with `.voice_disconnect` type
3. Log send action
4. Catch and log errors but don't throw (best-effort)

**Best-effort behavior:**
- Returns early instead of throwing if preconditions not met
- Catches and logs send errors without throwing
- Follows Task 4 contract: disconnect is courtesy signal only

**Why disconnect is different from other send methods:**
- **Offer/Answer/ICE are required for connection attempt** → throw on failure
- **Disconnect is courtesy-only** → best-effort, no throw
- This difference is intentional: connection messages must succeed or fail clearly, disconnect is optional cleanup

---

## Generic Send Method

### sendMessage

```swift
private func sendMessage<T: Codable>(
    type: VoiceSignallingMessageType,
    from: UUID,
    to: UUID,
    matchId: UUID,
    payload: T
) async throws
```

**Purpose:** Generic method for sending all message types

**Process:**
1. Guard: Channel must exist
2. Encode payload to JSON data
3. Convert JSON data to dictionary
4. Create message envelope with type, from, to, matchId, timestamp, payload
5. Send via `channel.broadcast(event: "voice_signal", message: message)`

**Message envelope format:**
```swift
[
    "type": type.rawValue,
    "from": from.uuidString,
    "to": to.uuidString,
    "matchId": matchId.uuidString,
    "timestamp": ISO8601DateFormatter().string(from: Date()),
    "payload": payloadDict
]
```

**Timestamp semantics:**
- Generated locally at send time only
- For diagnostics and debugging only
- Not used as protocol truth (consistent with Task 4 contract)
- Client clocks are not authoritative for signalling correctness

**Event name:** `"voice_signal"` (consistent for all message types)

**Throws:** `VoiceSessionError.signallingFailed` if no channel

---

## State Management

### New Private Properties

```swift
private var signallingChannel: RealtimeChannelV2?
private var otherPlayerId: UUID?
```

**Note:** `RealtimeChannelV2` is a Supabase SDK implementation detail. The conceptual contract is "Realtime channel reference" regardless of exact API type.

**signallingChannel:**
- Holds reference to Realtime channel
- Must be retained to keep subscription alive
- Set in `setupSignallingChannel`, cleared in `teardownSignallingChannel`

**otherPlayerId:**
- Stores the other player's UUID for message routing
- Set in `setupSignallingChannel`, cleared in `teardownSignallingChannel`
- Used in all send methods for `to` field

---

## Dependencies Added

```swift
private let supabaseService = SupabaseService.shared
private let authService = AuthService.shared
```

**supabaseService:**
- Access to Supabase client
- Used for creating Realtime channels

**authService:**
- Access to current user ID
- Used for `from` field in messages

---

## Logging Strategy

### Log Format

```
🔊 [VoiceSignalling] <action>: <details>
✅ [VoiceSignalling] Success: <details>
⚠️ [VoiceSignalling] Warning: <details>
❌ [VoiceSignalling] Error: <details>
ℹ️ [VoiceSignalling] Info: <details>
```

### Logged Events

**Channel management:**
- Setting up channel (with match ID prefix)
- Channel name
- Subscription status (subscribed, timed out, error)
- Teardown process

**Message sending:**
- SEND voice_offer (with recipient and session ID prefix)
- SEND voice_answer (with recipient and session ID prefix)
- SEND voice_ice_candidate (with recipient)
- SEND voice_disconnect (with recipient and reason)

**SDP logging guidance:**
- Default logs use concise identifiers and session prefixes
- Full SDP payload logging is for deep debugging only
- Avoid unnecessary verbosity in normal operation logs

**Errors:**
- Cannot send: no active session
- Cannot send: no other player ID
- Cannot send: not authenticated
- Cannot send: no channel
- Failed to send disconnect (best-effort)

---

## Error Handling

### Throwing Errors

**Methods that throw:**
- `setupSignallingChannel` — throws on subscription failure
- `sendOffer` — throws on guard failures or send failure
- `sendAnswer` — throws on guard failures or send failure
- `sendICECandidate` — throws on guard failures or send failure

**Methods that don't throw:**
- `teardownSignallingChannel` — always succeeds
- `sendDisconnect` — best-effort, returns early on failure

### Error Types

From `VoiceSessionError` enum:
- `.signallingTimeout` — channel subscription timed out
- `.signallingFailed(reason:)` — channel error, no channel, auth failure
- `.sessionNotActive` — no active session when trying to send

---

## Integration Points

### Not Yet Integrated

These methods are private and not yet called from anywhere:

- `setupSignallingChannel` — will be called when starting voice session (Task 7-9)
- `teardownSignallingChannel` — will be called when ending voice session (Task 13-15)
- `sendOffer` — will be called after creating WebRTC offer (Task 7-9)
- `sendAnswer` — will be called after creating WebRTC answer (Task 7-9)
- `sendICECandidate` — will be called when ICE candidates discovered (Task 7-9)
- `sendDisconnect` — will be called when ending session (Task 13-15)

### Future Integration (Task 7-9)

Voice engine will call these methods:

```swift
// When receiver creates offer
try await setupSignallingChannel(matchId: matchId, otherPlayerId: challengerId)
try await sendOffer(sdp)

// When challenger receives offer and creates answer
try await setupSignallingChannel(matchId: matchId, otherPlayerId: receiverId)
try await sendAnswer(sdp)

// When ICE candidates discovered
try await sendICECandidate(candidate: candidate, sdpMid: mid, sdpMLineIndex: index)
```

### Future Integration (Task 13-15)

Lifecycle management will call:

```swift
// When ending session
try await sendDisconnect(reason: .user_exit)
await teardownSignallingChannel()
```

**Critical teardown ordering:**
1. Best-effort send disconnect if possible
2. Tear down local channel/session **regardless of send result**
3. Teardown must proceed even if disconnect send fails

This ordering is essential to avoid teardown order bugs where cleanup is blocked by send failures.

---

## Design Decisions

### Decision 1: AnyCodable for Payload

**Chosen:** Use `[String: AnyCodable]` for message payload

**Rationale:**
- Supabase Realtime expects JSON-serializable dictionaries
- Enum-based `VoiceSignallingPayload` would require custom encoding
- Simpler to encode typed payloads to dictionaries
- Follows Task 4 note about implementation flexibility

**Trade-off:**
- Less type-safe at message envelope level
- Type safety maintained at individual payload level
- Acceptable for this use case

### Decision 2: Generic sendMessage Method

**Chosen:** Single generic method for all message types

**Rationale:**
- DRY principle - envelope creation logic shared
- Consistent error handling
- Single point for logging and debugging
- Easy to add new message types

**Alternative considered:**
- Separate send methods with duplicated envelope logic
- Rejected: too much duplication

### Decision 3: Best-Effort Disconnect

**Chosen:** `sendDisconnect` returns early instead of throwing

**Rationale:**
- Follows Task 4 contract: disconnect is courtesy signal
- Correctness must not depend on receiving disconnect
- Cleanup should proceed even if send fails
- Matches "best-effort only" philosophy

**Implementation:**
- Guards return early instead of throwing
- Catch send errors and log without throwing

### Decision 4: Channel Naming

**Chosen:** `voice_match_{matchId.uuidString}`

**Rationale:**
- Follows Task 4 contract
- Match-specific channels prevent cross-match leakage
- Comment notes alignment with existing patterns
- Can be adjusted if app has different convention

### Decision 5: Private Methods

**Chosen:** All send methods are private

**Rationale:**
- Not yet ready for external use (no WebRTC integration)
- Will be called internally by voice engine (Task 7-9)
- Prevents premature usage
- Can make public later if needed

---

## Testing Strategy

### Manual Testing (Not Yet Possible)

Cannot test until:
- WebRTC integration (Task 7-9)
- Receive implementation (Task 6)
- Full lifecycle integration (Task 13-15)

### Future Testing

**Unit tests:**
- Message envelope creation
- Payload encoding
- Error handling

**Integration tests:**
- Channel subscription
- Message sending
- Round-trip with Task 6 receive

**End-to-end tests:**
- Full offer/answer exchange
- ICE candidate exchange
- Disconnect signalling

**Task 6 validation assumption:**

The send-side implementation assumes Task 6 will validate received messages for:
- `matchId` matches current match
- `from` matches expected peer
- `to` matches current user
- `sessionId` matches current session

This boundary makes send responsible for correct envelope creation, and receive responsible for validation before acting on messages.

---

## Known Limitations

### What This Task Does NOT Include

- ❌ No receive implementation (Task 6)
- ❌ No message validation (Task 6)
- ❌ No WebRTC integration (Task 7-9)
- ❌ No actual usage of send methods (Task 7-9)
- ❌ No lifecycle integration (Task 13-15)

### Why These Are Deferred

- Task 5 is send-only
- Receive comes in Task 6
- Actual usage comes in Tasks 7-9 and 13-15
- This establishes the sending infrastructure

---

## Success Criteria for Task 5

This task is complete when:

- ✅ Supabase import added
- ✅ All message type definitions implemented
- ✅ Channel setup/teardown methods implemented
- ✅ Send methods for all message types implemented (offer, answer, ICE, disconnect)
- ✅ Generic sendMessage infrastructure implemented
- ✅ Error handling implemented
- ✅ Logging strategy implemented
- ✅ Best-effort disconnect behavior implemented
- ✅ Implementation is complete and ready for build verification

**Approval checkpoint:** Signalling send implementation reviewed and accepted before Task 6 begins.

---

## Next Task

**Task 6:** Implement signalling receive

This will implement the methods to receive and validate offer/answer/ICE candidates from Supabase Realtime, completing the signalling layer.
