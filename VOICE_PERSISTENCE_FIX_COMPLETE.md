# Voice Session Persistence Fix - Complete ✅

**Date:** 2026-03-15  
**Status:** Fix Applied - Ready for Testing

## Problem Identified

Voice session was being torn down when transitioning from lobby to gameplay, causing the microphone icon to show as crossed out (unavailable) in the game.

### Root Cause

`RemoteLobbyView.onDisappear` unconditionally called `voiceChatService.endSession()`, which destroyed the voice connection when navigating from lobby → gameplay.

**Evidence from logs:**
```
🧩 [Lobby] instance=C90D7F91... onDisappear - match=8EDAD185...
🎤 [VoiceChatService] Ending session: 63937877
🔊 [PeerConnection] ICE connection state: 6
🔊 [PeerConnection] Signaling state changed: 5
🔒 [PeerConnection] ICE closed
🔊 [VoiceSignalling] Tearing down channel
✅ [VoiceSignalling] Channel unsubscribed
```

This violated Phase 12 requirement that **voice should persist across lobby → gameplay → endgame**.

## Solution Implemented

Modified `RemoteLobbyView.swift` (lines 288-298) to only end voice session when actually exiting the remote flow, not when transitioning to gameplay.

### Code Change

**Before:**
```swift
.onDisappear {
    // Task 14: End voice session when leaving lobby
    Task {
        await voiceChatService.endSession()
        print("✅ [Lobby] Voice session ended")
    }
}
```

**After:**
```swift
.onDisappear {
    // Task 14: Voice session lifecycle - persist across lobby → gameplay
    // Only end voice when exiting remote flow entirely, not when transitioning to gameplay
    if !isTransitioningToGameplay {
        print("🎤 [Lobby] Exiting remote flow - ending voice session")
        Task {
            await voiceChatService.endSession()
            print("✅ [Lobby] Voice session ended")
        }
    } else {
        print("🎤 [Lobby] Transitioning to gameplay - voice session persists")
    }
}
```

### How It Works

The fix uses the existing `isTransitioningToGameplay` state variable (line 38) which is set to `true` during the navigation sequence to gameplay (line 420) and reset in a defer block (line 421).

