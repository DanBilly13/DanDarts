# Voice/WebRTC Log Cleanup Plan

## Goal
Mute verbose voice/WebRTC logs while keeping only essential state changes:
- Voice session started
- Voice connected
- Voice failed
- Voice disconnected

## Logs to Remove/Mute

### 1. Channel Setup Verbosity (lines ~850-893)
**Remove:**
- Full channel setup banner
- Match ID, player ID dumps
- Channel name, event name details
- Thread info, message keys
- Broadcast callback fired banners

**Keep:**
- Simple "Voice signalling channel ready" on success
- "Voice signalling failed: [error]" on failure

### 2. SDP Exchange Logs (lines ~980-1400)
**Remove:**
- Raw SDP dumps
- "Creating offer", "Creating answer" details
- "Setting remote description" details
- Offer/answer payload extraction logs

**Keep:**
- Nothing (handled by connection state)

### 3. ICE Candidate Spam (lines ~1040-1070, 1428-1453)
**Remove:**
- "Sending ICE candidate" logs
- "Received ICE candidate" logs
- Candidate payload details
- sdpMid, sdpMLineIndex details

**Keep:**
- Nothing (too verbose, not useful)

### 4. Peer Connection State Spam (lines ~1700-1800)
**Remove:**
- Every state transition log
- "Peer connection state changed" spam
- Route change logs
- Audio session route changes

**Keep:**
- Only final "connected" state
- Only "failed" or "disconnected" states

### 5. Message Routing Verbosity (lines ~1100-1300)
**Remove:**
- "SEND voice_ready" logs
- "RECV voice_offer" logs
- "SEND voice_answer" logs
- "Processing voice_ready" logs
- Payload extraction details

**Keep:**
- Nothing (handled by connection state)

## Logs to Keep

### Essential State Changes Only
1. **Session Started:**
   ```
   🔊 Voice session started: match=[id] role=[role]
   ```

2. **Connection Established:**
   ```
   ✅ Voice connected
   ```

3. **Connection Failed:**
   ```
   ❌ Voice failed: [reason]
   ```

4. **Session Ended:**
   ```
   🔊 Voice disconnected: [reason]
   ```

## Implementation Strategy

Create a `VoiceDebugMode` flag (default: false) to control verbosity:
- When false: Only log essential state changes
- When true: Log everything (for debugging voice issues)

This allows easy debugging when voice IS the bug, while keeping logs clean normally.
