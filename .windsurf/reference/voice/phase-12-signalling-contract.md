# Phase 12 — Signalling Contract
## Task 5: Define Signalling Contract for WebRTC

## Purpose

This document defines the signalling protocol for peer-to-peer voice chat in remote matches.

Signalling is the mechanism by which two peers exchange connection information (SDP offers/answers and ICE candidates) to establish a direct WebRTC connection. This contract ensures both players follow the same protocol for reliable connection establishment.

---

## 1. Transport Layer

### Supabase Realtime

**Channel:**
- Channel name: `voice:match:{matchId}`
- Example: `voice:match:a1b2c3d4-e5f6-7890-abcd-ef1234567890`

**Why Supabase Realtime:**
- Already integrated in the app
- Real-time bidirectional messaging
- Presence tracking available
- Automatic reconnection
- No additional infrastructure needed

**Channel Lifecycle:**
- Subscribe when voice session starts (`.preparing` state)
- Unsubscribe when voice session ends (`.ended` state)
- Each player subscribes to the same channel

---

## 2. Message Types

### 2.1 Offer Message

**Sent by:** Challenger (initiator)

**When:** After audio session configured, before ICE gathering complete

**Payload:**
```json
{
  "type": "offer",
  "from": "challenger-user-id",
  "to": "receiver-user-id",
  "matchId": "match-uuid",
  "sessionToken": "session-token-uuid",
  "sdp": "v=0\r\no=- ...",
  "timestamp": "2026-03-15T14:19:00.000Z"
}
```

**Fields:**
- `type`: Always `"offer"`
- `from`: Challenger's user ID (UUID string)
- `to`: Receiver's user ID (UUID string)
- `matchId`: Remote match ID (UUID string)
- `sessionToken`: Voice session token (UUID string) for validation
- `sdp`: SDP offer string from RTCPeerConnection
- `timestamp`: ISO 8601 timestamp

### 2.2 Answer Message

**Sent by:** Receiver (responder)

**When:** After receiving offer, creating answer, setting local description

**Payload:**
```json
{
  "type": "answer",
  "from": "receiver-user-id",
  "to": "challenger-user-id",
  "matchId": "match-uuid",
  "sessionToken": "session-token-uuid",
  "sdp": "v=0\r\no=- ...",
  "timestamp": "2026-03-15T14:19:01.000Z"
}
```

**Fields:**
- `type`: Always `"answer"`
- `from`: Receiver's user ID (UUID string)
- `to`: Challenger's user ID (UUID string)
- `matchId`: Remote match ID (UUID string)
- `sessionToken`: Voice session token (UUID string) for validation
- `sdp`: SDP answer string from RTCPeerConnection
- `timestamp`: ISO 8601 timestamp

### 2.3 ICE Candidate Message

**Sent by:** Both players

**When:** As ICE candidates are discovered during connection establishment

**Payload:**
```json
{
  "type": "ice-candidate",
  "from": "sender-user-id",
  "to": "recipient-user-id",
  "matchId": "match-uuid",
  "sessionToken": "session-token-uuid",
  "candidate": "candidate:1 1 UDP 2130706431 192.168.1.100 54321 typ host",
  "sdpMid": "0",
  "sdpMLineIndex": 0,
  "timestamp": "2026-03-15T14:19:02.000Z"
}
```

**Fields:**
- `type`: Always `"ice-candidate"`
- `from`: Sender's user ID (UUID string)
- `to`: Recipient's user ID (UUID string)
- `matchId`: Remote match ID (UUID string)
- `sessionToken`: Voice session token (UUID string) for validation
- `candidate`: ICE candidate string
- `sdpMid`: Media stream ID (string)
- `sdpMLineIndex`: Media line index (number)
- `timestamp`: ISO 8601 timestamp

### 2.4 Error Message (Optional)

**Sent by:** Either player

**When:** Signalling or connection error occurs

**Payload:**
```json
{
  "type": "error",
  "from": "sender-user-id",
  "to": "recipient-user-id",
  "matchId": "match-uuid",
  "sessionToken": "session-token-uuid",
  "error": "ice-negotiation-failed",
  "message": "No valid ICE candidates found",
  "timestamp": "2026-03-15T14:19:05.000Z"
}
```

**Fields:**
- `type`: Always `"error"`
- `from`: Sender's user ID (UUID string)
- `to`: Recipient's user ID (UUID string)
- `matchId`: Remote match ID (UUID string)
- `sessionToken`: Voice session token (UUID string) for validation
- `error`: Error code (string)
- `message`: Human-readable error message (string)
- `timestamp`: ISO 8601 timestamp

---

## 3. Signalling Flow

### 3.1 Standard Flow (STUN Success)