**Flow:**
1. When match status changes to `.inProgress`, `isTransitioningToGameplay = true`
2. Navigation to gameplay begins
3. Lobby's `onDisappear` fires
4. Check: `if !isTransitioningToGameplay` → **false** (we're transitioning)
5. Voice session **persists** (not ended)
6. Gameplay view appears with voice still connected
7. `defer` block resets `isTransitioningToGameplay = false`

**When voice DOES end:**
- User backs out to games list (not transitioning to gameplay)
- Match is cancelled/aborted
- Match expires

## Expected Behavior After Fix

### Voice Session Lifecycle

**Lobby:**
- ✅ Voice session starts
- ✅ Shows "Connecting voice..." or "Voice ready"
- ✅ Microphone button appears in toolbar

**Transition to Gameplay:**
- ✅ Voice session **persists** (not torn down)
- ✅ Connection state maintained
- ✅ Signalling channel remains open
- ✅ Peer connection stays active

**Gameplay:**
- ✅ Voice session continues from lobby
- ✅ Microphone button functional
- ✅ Can mute/unmute
- ✅ Audio flows both ways

**Exit Remote Flow:**
- ✅ Voice session ends cleanly
- ✅ Resources released
- ✅ Channels unsubscribed

## Testing Instructions

### Test 1: Voice Persistence (Primary)

1. Start a remote match
2. Both players enter lobby
3. Watch console for voice bootstrap logs
4. Wait for "Players Ready"
5. Transition to gameplay
6. **Expected:** Console shows `🎤 [Lobby] Transitioning to gameplay - voice session persists`
7. **Expected:** No `endSession()` logs during transition
8. **Expected:** Microphone icon remains in same state (not crossed out)

### Test 2: Voice Connection Success

1. Complete Test 1
2. In gameplay, check voice state
3. **Expected:** Voice shows as "connected" (if WebRTC handshake succeeded)
4. **Expected:** Microphone button is enabled
5. **Expected:** Can toggle mute/unmute
6. **Expected:** Audio passes both ways

### Test 3: Exit Flow Cleanup

1. Start remote match with voice
2. Enter lobby
3. Back out to games list (don't start match)
4. **Expected:** Console shows `🎤 [Lobby] Exiting remote flow - ending voice session`
5. **Expected:** Voice session ends cleanly
6. **Expected:** Resources released

## Console Logs to Look For

### Successful Persistence (Lobby → Gameplay)

```
🧩 [Lobby] instance=... onDisappear - match=...
🎤 [Lobby] Transitioning to gameplay - voice session persists
🚦 [FlowGate] EXIT depth=1
👁️ [RemoteGameplayView] onAppear - matchId: ...
✅ [RemoteGameplayView] Voice session valid for current match
```

**Note:** No `endSession()` logs, no ICE closed, no channel teardown.

### Successful Cleanup (Exit Remote Flow)

```
🧩 [Lobby] instance=... onDisappear - match=...
🎤 [Lobby] Exiting remote flow - ending voice session
🎤 [VoiceChatService] Ending session: ...
🔊 [VoiceSignalling] Tearing down channel
✅ [VoiceSignalling] Channel unsubscribed
🔊 [VoiceEngine] Deactivating audio session
✅ [VoiceEngine] Audio session deactivated
✅ [VoiceChatService] Session cleared
```

## Files Modified

1. **RemoteLobbyView.swift** (lines 288-298)
   - Added conditional check for `isTransitioningToGameplay`
   - Voice session only ends when exiting remote flow
   - Voice session persists when transitioning to gameplay

## Next Steps

### If Voice Still Shows as Unavailable

The persistence fix ensures voice session isn't torn down prematurely. If voice still shows as unavailable/crossed out in gameplay, the issue is likely:

1. **Signalling not completing** - Check for offer/answer exchange in logs
2. **ICE candidates not exchanging** - Check for ICE candidate logs
3. **Peer connection failing** - Check for WebRTC connection state logs
4. **Receiver not creating offer** - Check receiver's logs for offer creation

### Debug Commands

Look for these log patterns:

**Receiver (should create offer):**
```
🔊 [VoiceEngine] Creating offer
✅ [VoiceEngine] Offer created and set as local description
📤 [VoiceSignalling] Sending offer to peer
```

**Challenger (should receive offer and create answer):**
```
📥 [VoiceSignalling] RECV voice_offer from ...
✅ [VoiceSignalling] Valid offer received
🔊 [VoiceEngine] Creating answer
✅ [VoiceEngine] Answer created and set as local description
📤 [VoiceSignalling] Sending answer to peer
```

**Both players (ICE candidates):**
```
📥 [VoiceSignalling] RECV voice_ice_candidate from ...
✅ [VoiceSignalling] Valid ICE candidate received
🔊 [PeerConnection] ICE connection state: 2 (connected)
```

## Success Criteria

### Minimum Success (Persistence Working)
- ✅ No crashes
- ✅ Voice session not torn down during lobby → gameplay transition
- ✅ Console shows "Transitioning to gameplay - voice session persists"
- ✅ No premature `endSession()` calls

### Full Success (Voice Connected)
- ✅ Persistence working (above)
- ✅ Signalling completes (offer/answer exchanged)
- ✅ ICE candidates exchanged
- ✅ Peer connection reaches `.connected` state
- ✅ Audio flows both ways
- ✅ Mute/unmute functional

## Summary

The voice session persistence fix is **complete and applied**. The session will now survive the lobby → gameplay transition, allowing the WebRTC connection to remain active throughout the match.

**Key change:** Voice only ends when exiting the remote flow entirely, not when navigating between lobby and gameplay.

**Ready for testing** to verify voice connection succeeds with persistence in place.
