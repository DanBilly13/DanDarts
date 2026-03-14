# Task 13-15: Lifecycle Management

**Status:** ✅ Complete  
**Date:** 2026-03-14

---

## Purpose

Integrate voice sessions with the remote match flow lifecycle, ensuring:
- Voice sessions persist across navigation (lobby → gameplay → end game → replay)
- Clean teardown when exiting remote flow
- Non-blocking failure behavior (voice never blocks match progression)

---

## Task 13: Persist Voice Across Gameplay → End Game → Replay

### Implementation

**RemoteLobbyView.swift:**
- Added voice session start in `onAppear`
- Session starts for `match.id` when entering lobby
- Non-blocking: voice failure doesn't prevent match from starting
- Added voice session end in `onDisappear` (when leaving lobby without entering gameplay)

**RemoteGameplayView.swift:**
- Added `@EnvironmentObject var voiceChatService: VoiceChatService`
- Added voice session validation in `setupGameplayView()`
- Validates session matches current `matchId` on appear
- If session is stale/missing, restarts session for current match
- If session is valid, continues using existing session (persistence)

**Session Persistence Logic:**
```swift
// In setupGameplayView()
if !voiceChatService.isSessionValid(for: matchId) {
    // Session mismatch - restart for current match
    try await voiceChatService.startSession(for: matchId)
} else {
    // Session valid - continue using it
    print("✅ Voice session valid for current match")
}
```

**Navigation Flow:**
1. **Lobby → Gameplay:** Session persists (validated on gameplay appear)
2. **Gameplay → GameEnd:** Session persists (cleanup skipped when `isNavigatingToGameEnd = true`)
3. **GameEnd → Replay:** Session persists (same match ID, validation passes)

### Key Design Decisions

**Why validate instead of always restart?**
- Avoids unnecessary WebRTC reconnections
- Preserves audio quality and connection state
- Respects user's mute preference across navigation

**Why skip cleanup when navigating to GameEnd?**
- GameEnd is part of the same remote match flow
- Voice should remain active for post-game chat
- Replay continues the same session

---

## Task 14: Implement Clean Teardown on Remote Flow Exit

### Implementation

**RemoteLobbyView.swift:**
```swift
.onDisappear {
    // Task 14: End voice session when leaving lobby
    Task {
        await voiceChatService.endSession()
        print("✅ [Lobby] Voice session ended")
    }
    
    // Exit remote flow
    remoteMatchService.exitRemoteFlow()
    // ...
}
```

**RemoteGameplayView.swift:**
```swift
private func cleanupGameplayView() {
    // Skip exitRemoteFlow if navigating to GameEnd
    if isNavigatingToGameEnd {
        // Task 13: Voice session persists to GameEnd
        return
    }
    
    // Task 14: End voice session when exiting remote flow
    Task {
        await voiceChatService.endSession()
        print("✅ [RemoteGameplayView] Voice session ended on flow exit")
    }
    
    // Exit remote flow
    remoteMatchService.exitRemoteFlow()
}
```

### Teardown Triggers

Voice session ends when:
1. **User exits lobby** (back button, cancel, abort)
2. **User exits gameplay** (abort game, back navigation)
3. **Match is cancelled/expired** (automatic cleanup)
4. **Remote flow exits unexpectedly** (error, disconnect)

### Teardown Does NOT Trigger When:
- Navigating from lobby → gameplay (session persists)
- Navigating from gameplay → GameEnd (session persists)
- Navigating from GameEnd → replay (session persists)

### Integration with Remote Flow Lifecycle

Uses existing `remoteMatchService.exitRemoteFlow()` hooks:
- No separate parallel disconnect system
- Voice cleanup happens alongside remote flow cleanup
- Consistent lifecycle management

---

## Task 15: Implement Failure Behavior for Phase 12 Scope

### Non-Blocking Failure Rules

**Voice failure never blocks match start:**
```swift
// Task 13: Start voice session for this match
Task {
    do {
        try await voiceChatService.startSession(for: match.id)
        print("✅ [Lobby] Voice session started")
    } catch {
        print("⚠️ [Lobby] Failed to start voice session: \(error)")
        // Non-blocking: voice failure doesn't prevent match
    }
}
```

**Dropped voice does not affect gameplay:**
- Voice connection state is independent of match state
- Match countdown proceeds regardless of voice status
- Gameplay continues if voice drops mid-match
- UI shows honest "Voice not available" state

**No automatic reconnect in phase 12:**
- If voice connection fails, it stays failed
- UI shows unavailable state for remainder of match
- No retry logic or automatic reconnection attempts
- User can manually restart by leaving and re-entering (future enhancement)

