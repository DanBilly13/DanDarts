# Phase 12 Task 6 Complete: Supabase Realtime Signalling

## Implementation Summary

Implemented Supabase Realtime signalling for WebRTC peer connection establishment in `VoiceSessionService.swift`.

**File Modified:** `/DanDart/Services/VoiceSessionService.swift`

---

## What Was Implemented

### 1. Signalling Message Types

**SignallingMessageType Enum:**
```swift
enum SignallingMessageType: String, Codable {
    case offer, answer, iceCandidate, error
}
```

**SignallingMessage Struct:**
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
```

### 2. Dependencies Added

**Supabase Integration:**
- `import Supabase`
- `supabaseService = SupabaseService.shared`
- `authService = AuthService.shared`

**Realtime Channel Properties:**
- `signallingChannel: RealtimeChannelV2?` - Active channel
- `broadcastSubscription: Task<Void, Never>?` - Subscription token

### 3. Channel Management

**subscribeToSignallingChannel(matchId:)**
- Channel name: `voice:match:{matchId}`
- Broadcast configuration: `receiveOwnBroadcasts = false`
- Listens for `voice-signal` events
- Validates session before processing messages
- Transitions to `.connecting` state after subscription

**unsubscribeFromSignallingChannel()**
- Cancels broadcast subscription
- Unsubscribes from channel
- Clears channel reference
- Called when session ends

### 4. Message Handling

**handleSignallingMessage(_ payload:)**
- Decodes JSON payload to `SignallingMessage`
- Validates message (5-point validation)
- Routes to type-specific handler

**Message Validation (5 Checks):**
1. Session token matches active session
2. Match ID matches active session
3. Recipient is current user
4. Sender is expected peer (challenger or receiver)
5. Message type is valid

**Type-Specific Handlers:**
- `handleOffer()` - Logs SDP offer (WebRTC in Task 9+)
- `handleAnswer()` - Logs SDP answer (WebRTC in Task 9+)
- `handleIceCandidate()` - Logs ICE candidate (WebRTC in Task 9+)
- `handleError()` - Transitions to `.unavailable`

### 5. Message Sending

**sendOffer(sdp:)**
- Creates offer message with SDP
- Determines recipient (other player)
- Sends via Realtime broadcast
- Logs sent message

**sendAnswer(sdp:)**
- Creates answer message with SDP
- Determines recipient (other player)
- Sends via Realtime broadcast
- Logs sent message

**sendIceCandidate(candidate:sdpMid:sdpMLineIndex:)**
- Creates ICE candidate message
- Determines recipient (other player)
- Sends via Realtime broadcast
- Logs sent message

**sendSignallingMessage(_ message:)**
- Encodes message to JSON
- Sends via `channel.broadcast(event:message:)`
- ISO 8601 date encoding

### 6. Lifecycle Integration

**startSession() Updated:**
```swift
// Subscribe to signalling channel
Task {
    await subscribeToSignallingChannel(matchId: matchId)
}
```

**endSession() Updated:**
```swift
// Unsubscribe from signalling channel
Task {
    await unsubscribeFromSignallingChannel()
}
```

---

## Message Flow

### Offer/Answer Exchange

```
Challenger                          Receiver
    |                                   |
    | startSession()                    | startSession()
    | subscribe to channel              | subscribe to channel
    |                                   |
    | sendOffer(sdp)                    |
    |---------------------------------->|
    |                                   | handleOffer()
    |                                   | (Task 9+: create answer)
    |                                   | sendAnswer(sdp)
    |<----------------------------------|
    | handleAnswer()                    |
    | (Task 9+: set remote description) |
```

### ICE Candidate Exchange

```
Both Players
    |
    | (Task 9+: ICE gathering)
    | sendIceCandidate()
    |<--------------------------------->|
    | handleIceCandidate()              |
    | (Task 9+: add to peer connection) |
```

---

## Validation Rules

### Incoming Message Validation

**All messages must pass:**

1. **Session Token Match**
   ```swift
   message.sessionToken == activeSession?.sessionToken
   ```

2. **Match ID Match**
   ```swift
   message.matchId == activeSession?.matchId
   ```

3. **Recipient Match**
   ```swift
   message.to == currentUserId
   ```

4. **Sender Validation**
   ```swift
   message.from == match.challengerId || message.from == match.receiverId
   ```

5. **Type Validation**
   - Must be offer, answer, iceCandidate, or error

**Failed Validation:**
- Message logged and ignored
- No state changes
- No side effects

---

## Channel Configuration

### Channel Name Format

```
voice:match:{matchId}
```

**Example:**
```
voice:match:a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

### Broadcast Configuration

```swift
channel.broadcast.receiveOwnBroadcasts = false
```

**Why false:**
- Prevents receiving own messages
- Reduces unnecessary processing
- Peer messages only

### Event Name

```
voice-signal
```

**All signalling messages use this event.**

---

## Stale Callback Protection

