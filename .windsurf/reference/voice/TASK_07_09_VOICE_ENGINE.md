# Task 7-9 — Voice Engine Implementation
**Phase:** 12  
**Sub-phase:** C (Voice Engine)  
**Status:** Implemented  
**Date:** 2026-03-14

---

## Purpose

This task implements the WebRTC voice engine, including iOS audio session configuration, peer connection setup, and integration with the signalling layer. This completes the core voice infrastructure by adding actual audio transport capabilities.

---

## Implementation Summary

### Package Dependency Required

**⚠️ IMPORTANT: WebRTC Package Dependency**

Before the code will compile, the WebRTC Swift package must be added to the Xcode project:

**Package URL:** `https://github.com/stasel/WebRTC.git`  
**Version:** Latest (or specific version as needed)

**To add in Xcode:**
1. Open `DanDart.xcodeproj` in Xcode
2. Select the project in the navigator
3. Select the "DanDart" target
4. Go to "Package Dependencies" tab
5. Click "+" to add package
6. Enter package URL: `https://github.com/stasel/WebRTC.git`
7. Select version and add to target

**Alternative packages:**
- Official Google WebRTC (requires manual framework integration)
- Other Swift WebRTC wrappers (verify iOS support)

The `stasel/WebRTC` package is recommended as it provides a Swift-friendly wrapper around the Google WebRTC framework with SPM support.

### File Modified

**Location:** `/DanDart/Services/VoiceChatService.swift`

**Changes:**
- Added iOS audio session configuration (Task 7)
- Added WebRTC peer connection factory and setup (Task 8)
- Added offer/answer creation and handling (Task 8)
- Added ICE candidate handling (Task 8)
- Integrated WebRTC engine with signalling layer (Task 9)
- Added audio session activation/deactivation
- Added WebRTC resource cleanup

**New Imports:**
```swift
import AVFoundation  // iOS audio session
import WebRTC        // WebRTC framework (requires package dependency)
```

---

## Task 7: iOS Audio Session Configuration

### Audio Session Setup

```swift
private func configureAudioSession() throws
```

**Configuration:**
- Category: `.playAndRecord` (bidirectional audio)
- Mode: `.voiceChat` (optimized for voice communication)
- Options: `.allowBluetooth`, `.allowBluetoothA2DP` (Bluetooth headset support)
- Activation: `setActive(true)`

**Purpose:**
- Enables microphone recording and speaker playback
- Optimizes audio processing for voice chat
- Supports Bluetooth audio devices
- Allows background audio (screen lock support)

**Error Handling:**
- Throws `VoiceSessionError.audioSessionConfigurationFailed` on failure
- Logs category and mode on success

### Audio Session Teardown

```swift
private func deactivateAudioSession()
```

**Behavior:**
- Deactivates audio session with `.notifyOthersOnDeactivation`
- Allows other apps to resume audio
- Non-throwing (logs errors but continues)

---

## Task 8: WebRTC Peer Connection Setup

### Peer Connection Factory

```swift
private func initializePeerConnectionFactory()
```

**Initialization:**
- Calls `RTCInitializeSSL()` for WebRTC SSL support
- Creates `RTCPeerConnectionFactory` with default encoder/decoder factories
- Stores factory for creating peer connections

**Note:** Factory is initialized once and reused for all connections.

### Peer Connection Creation

```swift
private func createPeerConnection() throws
```

**Configuration:**
- ICE servers: Google STUN (`stun:stun.l.google.com:19302`)
- SDP semantics: `.unifiedPlan` (modern WebRTC standard)
- ICE gathering: `.gatherContinually` (continuous candidate gathering)
- Constraints: `DtlsSrtpKeyAgreement: true` (secure media)

**TURN-Ready Design:**
- ICE servers array can be extended with TURN servers later
- No architectural changes needed for TURN support
- Configuration is centralized in this method

### Local Audio Track

```swift
private func addLocalAudioTrack() throws
```

**Setup:**
- Creates audio source from factory
- Creates audio track with ID `"audio0"`
- Adds track to peer connection with stream ID `"stream0"`
- Stores track reference for later cleanup

**Purpose:**
- Captures microphone input
- Sends audio to remote peer
- Enables local mute functionality (future)

### Offer Creation

```swift
private func createOffer() async throws -> String
```

**Process:**
1. Create offer with constraints (audio only, no video)
2. Set offer as local description
3. Return SDP string for signalling

**Constraints:**
- `OfferToReceiveAudio: true`
- `OfferToReceiveVideo: false`

**Error Handling:**
- Throws `VoiceSessionError.peerConnectionFailed` on any failure
- Uses `withCheckedThrowingContinuation` for async/await bridge

### Answer Creation

```swift
private func createAnswer() async throws -> String
```

