# Task 4 — Signalling Message Contract
**Phase:** 12  
**Sub-phase:** B (Signalling)  
**Status:** Defined  
**Date:** 2026-03-14

---

## Purpose

This task defines the exact message payloads for WebRTC signalling over Supabase Realtime. This establishes the contract between the two peers for offer/answer/ICE candidate exchange before any implementation begins.

---

## Signalling Transport

### Supabase Realtime Channel

**Channel naming:**
```
voice_match_{matchId}
```

**Example:**
```
voice_match_a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

**Why match-specific channels:**
- Each remote match gets its own voice signalling channel
- Prevents cross-match signal leakage
- Automatic cleanup when match ends

**Important alignment note:**
- This is the preferred Phase 12 design, assuming Supabase Realtime channel fan-out and lifecycle are acceptable at the match level
- **If the app already has an existing per-match channel pattern for remote matches, align with that rather than creating a parallel voice-specific channel convention**
- The goal is to avoid diverging from existing remote match channel architecture unless there is a strong reason

### Channel Lifecycle

**Subscribed:** When voice session starts (receiver enters lobby, challenger joins)  
**Unsubscribed:** When either player exits remote match flow or voice session ends  
**Backend cleanup:** Implementation-managed / implicit (Supabase handles cleanup after all clients disconnect)

**Note:** Realtime channels are primarily a subscribe/unsubscribe concept rather than explicitly created/destroyed resources in the product sense

---

## Message Envelope

### Base Message Structure

All voice signalling messages follow this envelope:

```typescript
{
  type: "voice_offer" | "voice_answer" | "voice_ice_candidate" | "voice_disconnect",
  from: string,        // UUID of sender
  to: string,          // UUID of recipient
  matchId: string,     // UUID of match (validation)
  timestamp: string,   // ISO 8601 timestamp
  payload: object      // Type-specific payload
}
```

**Field descriptions:**

- **type** — Message type discriminator
- **from** — Sender's user ID (for validation and routing)
- **to** — Recipient's user ID (for validation and routing)
- **matchId** — Match UUID (ensures message belongs to current match)
- **timestamp** — When message was sent (for debugging and inspection only)
- **payload** — Type-specific data (defined below)

### Why This Envelope

**Validation:**
- `matchId` ensures message belongs to current match
- `from`/`to` prevent signal spoofing
- `timestamp` helps debug ordering issues

**Routing:**
- Recipient can ignore messages not addressed to them
- Sender can track which messages were sent

**Debugging:**
- Clear message type for logging
- Timestamp for diagnostic inspection (not authoritative for ordering)
- Complete context in each message

**Important:** Signalling correctness must not rely on precise client timestamp ordering. Client clocks are not authoritative enough for protocol correctness.

---

## Message Types

### 1. Voice Offer

**Type:** `voice_offer`

**Purpose:** Receiver sends WebRTC offer to challenger after creating peer connection

**Payload:**
```typescript
{
  sdp: string,           // Session Description Protocol offer
  sessionId: string      // Voice session UUID (canonical for entire handshake)
}
```

**Session ID ownership:**
- The receiver generates the canonical `sessionId` when creating the offer
- This `sessionId` is used for the entire handshake (offer, answer, all ICE candidates)
- The answer and all subsequent ICE candidates must reuse exactly this same `sessionId` value
- Any message with a mismatched `sessionId` is rejected

**Example:**
```json
{
  "type": "voice_offer",
  "from": "receiver-user-id",
  "to": "challenger-user-id",
  "matchId": "match-uuid",
  "timestamp": "2026-03-14T13:00:00.000Z",
  "payload": {
    "sdp": "v=0\r\no=- 123456789 2 IN IP4 127.0.0.1\r\n...",
    "sessionId": "voice-session-uuid"
  }
}
```

**Flow position:** First message in handshake

**Sender:** Receiver (the player who accepted the challenge)

**Recipient:** Challenger (the player who created the challenge)

---

### 2. Voice Answer

**Type:** `voice_answer`

**Purpose:** Challenger responds with WebRTC answer after receiving offer

**Payload:**
```typescript
{
  sdp: string,           // Session Description Protocol answer
  sessionId: string      // Voice session UUID (must match offer)
}
```

**Example:**
```json
{
  "type": "voice_answer",
  "from": "challenger-user-id",
  "to": "receiver-user-id",
  "matchId": "match-uuid",
  "timestamp": "2026-03-14T13:00:01.500Z",
  "payload": {
    "sdp": "v=0\r\no=- 987654321 2 IN IP4 127.0.0.1\r\n...",
    "sessionId": "voice-session-uuid"
  }
}
```

**Flow position:** Second message in handshake

**Sender:** Challenger

**Recipient:** Receiver

**Validation:** `sessionId` must exactly match the receiver-generated offer's `sessionId` (canonical for entire handshake)

---

### 3. Voice ICE Candidate

**Type:** `voice_ice_candidate`

**Purpose:** Either peer sends ICE candidates as they are discovered

**Payload:**
```typescript
{
  candidate: string,     // ICE candidate string
  sdpMid: string,        // Media stream ID
  sdpMLineIndex: number, // Media line index
  sessionId: string      // Voice session UUID
}
```

**Example:**
```json
{
  "type": "voice_ice_candidate",
  "from": "receiver-user-id",
  "to": "challenger-user-id",
  "matchId": "match-uuid",
  "timestamp": "2026-03-14T13:00:02.000Z",
  "payload": {
    "candidate": "candidate:1 1 UDP 2130706431 192.168.1.100 54321 typ host",
    "sdpMid": "0",
    "sdpMLineIndex": 0,
    "sessionId": "voice-session-uuid"
  }
}
```

**Flow position:** Multiple messages, sent as candidates are discovered

**Sender:** Either peer

**Recipient:** Other peer

**Frequency:** Multiple ICE candidates may be sent by each peer

**Timing:** Can arrive before, during, or after offer/answer exchange (trickle ICE)

**Note on `to` field:** While the channel is already match-scoped, the `to` field provides defensive validation and explicit routing metadata. It ensures messages are only processed by the intended recipient even if channel subscription boundaries are unexpectedly loose.

---

### 4. Voice Disconnect

**Type:** `voice_disconnect`

**Purpose:** Either peer signals intentional disconnect

**Payload:**
```typescript
{
  reason: "user_exit" | "session_ended" | "error",
  sessionId: string      // Voice session UUID
}
```

**Example:**
```json
{
  "type": "voice_disconnect",
  "from": "receiver-user-id",
  "to": "challenger-user-id",
  "matchId": "match-uuid",
  "timestamp": "2026-03-14T13:05:00.000Z",
  "payload": {
    "reason": "user_exit",
    "sessionId": "voice-session-uuid"
  }
}
```

**Flow position:** Final message (optional)

**Sender:** Either peer

**Recipient:** Other peer

**When sent:**
- User exits remote match flow
- Session is intentionally terminated
- Error forces disconnect

**Critical: Best-effort only**
- `voice_disconnect` is a courtesy/best-effort teardown signal
- **Correctness must not depend on receiving this message**
- Peers must handle abrupt exits, crashes, and network loss without receiving disconnect
- This message is purely for graceful cleanup when possible

---

## Message Flow Sequence

### Happy Path (Successful Connection)

```
Receiver                                    Challenger
   |                                             |
   | 1. Create peer connection                  |
   | 2. Create offer                            |
   | 3. Send voice_offer ---------------------->|
   |                                             | 4. Receive offer
   |                                             | 5. Create peer connection
   |                                             | 6. Set remote description (offer)
   |                                             | 7. Create answer
   | 8. Receive answer <----------------------- | 8. Send voice_answer
   | 9. Set remote description (answer)         |
   |                                             |
   | 10. Gather ICE candidates                  | 10. Gather ICE candidates
   | 11. Send voice_ice_candidate ------------->|
   |<------------------------------------------- | 11. Send voice_ice_candidate
   | 12. Add remote candidate                   | 12. Add remote candidate
   |                                             |
   | (Multiple ICE candidates exchanged)        |
   |                                             |
   | 13. Connection established                 | 13. Connection established
   | 14. Audio flowing                          | 14. Audio flowing
   |                                             |
   | ... match continues ...                    |
   |                                             |
   | 15. Send voice_disconnect ---------------->|
   | 16. Close connection                       | 16. Receive disconnect
   |                                             | 17. Close connection
