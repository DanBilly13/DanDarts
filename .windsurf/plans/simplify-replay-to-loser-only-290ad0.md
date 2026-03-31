# Simplify Replay to Loser-Only Initiation

This plan simplifies the replay/rematch feature to eliminate dual-initiation race conditions by only allowing the loser to request rematches.

## Implementation Plan

### 1. Winner/Loser Determination
- **Current state**: `EndGameViewRemote` receives `winner: Player` parameter and `players: [Player]`
- **Logic**: Compare `authService.currentUser?.id` with `winner.id`
- **Computed property**: `private var isWinner: Bool { authService.currentUser?.id == winner.id }`
- **Derived property**: `private var isLoser: Bool { !isWinner }`

### 2. UI Changes - Conditional Button Display

**For Loser (sees active button):**
- Button: "Rematch" (enabled)
- Action: Creates replay as challenger

**For Winner (sees disabled state):**
- Button: "Rematch" (disabled, grayed out)
- Subtitle: "Only losers can request a rematch"
- No action on tap

### 3. Files Requiring Changes

**Primary:**
- `EndGameViewRemote.swift` - Add winner/loser logic, conditional UI

**No changes needed to:**
- `RemoteMatchService.swift` - Reuse existing `createChallenge()` 
- `PlayerChallengeCard.swift` - Reuse existing card states
- Database schema - Existing replay columns sufficient
- Voice/lobby flows - Role swap handled naturally by challenger/receiver fields

### 4. Implementation Details

**Add computed properties:**
```swift
private var isWinner: Bool {
    guard let currentUserId = authService.currentUser?.id else { return false }
    return currentUserId == winner.id
}

private var isLoser: Bool {
    return !isWinner
}
```

**Modify button section:**
```swift
// Action Buttons
VStack(spacing: 16) {
    if isLoser {
        // Loser gets active Rematch button
        AppButton(role: .primary, controlSize: .extraLarge, compact: true) {
            createReplayRequest()
        } label: {
            if isCreatingReplay {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Creating...")
                }
            } else {
                Label("Rematch", systemImage: "arrow.clockwise")
            }
        }
        .disabled(isCreatingReplay)
    } else {
        // Winner gets disabled button with subtitle
        VStack(spacing: 8) {
            AppButton(role: .primaryOutline, controlSize: .extraLarge, compact: true) {
                // No action - disabled
            } label: {
                Label("Rematch", systemImage: "arrow.clockwise")
            }
            .disabled(true)
            
            Text("Only losers can request a rematch")
                .font(.system(.caption, design: .rounded))
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // Back to Games button (unchanged)
    AppButton(role: .primaryOutline, controlSize: .extraLarge, compact: true) {
        onBackToGames()
    } label: {
        Label("Back to Games", systemImage: "house.fill")
    }
}
```

### 5. Role-Swap Risk Analysis

**Identified Risk**: When loser becomes challenger in rematch:
- **Original match**: Winner was challenger, loser was receiver (or vice versa)
- **Rematch**: Loser becomes challenger, winner becomes receiver

**Assessment**: **LOW RISK**
- RemoteLobbyView correctly determines role from `match.challengerId` vs `currentUser.id`
- Voice rebind logic is role-agnostic - uses `replayReadyMatchId` signal
- Navigation flows use authoritative match data, not assumed roles
- Existing replay system already handles role swaps correctly

**Mitigation**: No additional code needed - existing infrastructure handles this case.

### 6. Button/Text Recommendations

**Winner disabled state:**
- Button text: "Rematch"
- Button style: `.primaryOutline` (grayed out)
- Subtitle: "Only losers can request a rematch"
- Font: `.caption`, color: `textSecondary`

**Loser active state:**
- Button text: "Rematch" (changed from "Play Again")
- Button style: `.primary` (blue accent)
- Icon: `arrow.clockwise` (unchanged)

### 7. Testing Scenarios

**Test Case 1**: Loser initiates rematch
1. Complete remote match
2. Loser sees "Rematch" button
3. Winner sees disabled button
4. Loser taps "Rematch"
5. Winner receives incoming challenge
6. Both enter lobby flow

**Test Case 2: Dual tap prevention
1. Both users tap buttons simultaneously
2. Only loser's tap creates challenge
3. Winner's tap does nothing (disabled)

### 8. Migration Notes

- No database migrations needed
- No API changes needed
- Backward compatible with existing replay matches
- No breaking changes to other components

### 9. Code Churn Minimization

**Changes**: ~20 lines in `EndGameViewRemote.swift`
**Reuses**: 100% of existing replay infrastructure
**Eliminates**: Dual-initiation convergence logic and race condition debugging

### 10. Success Criteria

- Only loser can initiate rematches
- Winner sees clear disabled state explanation
- Existing replay flow works unchanged
- No role-swap issues in lobby/voice
- Eliminates dual-initiation race conditions