**Process:**
1. Create answer with constraints (audio only, no video)
2. Set answer as local description
3. Return SDP string for signalling

**Constraints:**
- Same as offer (audio only)

**Error Handling:**
- Same pattern as offer creation

### Remote Offer Handling

```swift
private func handleRemoteOffer(sdp: String) async throws
```

**Process:**
1. Create `RTCSessionDescription` with type `.offer`
2. Set as remote description on peer connection
3. Throws on failure

**Purpose:**
- Processes incoming offer from remote peer
- Prepares peer connection to create answer

### Remote Answer Handling

```swift
private func handleRemoteAnswer(sdp: String) async throws
```

**Process:**
1. Create `RTCSessionDescription` with type `.answer`
2. Set as remote description on peer connection
3. Throws on failure

**Purpose:**
- Completes offer/answer exchange
- Establishes media session

### ICE Candidate Handling

```swift
private func handleRemoteICECandidate(candidate: String, sdpMid: String, sdpMLineIndex: Int) async
```

**Process:**
1. Create `RTCIceCandidate` from parameters
2. Add to peer connection
3. Non-throwing (best-effort)

**Purpose:**
- Adds connectivity candidates from remote peer
- Enables NAT traversal
- Supports multiple network paths

### WebRTC Cleanup

```swift
private func cleanupWebRTC()
```

**Cleanup:**
- Clears local audio track reference
- Closes peer connection
- Clears peer connection reference

**Purpose:**
- Releases WebRTC resources
- Prevents memory leaks
- Prepares for next session

---

## Task 9: Signalling Integration

### Offer Reception and Answer Flow

**Modified:** `handleOffer(from:payload:)`

**Integration:**
1. Receive offer via signalling (Task 6)
2. Call `handleRemoteOffer(sdp:)` to set remote description
3. Call `createAnswer()` to generate answer
4. Call `sendAnswer(_:)` to send answer via signalling (Task 5)

**Error Handling:**
- Catches and logs all errors
- Does not throw (signalling receive is non-blocking)

**Flow:**
```
Peer A                           Peer B (this device)
──────                           ────────────────────
sendOffer(sdp)
  ↓
[Realtime channel]
                    ──────────→  handleOffer receives
                                   ↓
                                 handleRemoteOffer(sdp)
                                   ↓
                                 createAnswer()
                                   ↓
                                 sendAnswer(sdp)
  ↓
[Realtime channel]
handleAnswer receives  ←──────────
```

### Answer Reception Flow

**Modified:** `handleAnswer(from:payload:)`

**Integration:**
1. Receive answer via signalling (Task 6)
2. Call `handleRemoteAnswer(sdp:)` to set remote description
3. Connection established

**Error Handling:**
- Catches and logs all errors
- Does not throw

### ICE Candidate Flow

**Modified:** `handleICECandidate(from:payload:)`

**Integration:**
1. Receive ICE candidate via signalling (Task 6)
2. Call `handleRemoteICECandidate(...)` to add candidate
3. No response needed

**Behavior:**
- Non-throwing (ICE candidates are best-effort)
- Continues even if some candidates fail

---

## WebRTC Connection Flow

### Complete Handshake Sequence

**Receiver (creates offer):**
1. Initialize peer connection factory
2. Configure audio session
3. Create peer connection
4. Add local audio track
5. Create offer
6. Send offer via signalling
7. Receive answer via signalling
8. Set remote answer
9. Exchange ICE candidates
10. Connection established

**Challenger (creates answer):**
1. Initialize peer connection factory
2. Configure audio session
3. Create peer connection
4. Add local audio track
5. Receive offer via signalling
6. Set remote offer
7. Create answer
8. Send answer via signalling
9. Exchange ICE candidates
10. Connection established

---

## Design Decisions

### Decision 1: Audio Session Configuration

**Chosen:** `.playAndRecord` category with `.voiceChat` mode

**Rationale:**
- Enables bidirectional audio (microphone + speaker)
- `.voiceChat` mode optimizes for voice (echo cancellation, noise suppression)
- Bluetooth support for headsets
- Background audio for screen lock support

**Alternatives considered:**
- `.playback` only - rejected: no microphone access
- `.record` only - rejected: no speaker output
- `.ambient` mode - rejected: not optimized for voice

### Decision 2: STUN-Only for Phase 12

**Chosen:** Google STUN server only, no TURN relay

**Rationale:**
- Follows Phase 12 scope (STUN-first)
- Simplifies initial implementation
- Most users will connect successfully
- TURN can be added later without rearchitecting

**TURN-Ready Design:**
- ICE servers array is extensible
- No code changes needed to add TURN
- Just add TURN server URLs to array

### Decision 3: Unified Plan SDP Semantics

**Chosen:** `.unifiedPlan` instead of `.planB`

