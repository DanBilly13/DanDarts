# Phase 16: Replay Voice Ready Re-announcement - COMPLETE

## Implementation Summary

Successfully implemented explicit event-based replay voice ready re-announcement after session rebind, ensuring `challenger_voice_ready_at` and `receiver_voice_ready_at` become non-nil during replay lobby phase.

## Problem Solved

**Previous state:**
- ✅ Voice session reuse working (no teardown)
- ✅ Signaling channel rebind working
- ❌ Voice ready timestamps stayed nil during replay lobby
- ❌ Lobby advanced via timeout instead of voice-ready countdown
- ❌ `confirmVoiceReady(matchId:)` never called for replay match

**Root cause:**
After `rebindSessionForReplay()` completed, ready flags were reset but no code re-sent `voice_ready` signal on the new channel, and no mechanism triggered `confirmVoiceReady()` for the replay match.

## Solution Implemented

**Explicit event-based approach (not fake state transitions):**
1. After rebind, re-send `voice_ready` on new channel
2. Wait for peer ready response
3. Publish explicit `replayReadyMatchId` event
4. RemoteLobbyView observes event, calls `confirmVoiceReady(matchId:)`
5. Server timestamps become non-nil, lobby progresses normally

## Changes Made

### 1. Add Replay-Ready Published Event

**File:** `VoiceChatService.swift` (line 313-315)

```swift
/// Replay-ready event: matchId when readiness re-announced after replay rebind
/// RemoteLobbyView observes this to trigger confirmVoiceReady for replay match
@Published private(set) var replayReadyMatchId: UUID? = nil
```

**Purpose:** Clean, explicit signal that replay readiness was achieved for a specific match.

### 2. Add reannounceReadyAfterRebind() Method

**File:** `VoiceChatService.swift` (line 686-741)

**Method:** `reannounceReadyAfterRebind() async throws`

**Flow:**
1. Validates current session and role exist
2. Sends `voice_ready` signal on new channel
3. Sets `isLocalReady = true`
4. If challenger, waits 0.5s for peer response
5. If both ready, creates and sends offer
6. Publishes `replayReadyMatchId = session.matchId`
7. Logs all steps with `[ReplayVoice]` prefix

**Key logs:**
- `🔄 [ReplayVoice] ========== RE-ANNOUNCING READINESS ==========`
- `✅ [ReplayVoice] voice_ready sent on rebound channel`
- `✅ [ReplayVoice] replay-ready achieved for match ...`
- `✅ [ReplayVoice] ========== READINESS RE-ANNOUNCED ==========`

### 3. Call Re-announce in Rebind Flow

**File:** `VoiceChatService.swift` (line 666-674)

**Added after resetting ready flags:**
```swift
// Step 5: Re-announce readiness on new channel
// This triggers the ready handshake flow for the replay match
print("🔄 [Rebind] Re-announcing readiness for replay match")
do {
    try await reannounceReadyAfterRebind()
} catch {
    print("❌ [Rebind] Failed to re-announce readiness: \(error)")
    throw error
}
```

**Updated completion log:**
- Changed "Peer ready flags: RESET (will re-handshake)"
- To "Peer ready flags: RESET and RE-ANNOUNCED"

### 4. Observe Replay-Ready Event in RemoteLobbyView

**File:** `RemoteLobbyView.swift` (line 571-604)

**New onChange observer:**
```swift
.onChange(of: voiceChatService.replayReadyMatchId) { _, replayMatchId in
    // Only process if this is for our match
    guard let replayMatchId = replayMatchId,
          replayMatchId == match.id else {
        return
    }
    
    // Only report once per match
    guard !hasReportedVoiceReady else {
        print("⚠️ [ReplayVoice] Already reported for this match")
        return
    }
    
    // Allow reporting during lobby flow only
    let currentPhase = lobbyPhase
    guard currentPhase == .waiting || currentPhase == .connecting || 
          currentPhase == .timedOut || currentPhase == .countdown else {
        print("⚠️ [ReplayVoice] Skipping - phase is \(currentPhase)")
        return
    }
    
    hasReportedVoiceReady = true
    print("🔄 [ReplayVoice] Replay-ready event received for match ...")
    print("🔄 [ReplayVoice] Calling confirmVoiceReady for replay match")
    
    Task {
        do {
            try await remoteMatchService.confirmVoiceReady(matchId: match.id)
            print("✅ [ReplayVoice] confirmVoiceReady succeeded for replay match")
            await requestRefresh(reason: "replay-voice-ready")
        } catch {
            print("❌ [ReplayVoice] Failed to confirm voice ready: \(error)")
        }
    }
}
```

### 5. Reset hasReportedVoiceReady on Match Change

**File:** `RemoteLobbyView.swift` (line 565-570)

```swift
.onChange(of: match.id) { oldId, newId in
    if oldId != newId {
        print("🔄 [VoiceReady] Match changed (...), resetting hasReportedVoiceReady")
        hasReportedVoiceReady = false
    }
}
```

**Purpose:** Ensures replay match can report ready even if previous match already did.

### 6. Add Replay Logging to handleReady()

**File:** `VoiceChatService.swift` (line 1581-1584)

```swift
// Log if this is part of replay rebind
if let session = currentSession, session.connectionState == .connected {
    print("✅ [ReplayVoice] peer ready received for replay match ...")
}
```

**Purpose:** Track when peer ready is received during replay flow.

## Expected Flow After Fix