```
Challenger                          Receiver
    |                                   |
    | 1. Subscribe to channel           |
    |---------------------------------->|
    |                                   | 2. Subscribe to channel
    |                                   |<--
    |                                   |
    | 3. Create offer                   |
    | 4. Set local description          |
    | 5. Send OFFER message             |
    |---------------------------------->|
    |                                   | 6. Receive OFFER
    |                                   | 7. Set remote description
    |                                   | 8. Create answer
    |                                   | 9. Set local description
    |                                   | 10. Send ANSWER message
    |<----------------------------------|
    | 11. Receive ANSWER                |
    | 12. Set remote description        |
    |                                   |
    | 13. ICE gathering starts          | 14. ICE gathering starts
    | 15. Send ICE-CANDIDATE            |
    |---------------------------------->|
    |                                   | 16. Add ICE candidate
    |                                   | 17. Send ICE-CANDIDATE
    |<----------------------------------|
    | 18. Add ICE candidate             |
    |                                   |
    | (Multiple ICE candidates exchanged)|
    |<--------------------------------->|
    |                                   |
    | 19. Connection established        |
    |===================================|
    | 20. Audio streams active          |
```

### 3.2 Failure Flow (STUN Fails)

```
Challenger                          Receiver
    |                                   |
    | 1-12. Same as standard flow       |
    |<--------------------------------->|
    |                                   |
    | 13. ICE gathering starts          | 14. ICE gathering starts
    | 15. Send ICE-CANDIDATE            |
    |---------------------------------->|
    |                                   | 16. Add ICE candidate
    |                                   | 17. Send ICE-CANDIDATE
    |<----------------------------------|
    | 18. Add ICE candidate             |
    |                                   |
    | 19. ICE negotiation timeout       | 20. ICE negotiation timeout
    | 21. Transition to unavailable     | 22. Transition to unavailable
    |                                   |
    | 23. Send ERROR message (optional) |
    |---------------------------------->|
    |                                   | 24. Receive ERROR
    |                                   | 25. Transition to unavailable
```

---

## 4. Role Assignment

### Challenger = Initiator

**Responsibilities:**
- Creates SDP offer
- Sends offer first
- Waits for answer
- Initiates ICE gathering

**User ID:**
- `match.challengerId`

### Receiver = Responder

**Responsibilities:**
- Waits for offer
- Creates SDP answer
- Sends answer in response
- Responds to ICE candidates

**User ID:**
- `match.receiverId`

### Why This Assignment?

- Deterministic (no race conditions)
- Matches existing remote match roles
- Clear responsibility separation
- No negotiation needed

---

## 5. Message Validation

### Incoming Message Validation

**All messages must validate:**

1. **Session Token Match**
   ```swift
   guard message.sessionToken == activeSession?.sessionToken else {
       // Stale message, ignore
       return
   }
   ```

2. **Match ID Match**
   ```swift
   guard message.matchId == activeSession?.matchId else {
       // Wrong match, ignore
       return
   }
   ```

3. **Recipient Match**
   ```swift
   guard message.to == currentUserId else {
       // Not for us, ignore
       return
   }
   ```

4. **Sender Validation**
   ```swift
   guard message.from == expectedPeerId else {
       // Unknown sender, ignore
       return
   }
   ```

5. **Type Validation**
   ```swift
   guard ["offer", "answer", "ice-candidate", "error"].contains(message.type) else {
       // Unknown type, ignore
       return
   }
   ```

### Why Strict Validation?

- Prevents stale messages from old sessions
- Prevents cross-match contamination
- Prevents spoofing
- Ensures message ordering integrity

---

## 6. Timing and Timeouts

### Connection Timeout

**Duration:** 10 seconds

**Starts:** When offer is sent (challenger) or received (receiver)

**Triggers:** If no connection established within timeout

**Action:** Transition to `.unavailable` state

### ICE Gathering Timeout

**Duration:** 5 seconds

**Starts:** When ICE gathering begins

**Triggers:** If no valid candidates found within timeout

**Action:** Transition to `.unavailable` state

### Message Delivery

**No Retry:** Phase 12 does not retry failed messages

**No Acknowledgment:** Messages are fire-and-forget

**Assumption:** Supabase Realtime handles delivery reliability

---

## 7. Channel Subscription

### Subscribe

**When:** Voice session transitions to `.preparing`

**Channel:** `voice:match:{matchId}`

**Callback:**
```swift
channel.on("broadcast", filter: ChannelFilter(event: "voice-signal")) { message in
    handleSignallingMessage(message)
}
```

### Unsubscribe

**When:** Voice session transitions to `.ended`

**Action:**
```swift
await channel.unsubscribe()
```

**Cleanup:**
- Remove all message handlers
- Clear pending messages
- Cancel any in-flight operations

---

## 8. Error Handling

### Signalling Errors

**Offer Creation Failed:**
- Log error
- Transition to `.unavailable`
- Do not send offer

**Answer Creation Failed:**
- Log error
- Transition to `.unavailable`
- Do not send answer

**ICE Candidate Error:**
- Log error
- Continue (non-fatal)
- Other candidates may succeed

