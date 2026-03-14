# Task 10-12 — UI and Flow Integration
**Phase:** 12  
**Sub-phase:** D (UI and Flow Integration)  
**Status:** Implemented  
**Date:** 2026-03-14

---

## Purpose

This task adds the user-facing voice chat UI components and integrates the WebRTC engine with connection state monitoring. It makes the voice infrastructure visible and controllable by users in the lobby and gameplay screens.

---

## Implementation Summary

### Files Modified

**1. `/DanDart/Views/Remote/RemoteLobbyView.swift`**
- Added `VoiceChatService` as environment object
- Added voice status line underneath "Players Ready"
- Added voice control button in top-left toolbar
- Implemented three voice status states with appropriate UI
- Implemented voice control button with state-driven appearance

**2. `/DanDart/Services/VoiceChatService.swift`**
- Added `RTCPeerConnectionDelegate` extension
- Implemented connection state monitoring
- Implemented ICE candidate sending
- Set peer connection delegate to self
- Added remote audio track handling

---

## Task 10: Lobby Voice Status Line

### Implementation

Added a voice status line that appears underneath "Players Ready" in the lobby when both players are ready.

### Three States

**1. Connecting voice...**
- Shown when `connectionState == .connecting`
- Progress spinner + dimmed text
- Opacity: 0.7
- Color: `textSecondary`
- Icon: Animated progress indicator

**2. Voice ready**
- Shown when `connectionState == .connected`
- Checkmark icon + positive text
- Color: `interactiveSecondaryBackground` (green)
- Icon: `checkmark.circle.fill`

**3. Voice not available**
- Shown when `connectionState == .failed` or `.disconnected`
- Warning icon + dimmed text
- Opacity: 0.6
- Color: `textSecondary`
- Icon: `exclamationmark.circle`

**4. Hidden (idle)**
- Shown when `connectionState == .idle`
- EmptyView (no UI shown)

### Design Decisions

**Non-blocking:** Status line never blocks countdown or match start. It's purely informational.

**Honest state:** Shows actual connection state, never lies about availability.

**Low-drama:** Failed/unavailable state is dimmed and subtle, not alarming.

**Small and unobtrusive:** 12pt font, positioned between "Players Ready" and "MATCH STARTING".

### UI Code

```swift
private var voiceStatusLine: some View {
    Group {
        switch voiceChatService.connectionState {
        case .connecting:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(AppColor.textSecondary)
                Text("Connecting voice...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
            }
            .opacity(0.7)
            
        case .connected:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppColor.interactiveSecondaryBackground)
                Text("Voice ready")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColor.interactiveSecondaryBackground)
            }
            
        case .failed, .disconnected:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(AppColor.textSecondary)
                Text("Voice not available")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
            }
            .opacity(0.6)
            
        case .idle:
            EmptyView()
        }
    }
}
```

---

## Task 11: Voice Control Button (Lobby)

### Implementation

Added a voice control button in the **top-left** toolbar position in the lobby.

### Button States

**1. Idle/Connecting**
- Icon: `microphone`
- Color: `textSecondary`
- Opacity: 0.5
- Disabled: Yes
- Appearance: Dimmed, not interactive

**2. Connected (Unmuted)**
- Icon: `microphone`
- Color: `interactiveSecondaryBackground` (green)
- Opacity: 1.0
- Disabled: No
- Appearance: Active, tappable

**3. Connected (Muted)**
- Icon: `microphone.slash`
- Color: `interactivePrimaryBackground` (blue)
- Opacity: 1.0
- Disabled: No
- Appearance: Active, tappable

**4. Failed/Disconnected**
- Icon: `microphone.slash`
- Color: `textSecondary`
- Opacity: 0.5
- Disabled: Yes
- Appearance: Dimmed, not interactive

### Button Behavior

**Action:** Calls `voiceChatService.toggleMute()` when tapped

**Enabled:** Only when `connectionState == .connected`

**Position:** Top-left toolbar (`.topBarLeading`)

**Size:** 20pt icon

### Design Decisions

**Top-left placement:** Consistent position across lobby and gameplay (Task 12 will add to gameplay).

**Help button stays right:** Existing help button remains in top-right, no conflict.

**State-driven appearance:** Icon and color change based on connection and mute state.

**Disabled when unavailable:** Button is disabled (not hidden) when voice is not connected.

### UI Code

