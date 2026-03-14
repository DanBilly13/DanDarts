# Task 6 — Signalling Receive Implementation
**Phase:** 12  
**Sub-phase:** B (Signalling)  
**Status:** Implemented  
**Date:** 2026-03-14

---

## Purpose

This task implements the methods to receive and validate incoming offer/answer/ICE candidates from Supabase Realtime. This completes the signalling layer by adding the inbound message handling to complement Task 5's outbound sending.

---

## Implementation Summary

### File Modified

**Location:** `/DanDart/Services/VoiceChatService.swift`

**Changes:**
- Added broadcast listener in channel setup
- Added message envelope parsing and validation
- Added handler methods for all message types (offer, answer, ICE, disconnect)
- Added defensive validation for all message fields
- Added stale/late message rejection

---

## Broadcast Listener Setup

### Channel Setup Integration

Modified `setupSignallingChannel` to register broadcast listener:

```swift
// Listen for voice signalling messages
channel.onBroadcast(event: "voice_signal") { [weak self] message in
    Task { @MainActor in
        await self?.handleIncomingMessage(message)
    }
}
```

**Key decisions:**
- Uses `[weak self]` to avoid retain cycles
- Wraps in `Task { @MainActor }` to ensure main actor context
- Event name `"voice_signal"` matches Task 5 send implementation
- Registered before channel subscription

---

## Message Handling Flow

### handleIncomingMessage

```swift
private func handleIncomingMessage(_ message: JSONObject) async
```

**Process:**
1. Extract message envelope fields (type, from, to, matchId, payload)
2. Validate envelope structure (guard early return if invalid)
3. Call `validateMessage` for defensive validation
4. Route to type-specific handler based on message type

**Envelope extraction:**
- `type` → `VoiceSignallingMessageType` enum
- `from` → UUID (sender)
- `to` → UUID (recipient)
- `matchId` → UUID (match context)
- `payload` → JSONObject (type-specific data)

**Early rejection:**
- Invalid envelope structure → log and ignore
- Failed validation → log and ignore (validation logs specific reason)

---

## Defensive Validation

### validateMessage

```swift
private func validateMessage(
    type: VoiceSignallingMessageType,
    from: UUID,
    to: UUID,
    matchId: UUID
) -> Bool
```

**Validation rules (per Task 4 contract):**

1. **Active session exists**
   - Reject if no `currentSession`
   - Reason: Cannot process signalling without active voice session

2. **matchId matches current session**
   - Reject if `matchId != session.matchId`
   - Reason: Prevents cross-match message leakage

3. **from matches expected peer**
   - Reject if `from != otherPlayerId`
   - Reason: Only accept messages from known peer in active match
   - Trust boundary: `otherPlayerId` comes from match context, not peer data

4. **to matches current user**
   - Reject if `to != currentUser.id`
   - Reason: Defensive routing validation
   - Even though channel is match-scoped, explicit validation prevents misrouting

**All rejections are logged with specific reason for debugging.**

---

## Type-Specific Handlers

### handleOffer

```swift
private func handleOffer(from: UUID, payload: JSONObject) async
```

**Payload extraction:**
- `sdp` (String) — WebRTC offer SDP
- `sessionId` (UUID) — Voice session identifier

**Additional validation:**
- `sessionId` must match `currentSession.id`
- Rejects stale/late offers for old sessions

**Future integration (Task 7-9):**
- Pass SDP to WebRTC engine
- Engine creates answer and calls `sendAnswer`

### handleAnswer

```swift
private func handleAnswer(from: UUID, payload: JSONObject) async
```

**Payload extraction:**
- `sdp` (String) — WebRTC answer SDP
- `sessionId` (UUID) — Voice session identifier

**Additional validation:**
- `sessionId` must match `currentSession.id`
- Rejects stale/late answers for old sessions

**Future integration (Task 7-9):**
- Pass SDP to WebRTC engine
- Engine sets remote description

### handleICECandidate

```swift
private func handleICECandidate(from: UUID, payload: JSONObject) async
```

**Payload extraction:**
- `candidate` (String) — ICE candidate string
- `sdpMid` (String) — Media stream identifier
- `sdpMLineIndex` (Int) — Media line index
- `sessionId` (UUID) — Voice session identifier

**Additional validation:**
- `sessionId` must match `currentSession.id`
- Rejects stale/late ICE candidates for old sessions

**Future integration (Task 7-9):**
- Pass candidate to WebRTC engine
- Engine adds ICE candidate to peer connection

### handleDisconnect

```swift
private func handleDisconnect(from: UUID, payload: JSONObject) async
```

**Payload extraction:**
- `reason` (VoiceDisconnectReason) — Disconnect reason enum
- `sessionId` (UUID) — Voice session identifier (optional validation)

**Best-effort behavior:**
- Invalid payload → still process disconnect with `.error` reason
- SessionId mismatch → log warning but still process
- Always calls `handlePeerDisconnect` regardless of validation

**Rationale:**
- Disconnect is courtesy signal (per Task 4 contract)
- Better to process disconnect than ignore it
- Actual cleanup must handle abrupt disconnects anyway