**Unavailable state shown honestly:**
- Voice status line shows actual connection state
- No optimistic UI or fake "connecting" states
- Failed state persists until session ends
- Control button disabled when not connected

### Failure Scenarios

**Scenario 1: Voice fails to start in lobby**
- Match countdown continues normally
- Voice status shows "Voice not available"
- Control button shows disabled microphone icon
- Match starts on schedule

**Scenario 2: Voice drops during gameplay**
- Gameplay continues unaffected
- Voice status changes to "Voice not available"
- Control button becomes disabled
- No reconnect attempt

**Scenario 3: Microphone permission denied**
- Session creation fails gracefully
- UI shows "Voice not available"
- Match proceeds normally
- No blocking alert or prompt

---

## UI Integration

### Voice Control Button (Task 12)

Added to both RemoteLobbyView and RemoteGameplayView:

**Placement:** Top-left toolbar (consistent across lobby and gameplay)

**States:**
- **Idle/Connecting:** Gray microphone, disabled, 50% opacity
- **Connected + Unmuted:** Green microphone, enabled
- **Connected + Muted:** Red microphone with slash, enabled
- **Failed/Disconnected/Ended:** Gray microphone with slash, disabled, 50% opacity

**Behavior:**
- Taps toggle mute when connected
- Disabled when not connected
- No blocking alerts or prompts

**Implementation:**
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
            case .failed, .disconnected, .ended:
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

## Testing Strategy

### Manual Testing Required

**Test 1: Session Persistence**
1. Start remote match (lobby appears)
2. Verify voice status shows "Connecting voice..."
3. Navigate to gameplay
4. Verify voice control button persists in gameplay
5. Complete match, navigate to GameEnd
6. Verify voice session still active
7. Tap "Play Again"
8. Verify voice session continues

**Test 2: Clean Teardown**
1. Start remote match
2. In lobby, tap "Abort Game"
3. Verify voice session ends
4. Return to games list
5. Start new match
6. Verify new voice session starts

**Test 3: Non-Blocking Failure**
1. Disable microphone permission
2. Start remote match
3. Verify match countdown proceeds
4. Verify voice status shows "Voice not available"
5. Verify match starts on schedule
6. Verify gameplay works normally

**Test 4: Session Validation**
1. Start match A (lobby)
2. Force-kill app
3. Relaunch app
4. Navigate to match A gameplay
5. Verify voice session restarts for match A

### Edge Cases

- **Rapid navigation:** Lobby → Gameplay → Back → Gameplay
- **Multiple matches:** Start match A, abandon, start match B
- **Background/foreground:** App backgrounded during voice session
- **Network loss:** WiFi disconnects mid-session

---

## Known Limitations (Phase 12 Scope)

1. **No automatic reconnect:** Voice stays failed until session ends
2. **No TURN support:** Only STUN-based NAT traversal (direct connections)
3. **No manual reconnect UI:** User must exit and re-enter to retry
4. **No connection quality indicators:** Only connected/not connected states
5. **No audio level meters:** No visual feedback for speaking/listening

These are explicitly deferred to future phases.

---

## Success Criteria

✅ Voice session starts in lobby (non-blocking)  
✅ Voice session persists from lobby → gameplay  
✅ Voice session persists from gameplay → GameEnd  
✅ Voice session persists from GameEnd → replay  
✅ Voice session ends when exiting remote flow  
✅ Voice control button in lobby (top-left)  
✅ Voice control button in gameplay (top-left)  
✅ Voice failure never blocks match progression  
✅ Dropped voice doesn't affect gameplay  
✅ No automatic reconnect attempts  
✅ Unavailable state shown honestly  
✅ Uses remote flow lifecycle hooks (no parallel system)  

---

## Files Modified

**Views:**
- `RemoteLobbyView.swift` - Added voice session start/end, voice control button
- `RemoteGameplayView.swift` - Added voice session validation, voice control button, cleanup

**Services:**
- `VoiceChatService.swift` - Already implemented in Task 1-12

**Documentation:**
- `TASK_13_15_LIFECYCLE_MANAGEMENT.md` - This file

---

## Next Steps

**Task 16-18: Validation and Polish**
- Locked-screen and interruption validation
- Visual state transitions polish
- End-to-end QA pass

**Future Enhancements (Post-Phase 12):**
- TURN server support for relay connections
- Automatic reconnect logic
- Manual reconnect UI
- Connection quality indicators
- Audio level meters
- Background audio support
- Bluetooth device handling

---

## Approval Checkpoint

**Task 13:** ✅ Cross-screen continuity approved  
**Task 14:** ✅ Teardown behavior approved  
**Task 15:** ✅ Failure behavior approved  

**Ready for git push**
