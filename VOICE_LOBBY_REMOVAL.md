# Voice Completely Removed from Lobby

**Date:** 2026-03-15  
**Issue:** Crash occurs in lobby before gameplay starts (receiver waiting, challenger hasn't joined yet)

## Root Cause Analysis

### Timeline of Events

1. **Before voice integration:** Remote flow worked correctly
2. **After voice integration:** Crash in lobby before gameplay
3. **Crash context:** Receiver waiting in lobby, challenger hasn't tapped Join Match yet
4. **Conclusion:** Crash is lobby-time, not gameplay handoff

### Leading Suspect: Voice in Lobby

**Why voice is the primary suspect:**
- Issue started immediately after voice was added
- Crash occurs during lobby wait time (when voice would be running)
- Challenger hasn't joined yet (voice may assume both players present)
- Voice session may not be safe when remote participant doesn't exist yet

**Lobby-time systems that could cause crash:**
1. ✅ **Voice session** (most likely - new code, timing-sensitive)
2. Realtime updates (existing code, previously stable)
3. Lobby refresh/onChange/timers (existing code, previously stable)

## Changes Made

### RemoteLobbyView.swift - Voice Completely Disabled

**Removed:**
- `@EnvironmentObject private var voiceChatService: VoiceChatService`
- All voice session startup code from `onAppear`
- All voice session cleanup code from `onDisappear`

**Added:**
- Clear log markers indicating voice is disabled in lobby
- Comments explaining voice will start in RemoteGameplayView

**Before:**
```swift
.onAppear {
    // ... lobby setup ...
    
    Task {
        try await voiceChatService.startSession(...)
    }
}

.onDisappear {
    Task {
        await voiceChatService.endSession()
    }
}
```

**After:**
```swift
.onAppear {
    // ... lobby setup ...
    
    // VOICE DISABLED IN LOBBY - moved to RemoteGameplayView
    print("🎤 [VOICE-DISABLED] Voice startup disabled in lobby")
    print("🎤 [VOICE-DISABLED] Voice will start in RemoteGameplayView when match is in_progress")
}

.onDisappear {
    // VOICE DISABLED IN LOBBY - no session to end
    print("🎤 [VOICE-DISABLED] No voice session to end (voice disabled in lobby)")
}
```

### RemoteGameplayView.swift - Voice Remains Active

**No changes needed** - voice already starts here when gameplay begins:

```swift
.onAppear {
    // Validate voice session matches current match
    if !voiceChatService.isSessionValid(for: matchId) {
        Task {
            try await voiceChatService.startSession(
                for: matchId,
                currentUserId: currentUserId,
                otherPlayerId: otherPlayerId,
                isReceiver: isReceiver
            )
        }
    }
}
```

**Key difference:** RemoteGameplayView only appears when match is `in_progress`, meaning:
- Both players have joined
- Match state is stable
- Remote participant definitely exists
- Gameplay has started

## Testing This Change

### Expected Outcome: Crash Disappears

**If crash is gone:**
- Voice in lobby was the cause ✅
- Keep voice disabled in lobby
- Voice still works during gameplay
- Harden voice for future lobby use (see below)

**If crash persists:**
- Voice was not the sole cause
- Check other lobby-time systems
- Review realtime subscription timing
- Check lobby refresh logic

### Test Procedure

1. **Clean build** to ensure changes applied
2. **Challenger sends challenge**
3. **Receiver taps Accept**
4. **Receiver enters lobby** (should NOT crash now)
5. **Receiver waits in lobby** (should remain stable)
6. **Challenger taps Join Match**
7. **Both enter gameplay** (voice should start here)
8. **Verify voice works** during gameplay

### Log Markers

**Lobby (voice disabled):**
```
🎤 [VOICE-DISABLED] Voice startup disabled in lobby
🎤 [VOICE-DISABLED] Voice will start in RemoteGameplayView when match is in_progress
```

**Gameplay (voice active):**
```
⚠️ [RemoteGameplayView] Voice session mismatch, restarting for match: <matchId>
✅ [RemoteGameplayView] Voice session restarted
```
or
```
✅ [RemoteGameplayView] Voice session valid for current match
```

## Future: Hardening Voice for Lobby Use

If we want to re-enable voice in lobby later, we need to make it safe:

### Requirements for Lobby Voice

1. **Idempotent**
   - Multiple calls to `startSession()` should be safe
   - Check if session already exists before creating
   - Don't crash if session already running

2. **One-shot per match**
   - Only start session once per match ID
   - Track which matches have active sessions
   - Don't restart if already running for this match

3. **Safe when other player hasn't joined**
   - Don't assume remote participant exists
   - Handle missing remote peer gracefully
   - Queue signaling messages until peer appears

4. **Not dependent on remote participant state**
   - Don't crash if remote peer not in Supabase yet
   - Don't crash if remote peer subscription not ready
   - Handle late-joining peer gracefully

### Hardening Implementation

```swift
// Example safe lobby voice startup
func startLobbyVoiceIfSafe(matchId: UUID, currentUserId: UUID, otherPlayerId: UUID) async {
    // 1. Check if session already exists
    guard !voiceChatService.isSessionValid(for: matchId) else {
        print("✅ Voice session already running for match")
        return
    }
    
    // 2. Check if other player has joined
    guard let match = await remoteMatchService.fetchMatch(matchId: matchId),
          match.status == .lobby || match.status == .inProgress else {
        print("⚠️ Other player not ready, deferring voice startup")
        return
    }
    
    // 3. Start session with error handling
    do {
        try await voiceChatService.startSession(
            for: matchId,
            currentUserId: currentUserId,
            otherPlayerId: otherPlayerId,
            isReceiver: isReceiver
        )
        print("✅ Lobby voice started safely")
    } catch {
        print("⚠️ Lobby voice failed (non-blocking): \(error)")
        // Don't crash - match continues without voice
    }
}
```

## Current State

**Voice in Lobby:** ❌ Disabled (completely removed)  
**Voice in Gameplay:** ✅ Active (starts when match is in_progress)  
**Crash Risk:** Eliminated (voice not running during lobby wait)  
**User Experience:** Voice starts when gameplay begins (both players present)

## Files Modified

- **RemoteLobbyView.swift**
  - Commented out `@EnvironmentObject private var voiceChatService`
  - Removed all voice startup code from `onAppear`
  - Removed all voice cleanup code from `onDisappear`
  - Added clear log markers for voice disabled state

- **RemoteGameplayView.swift**
  - No changes (voice already correctly implemented here)

## Rollback Plan

If this change causes issues (unlikely), restore voice in lobby by:

1. Uncomment `@EnvironmentObject private var voiceChatService` in RemoteLobbyView
2. Restore voice startup code in `onAppear`
3. Restore voice cleanup code in `onDisappear`

But only do this if:
- Crash persists with voice removed
- Voice in lobby is proven NOT to be the cause
- Alternative fix is identified

## Success Criteria

✅ Receiver can accept challenge without crash  
✅ Receiver can wait in lobby without crash  
✅ Challenger can join match without crash  
✅ Voice starts when gameplay begins  
✅ Voice works during gameplay  
✅ Voice ends when gameplay ends  

If all criteria met, voice removal from lobby is successful and should remain permanent until voice is hardened for lobby use.