### handlePeerDisconnect

```swift
private func handlePeerDisconnect(reason: VoiceDisconnectReason) async
```

**Purpose:** Centralized peer disconnect handling

**Current behavior:**
- Logs disconnect with reason
- Placeholder for Task 13-15 cleanup

**Future integration (Task 13-15):**
- Trigger session cleanup
- Update connection state
- Teardown voice engine
- Note: Must also handle abrupt disconnects (no message received)

---

## Stale/Late Message Handling

### SessionId Validation

All handlers (except disconnect) validate `sessionId`:

```swift
guard let session = currentSession, sessionId == session.id else {
    print("⚠️ [VoiceSignalling] <type> sessionId mismatch, ignoring (stale/late message)")
    return
}
```

**Purpose:**
- Reject messages for previous voice sessions
- Reject messages that arrive late after session ended
- Prevent processing outdated signalling data

**Example scenarios:**
- User ends session, new session starts, old ICE candidates arrive → rejected
- Session ends, late offer arrives → rejected
- Network delay causes old session messages to arrive → rejected

---

## Logging Strategy

### Log Format

```
📥 [VoiceSignalling] <action>: <details>
⚠️ [VoiceSignalling] <warning>: <details>
🔊 [VoiceSignalling] <info>: <details>
```

### Logged Events

**Message reception:**
- Received message (full JSONObject for debugging)
- RECV voice_offer (with sender prefix)
- RECV voice_answer (with sender prefix)
- RECV voice_ice_candidate (with sender prefix)
- RECV voice_disconnect (with sender prefix)

**Validation:**
- Invalid message envelope
- Received <type> but no active session
- Received <type> for different match (with match ID prefixes)
- Received <type> from unexpected sender (with sender prefixes)
- Received <type> for different user (with user ID prefixes)
- <Type> sessionId mismatch (stale/late message)

**Processing:**
- Valid <type> received (with session ID prefix)
- Processing disconnect (with reason)
- Peer disconnected (with reason)

---

## Error Handling

### Validation Failures

**Strategy:** Early return with logging

All validation failures:
1. Log specific rejection reason
2. Return early (do not process message)
3. Do not throw errors (silent rejection)

**Rationale:**
- Malformed/invalid messages should not crash service
- Peer errors should not affect local state
- Logging provides debugging visibility
- Silent rejection prevents attack vectors

### Best-Effort Disconnect

**Strategy:** Process even if invalid

Disconnect handling:
1. Attempt to extract payload
2. If invalid → use `.error` reason and process anyway
3. If sessionId mismatch → log warning and process anyway
4. Always call `handlePeerDisconnect`

**Rationale:**
- Disconnect is courtesy signal (per Task 4)
- Better to process than ignore
- Actual cleanup handles abrupt disconnects anyway

---

## Integration Points

### Current Integration

**setupSignallingChannel:**
- Broadcast listener registered
- Calls `handleIncomingMessage` for all `voice_signal` events

**Not Yet Integrated:**

All handler methods have TODO comments for Task 7-9 integration:

```swift
// TODO: Task 7-9 - Pass to WebRTC engine
```

### Future Integration (Task 7-9)

Voice engine will be called from handlers:

```swift
// In handleOffer
await voiceEngine.handleRemoteOffer(sdp: sdp)

// In handleAnswer
await voiceEngine.handleRemoteAnswer(sdp: sdp)

// In handleICECandidate
await voiceEngine.handleRemoteICECandidate(
    candidate: candidate,
    sdpMid: sdpMid,
    sdpMLineIndex: sdpMLineIndex
)
```

### Future Integration (Task 13-15)

Lifecycle management will be called from disconnect handler:

```swift
// In handlePeerDisconnect
await endSession()
```

**Critical note:** Lifecycle must also handle abrupt disconnects (no message received).

---

## Design Decisions

### Decision 1: Envelope Validation Before Type Routing

**Chosen:** Validate envelope structure before routing to type handlers

**Rationale:**
- Prevents type handlers from dealing with malformed envelopes
- Centralized validation logic
- Early rejection of invalid messages
- Type handlers can assume valid envelope

**Alternative considered:**
- Validate in each type handler
- Rejected: too much duplication

### Decision 2: Separate validateMessage Method

**Chosen:** Dedicated validation method with detailed logging

**Rationale:**
- Centralized validation rules (per Task 4 contract)
- Consistent rejection logging
- Easy to audit validation logic
- Single source of truth for validation rules

**Alternative considered:**
- Inline validation in handleIncomingMessage
- Rejected: too verbose, harder to maintain

### Decision 3: SessionId Validation in Type Handlers

**Chosen:** Each handler validates sessionId separately

**Rationale:**
- Stale/late message detection is type-specific concern
- Allows different behavior per type (e.g., disconnect is best-effort)
- Clear logging of which message type was stale
- Keeps envelope validation separate from payload validation

**Alternative considered:**
- Validate sessionId in envelope validation
- Rejected: envelope validation doesn't have access to payload