### Session Capture Pattern

```swift
private func subscribeToSignallingChannel(matchId: UUID) async {
    guard let session = activeSession else { return }
    let capturedSession = session
    
    broadcastSubscription = Task { @MainActor in
        for await message in await channel.broadcast(event: "voice-signal") {
            // Validate session still active
            guard isSessionValid(capturedSession) else {
                print("⚠️ [Signalling] Stale message - session changed, ignoring")
                return
            }
            
            await handleSignallingMessage(message.payload)
        }
    }
}
```

**Protection:**
- Captures session identity at subscription time
- Validates on every message
- Ignores messages for old sessions
- Prevents stale state mutations

---

## Error Handling

### Decode Errors

**Failed to decode message:**
- Logs error
- Returns early
- No state changes

### Validation Errors

**Message validation failed:**
- Logs specific validation failure
- Returns early
- No state changes

### Channel Errors

**No active channel:**
- Logs warning
- Cannot send/receive
- Graceful degradation

### Error Messages

**Received error message:**
- Logs error code and message
- Transitions to `.unavailable`
- Non-blocking (match continues)

---

## Logging

### Channel Operations

```
🔊 [Signalling] Subscribing to channel: voice:match:a1b2c3d4...
✅ [Signalling] Subscribed to channel: voice:match:a1b2c3d4...
🔊 [Signalling] Unsubscribing from channel
✅ [Signalling] Unsubscribed from channel
```

### Message Sending

```
🔊 [Signalling] Sent OFFER to receiver-id...
🔊 [Signalling] Sent ANSWER to challenger-id...
🔊 [Signalling] Sent ICE-CANDIDATE to peer-id...
```

### Message Receiving

```
🔊 [Signalling] Received message: {payload}
🔊 [Signalling] Received OFFER from sender-id...
📝 [Signalling] SDP: v=0\r\no=- ...
🔊 [Signalling] Received ICE-CANDIDATE from sender-id...
📝 [Signalling] Candidate: candidate:1 1 UDP...
```

### Validation Failures

```
⚠️ [Signalling] Invalid session token
⚠️ [Signalling] Invalid match ID
⚠️ [Signalling] Message not for current user
⚠️ [Signalling] Message from unknown sender
⚠️ [Signalling] Stale message - session changed, ignoring
```

### Errors

```
❌ [Signalling] Failed to decode message
❌ [Signalling] No active channel, cannot send message
❌ [Signalling] Received ERROR from sender-id...
```

---

## What This Does NOT Include

Task 6 implements **signalling only**.

It does not implement:

- WebRTC peer connection (Task 9)
- Audio session configuration (Task 8)
- ICE server configuration (Task 9)
- Actual SDP offer/answer creation (Task 9)
- Actual ICE candidate handling (Task 9)
- UI components (Task 11+)

**Current State:**
- Messages are sent and received
- Validation works
- Handlers log messages
- Ready for WebRTC integration (Task 9)

---

## Testing Readiness

### Task 7: Test Signalling with Mock Peer

**What Can Be Tested:**
- Channel subscription/unsubscription
- Message encoding/decoding
- Message validation (5 checks)
- Stale message rejection
- Session token validation
- Match ID validation
- Recipient validation
- Sender validation

**Test Scenarios:**
1. Start session → subscribe to channel
2. Send offer → verify broadcast
3. Receive offer → verify validation
4. Send answer → verify broadcast
5. Receive answer → verify validation
6. Send ICE candidate → verify broadcast
7. Receive ICE candidate → verify validation
8. End session → unsubscribe from channel
9. Stale message → rejected
10. Wrong session token → rejected
11. Wrong match ID → rejected
12. Wrong recipient → rejected
13. Unknown sender → rejected

---

## Approval Checkpoint

Task 6 is complete when:

- ✅ Signalling message types defined (offer, answer, iceCandidate, error)
- ✅ Supabase Realtime channel integration
- ✅ Channel subscription/unsubscription
- ✅ Message encoding/decoding (JSON, ISO 8601 dates)
- ✅ 5-point message validation
- ✅ Stale callback protection
- ✅ Type-specific message handlers
- ✅ sendOffer(), sendAnswer(), sendIceCandidate() methods
- ✅ Comprehensive logging
- ✅ Error handling (non-blocking)
- ✅ Ready for Task 7 (testing)

---

## Summary

Task 6 implements the complete signalling layer:

- **Transport:** Supabase Realtime broadcast
- **Channel:** `voice:match:{matchId}`
- **Messages:** Offer, Answer, ICE Candidate, Error
- **Validation:** 5-point check (session, match, recipient, sender, type)
- **Protection:** Stale callback rejection
- **Handlers:** Placeholder for WebRTC (Task 9)
- **Lifecycle:** Integrated with startSession/endSession

**Next:** Task 7 - Test signalling with mock peer

**Status: ✅ Task 6 Complete - Signalling Layer Ready**
