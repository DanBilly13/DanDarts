# Voice Session Persistence Fix

## Problem
Voice session is being torn down when transitioning from lobby to gameplay, causing the microphone icon to show as crossed out (unavailable).

## Root Cause
`RemoteLobbyView.onDisappear` unconditionally calls `voiceChatService.endSession()`, which tears down the voice connection when navigating to gameplay.

## Solution
Only end voice session when actually exiting the remote flow, not when transitioning to gameplay.

## Implementation

In `RemoteLobbyView.swift` line 294-301, replace:

```swift
// Task 14: End voice session when leaving lobby
Task {
    await voiceChatService.endSession()
    print("✅ [Lobby] Voice session ended")
}
```

With:

```swift
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
```

## Expected Behavior After Fix
- Voice session starts in lobby
- Voice session persists when transitioning to gameplay
- Voice session only ends when:
  - User exits back to games list
  - Match is cancelled/aborted
  - Match expires
