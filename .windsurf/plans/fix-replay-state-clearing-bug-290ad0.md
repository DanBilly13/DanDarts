# Fix Replay State Clearing Bug During Pending->Ready Transition

This plan fixes the local state-clearing bug where EndGameViewRemote incorrectly dismisses replay UI when the match transitions from pending to ready.

## Root Cause Analysis

The issue occurs in `scanForIncomingReplayRequest()`:
1. Receiver accepts replay → match moves `pending` → `ready`
2. `loadMatches()` publishes: `pending=[] ready=[FAF4EE5A]`
3. `scanForIncomingReplayRequest()` re-runs and only checks `pendingChallenges`
4. Since replay is no longer pending, it treats it as "disappeared"
5. Overlay is dismissed and `replayMatch` cleared
6. Navigation fails with "No replay match to join"

## Implementation Plan

### 1. Add Helper Method: `findActiveReplayMatch()`

Create a comprehensive helper that searches all valid replay locations:

```swift
/// Find the active replay match across all valid buckets
private func findActiveReplayMatch(matchId: UUID) -> RemoteMatch? {
    // Check pendingChallenges (initial state)
    if let pending = remoteMatchService.pendingChallenges.first(where: { $0.match.id == matchId }) {
        return pending.match
    }
    
    // Check readyMatches (after acceptance)
    if let ready = remoteMatchService.readyMatches.first(where: { $0.match.id == matchId }) {
        return ready.match
    }
    
    // Check sentChallenges (if initiator)
    if let sent = remoteMatchService.sentChallenges.first(where: { $0.match.id == matchId }) {
        return sent.match
    }
    
    // Check activeMatch (if in lobby/gameplay)
    if let active = remoteMatchService.activeMatch, active.match.id == matchId {
        return active.match
    }
    
    return nil
}
```

### 2. Add Helper Method: `isReplayTerminal()`

Create a method to check if replay should be dismissed:

```swift
/// Check if replay match is in terminal state (should be dismissed)
private func isReplayTerminal(_ match: RemoteMatch) -> Bool {
    switch match.status {
    case .cancelled, .expired, .completed:
        return true
    default:
        return false
    }
}
```

### 3. Fix `scanForIncomingReplayRequest()`

Replace the current logic to use the new helpers:

```swift
private func scanForIncomingReplayRequest() {
    guard let opponent = opponent else { return }
    guard let currentMatchId = matchId else { return }
    
    print("🔍 [EndGameViewRemote] Scanning for replay requests...")
    
    // If we already have an active replayMatchId, preserve its state
    if let activeReplayId = replayMatchId {
        if let activeMatch = findActiveReplayMatch(matchId: activeReplayId) {
            // Update replayMatch with fresh data
            replayMatch = activeMatch
            
            // Check if match became terminal
            if isReplayTerminal(activeMatch) {
                print("🔴 [EndGameViewRemote] Replay became terminal - dismissing")
                dismissReplayOverlay()
                return
            }
            
            print("✅ [EndGameViewRemote] Active replay found and preserved")
            return
        } else {
            // Match not found anywhere - truly disappeared
            print("🔴 [EndGameViewRemote] Active replay match not found - dismissing")
            dismissReplayOverlay()
            return
        }
    }
    
    // Initial scan for new replay requests (original logic)
    for challengeWithPlayers in remoteMatchService.pendingChallenges {
        let match = challengeWithPlayers.match
        
        guard match.challengerId == opponent.id else { continue }
        guard match.isReplay == true else { continue }
        guard match.replaySourceMatchId == currentMatchId else { continue }
        
        print("✅ [EndGameViewRemote] Found replay request from \(opponent.displayName)")
        handleIncomingReplayRequest(matchId: match.id, match: match)
        return
    }
    
    print("❌ [EndGameViewRemote] No matching replay request found")
}
```

### 4. Fix `subscribeToReplayMatch()` 

Update the subscription logic to use the new helper:

```swift
// Replace the existing match finding logic with:
if let activeMatch = findActiveReplayMatch(matchId: matchId) {
    print("✅ [EndGameViewRemote] Found replay match in service arrays - status: \(activeMatch.status?.rawValue ?? "nil")")
    replayMatch = activeMatch
    notFoundCount = 0
    
    if isReplayTerminal(activeMatch) {
        // Terminal - dismiss overlay
        dismissReplayOverlay()
    }
} else {
    // Not found anywhere
    notFoundCount += 1
    if notFoundCount >= 3 {
        print("❌ [EndGameViewRemote] Replay match not found after 3 attempts - dismissing")
        dismissReplayOverlay()
    }
}
```

## Success Criteria

1. ✅ Receiver accepts replay
2. ✅ Match moves `pending` → `ready` 
3. ✅ Overlay is NOT dismissed during transition
4. ✅ `replayMatchId` and `replayMatch` remain intact
5. ✅ `navigateToLobby()` succeeds with valid match data
6. ✅ Receiver enters lobby successfully
7. ✅ Terminal states (cancelled/expired/completed) still dismiss properly

## Files to Modify

**Single File**: `EndGameViewRemote.swift`
- Add `findActiveReplayMatch()` helper method
- Add `isReplayTerminal()` helper method  
- Fix `scanForIncomingReplayRequest()` logic
- Update `subscribeToReplayMatch()` logic

## Testing Scenarios

1. **Normal Flow**: Accept replay → pending→ready → lobby entry
2. **Terminal States**: Cancelled/expired/completed → overlay dismissal
3. **Edge Cases**: Match not found → overlay dismissal
4. **State Preservation**: replayMatch preserved across bucket transitions

## Risk Assessment

**LOW RISK** - Changes are defensive and preserve existing behavior while fixing the specific bug. The new helpers provide better state visibility and prevent premature dismissal.