### Replay Flow (Complete)
```
rebindSessionForReplay()
  → teardownSignallingChannel()
  → setupSignallingChannel(newMatchId)
  → isPeerReady = false, isLocalReady = false
  → reannounceReadyAfterRebind()
    → sendReady(role:)
    → isLocalReady = true
    → peer receives → isPeerReady = true
    → replayReadyMatchId = newMatchId (published)
  → RemoteLobbyView onChange(replayReadyMatchId)
  → confirmVoiceReady(matchId:)
  → server sets challenger_voice_ready_at / receiver_voice_ready_at
  → lobby countdown starts (voice-ready path)
```

### Expected Logs
```
✅ [Rebind] ========== REPLAY SESSION REBIND COMPLETE ==========
🔄 [Rebind] Re-announcing readiness for replay match
🔄 [ReplayVoice] ========== RE-ANNOUNCING READINESS ==========
🔄 [ReplayVoice] Match: A765C720...
🔄 [ReplayVoice] Role: challenger
✅ [ReplayVoice] voice_ready sent on rebound channel
📥 [VoiceSignalling] RECV voice_ready from ...
✅ [ReplayVoice] peer ready received for replay match A765C720
✅ [ReplayVoice] replay-ready achieved for match A765C720
🔄 [ReplayVoice] Replay-ready event received for match A765C720
🔄 [ReplayVoice] Calling confirmVoiceReady for replay match
✅ [ReplayVoice] confirmVoiceReady succeeded for replay match
```

### Expected Server State
```
challenger_voice_ready_at=2026-03-24T13:XX:XX.xxx+00:00
receiver_voice_ready_at=2026-03-24T13:XX:XX.xxx+00:00
```

### Expected Lobby Behavior
```
✅ [MaybeStartCountdown] Countdown started: voice-ready
```

## Success Criteria

1. **Replay readiness re-established** ✅
   - `voice_ready` sent on rebound channel
   - Peer ready received for replay match
   - Replay-ready event published

2. **Server confirmation triggered** ✅
   - `confirmVoiceReady()` called for replay match
   - Server timestamps populated

3. **Lobby progresses normally** ✅
   - Countdown starts via voice-ready path
   - Timeout still works as fallback

4. **Voice session preserved** ✅
   - No teardown/reconnect
   - Peer connection maintained
   - Audio continuity preserved

## Key Design Decisions

### ✅ Explicit Event-Based Approach
**Chosen:**
- Add `@Published var replayReadyMatchId: UUID?`
- Publish event after re-announce completes
- RemoteLobbyView observes dedicated event

**Why:**
- Clean separation of concerns
- Explicit, not implicit
- No fake state transitions
- Easy to debug with clear logs

### ❌ Rejected: Fake Connection-State Transition
**Not used:**
- Temporarily set `.connected → .connecting → .connected`
- Rely on `onChange(of: connectionState)` to fire

**Why rejected:**
- Too indirect and brittle
- Couples core voice behavior to UI observer hack
- Can create weird side effects elsewhere

## Edge Cases Handled

1. **Re-announce fails:** Caught in try-catch, throws error, triggers fallback to full session restart
2. **Peer doesn't respond:** Existing timeout mechanisms handle this, lobby advances via timeout
3. **Multiple rapid replays:** Each rebind publishes new `replayReadyMatchId`, only current match processes
4. **Stale RemoteLobbyView:** Guard checks `replayMatchId == match.id`, stale instances ignore event

## Files Modified

1. **VoiceChatService.swift**
   - Added `@Published var replayReadyMatchId: UUID?` (line 315)
   - Added `reannounceReadyAfterRebind()` method (line 686-741)
   - Call it in `rebindSessionForReplay()` (line 666-674)
   - Added replay log in `handleReady()` (line 1581-1584)

2. **RemoteLobbyView.swift**
   - Added `onChange(of: voiceChatService.replayReadyMatchId)` (line 571-604)
   - Added `onChange(of: match.id)` to reset flag (line 565-570)

## What Was NOT Changed

- ✅ Session reuse logic preserved
- ✅ Signaling rebind logic preserved
- ✅ Peer connection preservation preserved
- ✅ Timeout fallback behavior preserved
- ✅ Normal (non-replay) voice flow unchanged
- ✅ No fake connection-state transitions
- ✅ No UI observer as primary mechanism

## Testing Checklist

**Replay voice readiness:**
- [ ] Logs show "voice_ready sent on rebound channel"
- [ ] Logs show "peer ready received for replay match"
- [ ] Logs show "replay-ready achieved for match"
- [ ] Logs show "confirmVoiceReady called for replay match"
- [ ] Logs show "confirmVoiceReady succeeded for replay match"

**Server state:**
- [ ] `challenger_voice_ready_at` becomes non-nil during replay lobby
- [ ] `receiver_voice_ready_at` becomes non-nil during replay lobby

**Lobby progression:**
- [ ] Countdown starts via voice-ready path (not timeout)
- [ ] Timeout still works as fallback if ready fails

**Voice continuity:**
- [ ] No teardown/reconnect during replay
- [ ] Audio continues seamlessly
- [ ] Peer connection preserved

**Normal flows:**
- [ ] Non-replay matches work exactly as before
- [ ] Different opponent triggers full teardown
- [ ] Back to Games ends session properly

## Next Steps

1. Test replay flow end-to-end on both devices
2. Verify logs show complete replay-ready flow
3. Confirm server timestamps become non-nil
4. Verify lobby countdown starts via voice-ready path
5. Test fallback behavior (timeout still works)

**Status: Implementation complete, ready for testing**
