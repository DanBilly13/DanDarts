# Freeze Receiver Replay Card UI After Accept

This plan adds a receiver-side replay accept freeze flag to prevent visual card state transitions after Accept is tapped, ensuring the user sees either a frozen processing state or direct navigation to lobby.

## Problem Statement

Currently, when the receiver taps Accept on a replay request:
1. Accept is tapped → `acceptChallenge()` called
2. Match transitions `pending` → `ready` on server
3. Realtime update triggers card recompute
4. User sees card visually transition from pending → ready
5. Then navigation to lobby begins

This creates visual confusion as the user sees an intermediate "ready" state they shouldn't interact with.

## Solution Overview

Add a receiver-side UI freeze flag that:
- Sets immediately when Accept is tapped
- Prevents card visual state updates while frozen
- Allows normal server transitions to continue
- Clears when navigation begins or on failure

## Implementation Details

### 1. Add UI Freeze State

```swift
@State private var isReplayUIFrozen = false
```

### 2. Modify `acceptReplayRequest()`

Set freeze flag immediately before calling `acceptChallenge()`:

```swift
private func acceptReplayRequest() {
    print("[ReplayNavTrace] REPLAY_UI_FREEZE set | matchId: \(replayMatchId?.uuidString.prefix(8) ?? "nil")")
    isReplayUIFrozen = true
    
    // ... existing code ...
    
    Task {
        do {
            try await remoteMatchService.acceptChallenge(matchId: matchId)
            // ... rest of existing logic ...
        } catch {
            await MainActor.run {
                print("[ReplayNavTrace] REPLAY_UI_FREEZE cleared | reason: accept failed")
                isReplayUIFrozen = false
                // ... existing error handling ...
            }
        }
    }
}
```

### 3. Freeze Card Presentation Logic

Modify `replayCardState` computed property to respect freeze flag:

```swift
private var replayCardState: CardPresentationState? {
    guard let match = replayMatch else { return nil }
    guard let currentUserId = authService.currentUser?.id else { return nil }
    
    // If UI is frozen, return the last known state (pending for receiver)
    if isReplayUIFrozen {
        let iAmChallenger = match.challengerId == currentUserId
        let frozenState: CardPresentationState = iAmChallenger ? .sent : .pending
        
        print("[ReplayNavTrace] REPLAY_UI_FREEZE ignoring card state update | frozenState: \(frozenState) | actualStatus: \(match.status?.rawValue ?? "nil")")
        return frozenState
    }
    
    // Normal state computation (existing logic)
    let iAmChallenger = match.challengerId == currentUserId
    
    switch match.status {
    case .pending:
        return iAmChallenger ? .sent : .pending
    case .ready:
        return .ready
    case .lobby:
        return .lobby
    // ... rest of existing cases ...
    }
}
```

### 4. Clear Freeze on Navigation

Clear freeze flag when navigation begins:

```swift
private func navigateToLobby() {
    print("[ReplayNavTrace] REPLAY_NAV begin | matchId: \(replayMatch?.id.uuidString.prefix(8) ?? "nil")")
    
    // Clear UI freeze since we're navigating
    if isReplayUIFrozen {
        print("[ReplayNavTrace] REPLAY_UI_FREEZE cleared | reason: navigation starting")
        isReplayUIFrozen = false
    }
    
    // ... existing navigation logic ...
    
    print("[ReplayNavTrace] REPLAY_NAV push remoteLobby | matchId: \(match.id.uuidString.prefix(8))")
}
```

### 5. Clear Freeze on Terminal States

Clear freeze if match becomes terminal while frozen:

```swift
private func handleReplayStatusChange(_ newStatus: RemoteMatchStatus?) {
    // If UI is frozen and match becomes terminal, clear freeze and dismiss
    if isReplayUIFrozen, let status = newStatus {
        switch status {
        case .cancelled, .expired, .completed:
            print("[ReplayNavTrace] REPLAY_UI_FREEZE cleared | reason: match became terminal (\(status.rawValue))")
            isReplayUIFrozen = false
            // ... existing terminal handling ...
        default:
            break
        }
    }
    
    // ... existing status change logic ...
}
```

### 6. Update `scanForIncomingReplayRequest()`

Don't dismiss overlay while UI is frozen:

```swift
private func scanForIncomingReplayRequest() {
    // ... existing logic ...
    
    // If overlay is showing but no matching request exists, dismiss it
    // UNLESS UI is frozen (in which case we're processing accept)
    if showReplayOverlay && !isReplayUIFrozen {
        print("🔴 [EndGameViewRemote] Overlay is showing but replay request disappeared - dismissing")
        dismissReplayOverlay()
    }
}
```

## User Experience Flow

### Successful Accept:
1. User sees pending replay card
2. User taps Accept
3. Card immediately freezes in pending appearance (no visual change)
4. Processing happens in background
5. Navigation to lobby begins
6. Overlay dismisses during navigation

### Failed Accept:
1. User sees pending replay card
2. User taps Accept
3. Card freezes
4. Accept fails
5. Freeze clears
6. Error state shown or overlay dismisses

### Terminal During Accept:
1. User sees pending replay card
2. User taps Accept
3. Card freezes
4. Match becomes cancelled/expired
5. Freeze clears
6. Overlay dismisses with terminal state

## Key Benefits

1. **No Visual Confusion**: User never sees intermediate "ready" state
2. **Clear Feedback**: Freeze indicates processing is happening
3. **Preserves Logic**: Server transitions continue unchanged
4. **Graceful Failure**: Freeze clears appropriately on errors
5. **Minimal Impact**: Only affects visual presentation, not core logic

## Files Modified

**Single File**: `EndGameViewRemote.swift`
- Add `isReplayUIFrozen` state
- Modify `acceptReplayRequest()` to set/clear freeze
- Update `replayCardState` to respect freeze
- Update `navigateToLobby()` to clear freeze
- Update status change handling to clear freeze on terminal states
- Update `scanForIncomingReplayRequest()` to respect freeze

## Risk Assessment

**LOW RISK** - Changes are purely visual and defensive:
- Freeze flag only affects UI presentation
- Server logic and transitions unchanged
- Freeze clears appropriately on all failure paths
- Existing error handling preserved

## Success Criteria

✅ Receiver taps Accept → no visual card state change  
✅ Card appears frozen during processing  
✅ Navigation to lobby works normally  
✅ Failed accepts clear freeze appropriately  
✅ Terminal states during accept clear freeze  
✅ No ready state shown to receiver after accept