```swift
private var voiceControlButton: some View {
    Button {
        Task {
            await voiceChatService.toggleMute()
        }
    } label: {
        Group {
            switch voiceChatService.connectionState {
            case .idle, .connecting:
                Image(systemName: "microphone")
                    .foregroundColor(AppColor.textSecondary)
                    .opacity(0.5)
                
            case .connected:
                if voiceChatService.muteState == .muted {
                    Image(systemName: "microphone.slash")
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                } else {
                    Image(systemName: "microphone")
                        .foregroundColor(AppColor.interactiveSecondaryBackground)
                }
                
            case .failed, .disconnected:
                Image(systemName: "microphone.slash")
                    .foregroundColor(AppColor.textSecondary)
                    .opacity(0.5)
            }
        }
        .font(.system(size: 20))
    }
    .disabled(voiceChatService.connectionState != VoiceSessionState.connected)
}
```

---

## Task 12: Peer Connection Delegate

### Implementation

Added `RTCPeerConnectionDelegate` extension to `VoiceChatService` for connection state monitoring and ICE candidate sending.

### Delegate Methods Implemented

**1. `peerConnection(_:didChange:)` - Signaling State**
- Logs signaling state changes
- No action taken (informational only)

**2. `peerConnection(_:didAdd:)` - Stream Added**
- Called when remote audio stream is received
- Logs stream ID and audio track
- Audio plays automatically through audio session

**3. `peerConnection(_:didRemove:)` - Stream Removed**
- Called when remote stream is removed
- Logs stream ID

**4. `peerConnectionShouldNegotiate(_:)` - Negotiation Needed**
- Called when renegotiation is needed
- Logs event (no action in Phase 12)

**5. `peerConnection(_:didChange:)` - ICE Connection State** ⭐
- **Most important delegate method**
- Updates `connectionState` published property
- Drives UI state changes

**State Mapping:**
```swift
case .connected, .completed:
    connectionState = .connected
    
case .checking:
    connectionState = .connecting
    
case .disconnected:
    connectionState = .disconnected
    
case .failed:
    connectionState = .failed
    
case .closed:
    connectionState = .disconnected
```

**6. `peerConnection(_:didChange:)` - ICE Gathering State**
- Logs gathering state changes
- No action taken (informational only)

**7. `peerConnection(_:didGenerate:)` - ICE Candidate Generated** ⭐
- **Critical for connectivity**
- Called when local ICE candidate is generated
- Sends candidate to remote peer via signalling
- Uses existing `sendICECandidate()` method from Task 5

**Implementation:**
```swift
func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
    print("🔊 [PeerConnection] ICE candidate generated")
    
    Task {
        do {
            try await sendICECandidate(
                candidate: candidate.sdp,
                sdpMid: candidate.sdpMid ?? "",
                sdpMLineIndex: Int(candidate.sdpMLineIndex)
            )
            print("✅ [PeerConnection] ICE candidate sent to peer")
        } catch {
            print("❌ [PeerConnection] Failed to send ICE candidate: \(error)")
        }
    }
}
```

**8. `peerConnection(_:didRemove:)` - ICE Candidates Removed**
- Logs removed candidates
- No action taken

**9. `peerConnection(_:didOpen:)` - Data Channel Opened**
- Logs data channel events
- Not used for audio-only (informational only)

### Connection State Flow

**Complete connection sequence:**

1. Peer connection created with delegate set to `self`
2. ICE gathering begins automatically
3. `didGenerate` called for each local candidate → sent to peer
4. Remote peer sends candidates → received via signalling → added to peer connection
5. ICE connection state changes:
   - `.new` → `.checking` → `.connected` or `.completed`
6. `connectionState` published property updates
7. UI reacts to state changes (status line, button appearance)

### Integration with Signalling

**Outbound (Task 12):**
- `didGenerate` → `sendICECandidate()` → Realtime broadcast

**Inbound (Task 9):**
- Realtime receive → `handleICECandidate()` → `handleRemoteICECandidate()` → `peerConnection.add()`

**Complete loop:**
```
Local ICE candidate generated
  ↓
didGenerate delegate called
  ↓
sendICECandidate() (Task 5)
  ↓
Supabase Realtime broadcast
  ↓
Remote peer receives
  ↓
handleICECandidate() (Task 6)
  ↓
handleRemoteICECandidate() (Task 9)
  ↓
peerConnection.add()
  ↓
ICE connectivity established
```

---

## Design Decisions

### Decision 1: Voice Status Line Position

**Chosen:** Underneath "Players Ready", above "MATCH STARTING"

**Rationale:**
- Logical grouping with player readiness
- Doesn't interfere with main countdown UI
- Visible but not prominent
- Matches Phase 12 specification