### Decision 4: Best-Effort Disconnect Processing

**Chosen:** Process disconnect even if payload invalid or sessionId mismatched

**Rationale:**
- Follows Task 4 contract: disconnect is courtesy signal
- Better to process than ignore
- Actual cleanup must handle abrupt disconnects anyway
- Graceful degradation

**Alternative considered:**
- Strict validation like other message types
- Rejected: contradicts best-effort philosophy

### Decision 5: MainActor Context for Message Handling

**Chosen:** Wrap broadcast callback in `Task { @MainActor }`

**Rationale:**
- Service is `@MainActor` class
- Published state must be updated on main actor
- Ensures thread safety
- Matches existing patterns in codebase

**Alternative considered:**
- Handle on background thread, dispatch to main for state updates
- Rejected: more complex, error-prone

### Decision 6: Weak Self in Broadcast Callback

**Chosen:** Use `[weak self]` capture in broadcast listener

**Rationale:**
- Prevents retain cycle (channel → callback → service → channel)
- Service can be deallocated even if channel still exists
- Standard Swift memory management practice

**Alternative considered:**
- Strong capture
- Rejected: creates retain cycle

---

## Validation Coverage

### Message Envelope Validation

✅ Type is valid VoiceSignallingMessageType enum  
✅ From is valid UUID  
✅ To is valid UUID  
✅ MatchId is valid UUID  
✅ Payload is valid JSONObject  

### Defensive Validation (per Task 4)

✅ Active session exists  
✅ MatchId matches current session  
✅ From matches expected peer (otherPlayerId)  
✅ To matches current user  

### Payload Validation

**Offer:**
✅ SDP is string  
✅ SessionId is valid UUID  
✅ SessionId matches current session  

**Answer:**
✅ SDP is string  
✅ SessionId is valid UUID  
✅ SessionId matches current session  

**ICE Candidate:**
✅ Candidate is string  
✅ SdpMid is string  
✅ SdpMLineIndex is number (converted to Int)  
✅ SessionId is valid UUID  
✅ SessionId matches current session  

**Disconnect:**
⚠️ Reason is valid enum (best-effort)  
⚠️ SessionId validation (optional, best-effort)  

---

## Testing Strategy

### Manual Testing (Not Yet Possible)

Cannot test until:
- WebRTC integration (Task 7-9)
- Full lifecycle integration (Task 13-15)
- Two devices or simulator + device setup

### Future Testing

**Unit tests:**
- Envelope parsing
- Validation logic (all rejection paths)
- Stale/late message rejection
- Best-effort disconnect handling

**Integration tests:**
- Round-trip with Task 5 send
- Message routing to correct handlers
- SessionId validation

**End-to-end tests:**
- Full offer/answer exchange
- ICE candidate exchange
- Disconnect signalling
- Stale message rejection
- Abrupt disconnect handling (no message)

---

## Known Limitations

### What This Task Does NOT Include

- ❌ No WebRTC engine integration (Task 7-9)
- ❌ No actual processing of SDP/ICE data (Task 7-9)
- ❌ No session cleanup on disconnect (Task 13-15)
- ❌ No handling of abrupt disconnects without message (Task 13-15)

### Why These Are Deferred

- Task 6 is receive-only
- WebRTC processing comes in Task 7-9
- Lifecycle management comes in Task 13-15
- This establishes the receiving infrastructure

---

## Relationship to Task 5

### Complementary Implementation

**Task 5 (Send):**
- Creates message envelopes
- Sends via broadcast
- Assumes Task 6 will validate on receive

**Task 6 (Receive):**
- Receives broadcast messages
- Validates envelopes (matchId, from, to, sessionId)
- Routes to handlers

**Boundary:**
- Send is responsible for correct envelope creation
- Receive is responsible for validation before acting
- Clear separation of concerns

### Message Flow

```
Peer A (Send)                    Peer B (Receive)
─────────────                    ────────────────
sendOffer(sdp)
  ↓
VoiceBroadcastMessage
  ↓
channel.broadcast()
                    ──────────→  onBroadcast callback
                                   ↓
                                 handleIncomingMessage
                                   ↓
                                 validateMessage
                                   ↓
                                 handleOffer
                                   ↓
                                 [TODO: WebRTC engine]
```

---

## Success Criteria for Task 6

This task is complete when:

- ✅ Broadcast listener registered in channel setup
- ✅ Message envelope parsing implemented
- ✅ Defensive validation implemented (matchId, from, to, sessionId)
- ✅ Handler methods for all message types implemented
- ✅ Stale/late message rejection implemented
- ✅ Best-effort disconnect handling implemented
- ✅ Logging strategy implemented
- ✅ Integration points documented with TODO comments
- ✅ Implementation is complete and ready for build verification

**Approval checkpoint:** Signalling receive implementation reviewed and accepted before Task 7 begins.

---

## Next Task

**Task 7-9:** Voice Engine Implementation

This will implement the WebRTC peer connection, audio session configuration, and integration with the signalling layer to enable actual voice communication.