```

### Failure Path (Connection Timeout)

```
Receiver                                    Challenger
   |                                             |
   | 1. Send voice_offer ---------------------->|
   |                                             | 2. Receive offer
   |                                             | (No answer sent - network issue)
   |                                             |
   | 3. Wait for answer...                      |
   | 4. Timeout (10 seconds)                    |
   | 5. Set state to disconnected               |
   | 6. Send voice_disconnect (optional) ------>|
   |                                             |
```

---

## Validation Rules

### Message Validation

Every received message must be validated:

1. **Envelope structure**
   - All required fields present
   - Types match expected schema
   - Timestamp is valid ISO 8601 (diagnostic only, not used for ordering)

2. **Match ID validation**
   - `matchId` matches current active match
   - Reject messages for different matches

3. **Sender/recipient validation**
   - `from` must match the other known participant in the active remote match
   - `to` must match the current authenticated user
   - Reject messages from unknown senders or incorrect recipients

4. **Session ID validation**
   - `sessionId` matches current voice session (receiver-generated canonical ID)
   - Reject messages for stale sessions
   - **Stale/late messages:** Messages for previous sessions or match contexts are ignored, even if they arrive late on the same channel subscription window

5. **Payload validation**
   - Type-specific payload structure is valid
   - Required fields present
   - SDP format is valid (for offer/answer)

### Invalid Message Handling

**Action:** Log error and ignore message

**Do NOT:**
- Show alert to user
- Terminate session
- Block match flow

**Rationale:**
- Signalling failures should not block match
- Invalid messages may be from stale sessions
- User should see "voice unavailable" state, not errors

---

## Timeout Configuration

**Note:** The following are **initial proposed defaults** for Phase 12. These values may be adjusted during implementation and testing based on real-world network behavior.

### Offer/Answer Timeout

**Proposed default:** 10 seconds

**Trigger:** Offer sent, no answer received

**Action:**
- Set connection state to `disconnected`
- Log timeout error
- Update UI to show "Voice not available"
- Do NOT block match flow

### ICE Gathering Timeout

**Proposed default:** 15 seconds

**Trigger:** Peer connection created, no ICE candidates gathered

**Action:**
- Set connection state to `disconnected`
- Log timeout error
- Update UI to show "Voice not available"
- Do NOT block match flow

### Connection Establishment Timeout

**Proposed default:** 20 seconds

**Trigger:** ICE candidates exchanged, connection not established

**Action:**
- Set connection state to `disconnected`
- Log timeout error
- Update UI to show "Voice not available"
- Do NOT block match flow

**Philosophy:** Timeouts are generous to account for slow networks. Phase 12 prioritizes avoiding false negatives over fast failure. These values will be validated during testing.

---

## Error Handling

### Signalling Errors

**Scenarios:**
- Realtime channel subscription fails
- Message publish fails
- Message receive fails
- Invalid message format

**Handling:**
- Log error with context
- Set `lastError` in session
- Update connection state to `disconnected`
- Update UI to show "Voice not available"
- Do NOT show alert
- Do NOT block match flow

### Network Errors

**Scenarios:**
- Realtime connection drops
- Message delivery fails
- Timeout waiting for response

**Handling:**
- Same as signalling errors
- No automatic reconnect in Phase 12
- Session stays in `disconnected` state

---

## Security Considerations

### Message Authentication

**Current approach (Phase 12):**
- Rely on Supabase Realtime's built-in authentication
- Users must be authenticated to subscribe to channels
- Row-level security on matches table ensures only participants can access match data

**Validation:**
- Check `from` field matches the other known participant in the active remote match
- Check `to` field matches the current authenticated user
- Check `matchId` matches current match
- Check `sessionId` matches current session

**Not implemented (Phase 12):**
- Message signing
- End-to-end encryption
- Additional authentication beyond Supabase

**Rationale:**
- Phase 12 relies on existing authenticated app/session infrastructure plus signalling validation
- Additional message signing or higher-level hardening is out of scope for this phase
- Supabase authentication is sufficient for MVP
- Can add signing/encryption in future phase if needed

### Replay Attack Prevention

**Risk:** Attacker replays old signalling messages

**Mitigation:**
- `sessionId` validation rejects messages from old sessions
- `matchId` validation rejects messages from other matches
- `timestamp` can be used to reject very old messages (optional)

**Not implemented (Phase 12):**
- Nonce-based replay prevention
- Message sequence numbers

**Rationale:**
- Low risk for voice chat signalling
- Session/match ID validation is sufficient
- Can add if real-world issues emerge

---

## Debugging Support

### Message Logging

**What to log:**
- All sent messages (type, to, timestamp)
- All received messages (type, from, timestamp)
- Validation failures (reason, message excerpt)
- Timeout events (type, duration)

**Log format:**
```
🔊 [VoiceSignalling] SEND voice_offer to challenger-id (session: abc123)
🔊 [VoiceSignalling] RECV voice_answer from challenger-id (session: abc123)
⚠️ [VoiceSignalling] INVALID message: matchId mismatch (expected: xyz, got: abc)
⏱️ [VoiceSignalling] TIMEOUT waiting for answer (10s elapsed)
```

### Message Inspection

**For debugging:**
- Include full SDP in logs (can be verbose)
- Include ICE candidate details
- Include validation failure details

**For production:**
- May want to truncate SDP in logs
- Keep ICE candidate logging
- Always log validation failures

---

## Swift Type Definitions

### Message Envelope

```swift
struct VoiceSignallingMessage: Codable {
    let type: VoiceSignallingMessageType
    let from: UUID
    let to: UUID
    let matchId: UUID
    let timestamp: Date
    let payload: VoiceSignallingPayload
}