**Channel Subscription Failed:**
- Log error
- Transition to `.unavailable`
- Cannot proceed without signalling

### Non-Blocking Principle

**All signalling errors are non-blocking:**
- Match continues normally
- Gameplay unaffected
- User sees "Voice not available"
- No disruptive alerts

---

## 9. TURN-Ready Design

### Current (Phase 12)

**STUN Only:**
```json
{
  "iceServers": [
    {
      "urls": "stun:stun.l.google.com:19302"
    }
  ]
}
```

### Future (TURN Support)

**STUN + TURN:**
```json
{
  "iceServers": [
    {
      "urls": "stun:stun.l.google.com:19302"
    },
    {
      "urls": "turn:turn.example.com:3478",
      "username": "user",
      "credential": "pass"
    }
  ]
}
```

**Contract Compatibility:**
- Message types unchanged
- Flow unchanged
- Only ICE server configuration changes
- No signalling protocol changes needed

---

## 10. Message Size Limits

### Supabase Realtime Limits

**Maximum Message Size:** 256 KB (estimated)

**Typical Sizes:**
- Offer SDP: ~2-5 KB
- Answer SDP: ~2-5 KB
- ICE Candidate: ~100-200 bytes

**Safety Margin:** Well within limits

---

## 11. Security Considerations

### No Encryption in Signalling

**Signalling messages are not encrypted** in Phase 12.

**Why:**
- Supabase Realtime uses WSS (encrypted transport)
- SDP and ICE candidates are not sensitive
- WebRTC media streams are encrypted (DTLS-SRTP)

**Future Enhancement:**
- Could add E2E encryption for signalling
- Not required for Phase 12 MVP

### Session Token Validation

**Purpose:**
- Prevents replay attacks
- Prevents cross-session contamination
- Ensures message freshness

**Implementation:**
- Every message includes session token
- Receiver validates token matches active session
- Stale tokens are rejected

---

## 12. Logging

### Message Logging

**Sent Messages:**
```
🔊 [Signalling] Sent OFFER to receiver-id (token: abc123...)
🔊 [Signalling] Sent ICE-CANDIDATE to receiver-id
```

**Received Messages:**
```
🔊 [Signalling] Received ANSWER from challenger-id
🔊 [Signalling] Received ICE-CANDIDATE from challenger-id
```

**Validation Failures:**
```
⚠️ [Signalling] Rejected message - stale session token
⚠️ [Signalling] Rejected message - wrong match ID
```

**Errors:**
```
❌ [Signalling] Failed to create offer: error-description
❌ [Signalling] Channel subscription failed: error-description
```

---

## 13. Swift Type Definitions

### SignallingMessage

```swift
struct SignallingMessage: Codable {
    let type: SignallingMessageType
    let from: UUID
    let to: UUID
    let matchId: UUID
    let sessionToken: UUID
    let timestamp: Date
    
    // Type-specific fields
    let sdp: String?              // For offer/answer
    let candidate: String?        // For ice-candidate
    let sdpMid: String?          // For ice-candidate
    let sdpMLineIndex: Int?      // For ice-candidate
    let error: String?           // For error
    let message: String?         // For error
}

enum SignallingMessageType: String, Codable {
    case offer = "offer"
    case answer = "answer"
    case iceCandidate = "ice-candidate"
    case error = "error"
}
```

---

## 14. What This Task Does Not Include

This task defines the **contract only**.

It does not implement:

- Supabase Realtime subscription code (Task 6)
- Message sending/receiving logic (Task 6)
- WebRTC peer connection code (Task 9)
- Audio session configuration (Task 8)
- UI components (Task 11+)

---

## 15. Approval Checkpoint

Task 5 is complete when:

- ✅ Message types defined (offer, answer, ice-candidate, error)
- ✅ Message payloads specified with all required fields
- ✅ Signalling flow documented (standard and failure)
- ✅ Role assignment clear (challenger = initiator, receiver = responder)
- ✅ Validation rules specified (session token, match ID, recipient, sender)
- ✅ Timing and timeouts defined (10s connection, 5s ICE)
- ✅ Channel subscription pattern specified
- ✅ Error handling strategy defined (non-blocking)
- ✅ TURN-ready design confirmed (ICE server config only)
- ✅ Swift type definitions provided
- ✅ Ready for Task 6 implementation

---

## Summary

This signalling contract establishes:

- **Transport:** Supabase Realtime channel per match
- **Messages:** Offer, Answer, ICE Candidate, Error
- **Roles:** Challenger initiates, Receiver responds
- **Validation:** Session token, match ID, recipient checks
- **Timeouts:** 10s connection, 5s ICE gathering
- **Error Handling:** Non-blocking, transition to unavailable
- **TURN-Ready:** ICE server config change only
- **Security:** Session token validation, WSS transport

This contract will be implemented in Task 6 (Supabase Realtime signalling) and used by Task 9 (WebRTC peer connection).