**Rationale:**
- Modern WebRTC standard
- Better multi-stream support
- Plan B is deprecated
- Future-proof implementation

### Decision 4: Continual ICE Gathering

**Chosen:** `.gatherContinually` instead of `.gatherOnce`

**Rationale:**
- Handles network changes during session
- Better for mobile devices (WiFi ↔ cellular transitions)
- Improves connection reliability
- Minimal overhead

### Decision 5: Non-Throwing ICE Candidate Handling

**Chosen:** `handleRemoteICECandidate` does not throw

**Rationale:**
- ICE candidates are best-effort
- Some candidates may fail (expected behavior)
- Connection can succeed with subset of candidates
- Throwing would be too strict

### Decision 6: Async/Await for Offer/Answer

**Chosen:** Use `withCheckedThrowingContinuation` for WebRTC callbacks

**Rationale:**
- Bridges callback-based WebRTC API to Swift async/await
- Cleaner error handling
- Matches service's async architecture
- Type-safe continuation

---

## Error Handling

### Audio Session Errors

**Error:** `VoiceSessionError.audioSessionConfigurationFailed`

**Causes:**
- Audio session already in use
- Permission denied
- Hardware failure

**Handling:**
- Throws from `configureAudioSession()`
- Logged with details
- Session cannot proceed without audio

### Peer Connection Errors

**Error:** `VoiceSessionError.peerConnectionFailed`

**Causes:**
- Factory not initialized
- Peer connection creation failed
- SDP negotiation failed
- Remote description invalid

**Handling:**
- Throws from WebRTC methods
- Logged with details
- Signalling integration catches and logs (non-blocking)

---

## Integration Points

### Current Integration

**Signalling Layer (Task 5/6):**
- `handleOffer` calls WebRTC engine
- `handleAnswer` calls WebRTC engine
- `handleICECandidate` calls WebRTC engine

**Not Yet Integrated:**

All WebRTC setup methods are private and not yet called from public API:

```swift
// Not yet called:
- configureAudioSession()
- initializePeerConnectionFactory()
- createPeerConnection()
- addLocalAudioTrack()
- createOffer()
```

### Future Integration (Task 10-15)

**Task 10-12 (UI Integration):**
- Call WebRTC setup when entering lobby
- Display connection state in UI
- Show mute/unmute controls

**Task 13-15 (Lifecycle):**
- Call `configureAudioSession()` on session start
- Call `initializePeerConnectionFactory()` on first use
- Call `createPeerConnection()` when entering lobby
- Call `cleanupWebRTC()` on session end
- Call `deactivateAudioSession()` on teardown

---

## Known Limitations

### What This Task Does NOT Include

- ❌ No peer connection delegate (connection state monitoring)
- ❌ No ICE candidate sending (only receiving)
- ❌ No mute/unmute functionality
- ❌ No connection state updates to session model
- ❌ No automatic session start/teardown
- ❌ No UI integration
- ❌ No TURN relay support

### Why These Are Deferred

- Task 7-9 establishes WebRTC infrastructure only
- Connection state monitoring comes in Task 10-12
- ICE candidate sending will be added when peer connection delegate is implemented
- Lifecycle integration comes in Task 13-15
- UI integration comes in Task 10-12
- TURN support is post-Phase 12

---

## Testing Strategy

### Manual Testing (Not Yet Possible)

Cannot test until:
- Lifecycle integration (Task 13-15)
- UI integration (Task 10-12)
- Two devices or simulator + device setup

### Future Testing

**Unit tests:**
- Audio session configuration
- Peer connection creation
- Offer/answer generation
- ICE candidate handling
- Error handling paths

**Integration tests:**
- Signalling → WebRTC flow
- Offer/answer exchange
- ICE candidate exchange
- Connection establishment

**End-to-end tests:**
- Full voice session (two devices)
- Audio quality verification
- Connection reliability
- Network transition handling
- Bluetooth device support

---

## Success Criteria for Task 7-9

This task is complete when:

- ✅ iOS audio session configuration implemented
- ✅ WebRTC peer connection factory initialized
- ✅ Peer connection creation implemented
- ✅ Local audio track setup implemented
- ✅ Offer/answer creation implemented
- ✅ Remote offer/answer handling implemented
- ✅ ICE candidate handling implemented
- ✅ Signalling integration complete (offer/answer/ICE)
- ✅ WebRTC cleanup implemented
- ✅ Error handling implemented
- ✅ TURN-ready architecture confirmed
- ✅ Implementation is complete and ready for build verification

**Approval checkpoint:** Voice engine implementation reviewed and accepted before Task 10 begins.

---

## Next Task

**Task 10-12:** UI and Flow Integration

This will add:
- Lobby voice status line
- Voice control button (mute/unmute)
- Connection state monitoring
- Integration with remote match flow lifecycle
- Automatic session start/teardown