enum VoiceSignallingMessageType: String, Codable {
    case voice_offer
    case voice_answer
    case voice_ice_candidate
    case voice_disconnect
}
```

### Payload Types

```swift
enum VoiceSignallingPayload: Codable {
    case offer(VoiceOfferPayload)
    case answer(VoiceAnswerPayload)
    case iceCandidate(VoiceICECandidatePayload)
    case disconnect(VoiceDisconnectPayload)
}

struct VoiceOfferPayload: Codable {
    let sdp: String
    let sessionId: UUID
}

struct VoiceAnswerPayload: Codable {
    let sdp: String
    let sessionId: UUID
}

struct VoiceICECandidatePayload: Codable {
    let candidate: String
    let sdpMid: String
    let sdpMLineIndex: Int
    let sessionId: UUID
}

struct VoiceDisconnectPayload: Codable {
    let reason: VoiceDisconnectReason
    let sessionId: UUID
}

enum VoiceDisconnectReason: String, Codable {
    case user_exit
    case session_ended
    case error
}
```

**Implementation note:**

The `VoiceSignallingPayload` enum representation is conceptually clean, but implementation may instead use a discriminated envelope with typed decode path per `type` if enum `Codable` becomes awkward with the chosen Realtime serialization format. The message contract matters more than the exact Swift enum representation.

---

## Integration with VoiceChatService

### New Methods (Task 5)

```swift
// Send methods
private func sendOffer(_ sdp: String) async throws
private func sendAnswer(_ sdp: String) async throws
private func sendICECandidate(_ candidate: RTCIceCandidate) async throws
private func sendDisconnect(reason: VoiceDisconnectReason) async throws

// Receive handler (Task 6)
private func handleSignallingMessage(_ message: VoiceSignallingMessage)
```

### Channel Management

```swift
private var signallingChannel: RealtimeChannel?

private func setupSignallingChannel(matchId: UUID) async throws
private func teardownSignallingChannel() async
```

---

## Success Criteria for Task 4

This task is complete when:

- ✅ Message envelope structure defined
- ✅ All message types defined (offer, answer, ICE candidate, disconnect)
- ✅ Message flow sequence documented
- ✅ Validation rules established
- ✅ Timeout configuration specified
- ✅ Error handling strategy defined
- ✅ Security considerations documented
- ✅ Swift type definitions provided
- ✅ Integration points with VoiceChatService identified

**Approval checkpoint:** Signalling contract reviewed and accepted before Task 5 begins.

---

## Next Task

**Task 5:** Implement signalling send

This will implement the methods to send offer/answer/ICE candidates over Supabase Realtime using the contract defined in this task.