**Alternatives considered:**
- Top of screen - rejected: too prominent
- Bottom of screen - rejected: too far from context
- Inside player cards - rejected: clutters player info

### Decision 2: Voice Control Button Position

**Chosen:** Top-left toolbar

**Rationale:**
- Consistent position across lobby and gameplay
- Doesn't conflict with help button (top-right)
- Easy thumb reach on mobile
- Matches Phase 12 specification

**Alternatives considered:**
- Top-right - rejected: conflicts with help/refresh buttons
- Bottom - rejected: too far from other controls
- Floating button - rejected: clutters screen

### Decision 3: Button Disabled vs Hidden

**Chosen:** Disabled (visible but not tappable) when unavailable

**Rationale:**
- User always knows voice feature exists
- Consistent UI layout (no shifting)
- Visual feedback about voice state
- Dimmed appearance indicates unavailability

**Alternatives considered:**
- Hidden when unavailable - rejected: confusing (where did it go?)
- Always enabled - rejected: tapping when unavailable is frustrating

### Decision 4: ICE Candidate Sending in Delegate

**Chosen:** Send immediately in `didGenerate` callback

**Rationale:**
- Fastest connectivity (no batching delay)
- Simple implementation
- Matches WebRTC best practices
- Each candidate sent as generated

**Alternatives considered:**
- Batch candidates - rejected: adds latency
- Wait for gathering complete - rejected: slower connection
- Send only first candidate - rejected: reduces connectivity options

### Decision 5: Connection State Updates on Main Actor

**Chosen:** Wrap state updates in `Task { @MainActor in ... }`

**Rationale:**
- Delegate callbacks happen on WebRTC thread
- Published properties must update on main thread
- SwiftUI requires main thread for UI updates
- Prevents threading issues

**Implementation:**
```swift
Task { @MainActor in
    connectionState = .connected
}
```

---

## Known Limitations

### What This Task Does NOT Include

- ❌ No gameplay voice control button (will be added when gameplay view is created)
- ❌ No automatic session start (Task 13-15)
- ❌ No lifecycle integration (Task 13-15)
- ❌ No mute toggle implementation (placeholder exists)
- ❌ No reconnect logic (Phase 12 scope)
- ❌ No TURN relay (Phase 12 scope)

### Why These Are Deferred

- Task 10-12 focuses on UI and connection monitoring only
- Lifecycle integration requires remote match flow changes (Task 13-15)
- Mute toggle needs audio track manipulation (Task 13-15)
- Gameplay integration needs gameplay view updates (separate task)
- Reconnect and TURN are post-Phase 12 enhancements

---

## Testing Strategy

### Manual Testing (Not Yet Possible)

Cannot fully test until:
- Lifecycle integration (Task 13-15) starts sessions automatically
- Two devices or simulator + device setup
- Remote match flow triggers voice session

### Current Testing Capability

**Can verify:**
- UI components render correctly
- Button states change based on `connectionState`
- Status line shows correct text for each state
- Button is disabled when not connected
- Delegate methods compile and are called

**Cannot verify yet:**
- Actual voice connection
- ICE candidate exchange
- Audio quality
- Mute functionality
- Connection state transitions

### Future Testing

**Unit tests:**
- Voice status line state rendering
- Voice control button state rendering
- Delegate method behavior
- Connection state mapping

**Integration tests:**
- ICE candidate sending flow
- Connection state updates
- UI reactivity to state changes

**End-to-end tests:**
- Full voice session with UI
- Mute/unmute functionality
- Connection state transitions
- Network condition handling

---

## Success Criteria for Task 10-12

This task is complete when:

- ✅ Voice status line added to lobby
- ✅ Three states implemented (Connecting/Ready/Not Available)
- ✅ Voice control button added to lobby (top-left)
- ✅ Button states implemented (idle/connecting/connected/failed)
- ✅ RTCPeerConnectionDelegate extension added
- ✅ Connection state monitoring implemented
- ✅ ICE candidate sending implemented
- ✅ Peer connection delegate set correctly
- ✅ UI updates on connection state changes
- ✅ Button disabled when not connected
- ✅ Implementation is complete and ready for build verification

**Approval checkpoint:** UI and flow integration reviewed and accepted before Task 13 begins.

---

## Next Task

**Task 13-15:** Lifecycle Management (Sub-phase E)

This will add:
- Automatic session start when entering lobby
- Session persistence across navigation (lobby → gameplay → end game → replay)
- Session cleanup when exiting remote match flow
- Mute/unmute implementation
- Integration with remote match lifecycle hooks
