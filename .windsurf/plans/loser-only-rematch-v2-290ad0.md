# Loser-Only Rematch V2 Implementation

This plan implements loser-only rematch initiation with minimal changes to only EndGameViewRemote.swift.

## Implementation Scope

**Single File Change**: `EndGameViewRemote.swift` only
**No Changes To**: RemoteMatchService, RemoteLobbyView, voice flow, edge functions

## Safe Logic Implementation

### Computed Properties
```swift
private var currentUserId: UUID? {
    return authService.currentUser?.id
}

private var isWinner: Bool {
    guard let currentUserId = currentUserId else { return false }
    return currentUserId == winner.id
}

private var isLoser: Bool {
    guard let currentUserId = currentUserId else { return false }
    return currentUserId != winner.id
}
```

### UI Changes - Conditional Button Logic

**Replace existing "Play Again" button section with:**

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
    } else if isWinner {
        // Winner gets disabled button with explanation
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
    
    // Back to Games Button (unchanged)
    AppButton(role: .primaryOutline, controlSize: .extraLarge, compact: true) {
        onBackToGames()
    } label: {
        Label("Back to Games", systemImage: "house.fill")
    }
}
```

## Key Implementation Details

### Button Text Consistency
- Use "Rematch" for both active and disabled buttons
- Change from "Play Again" to "Rematch" for consistency

### Safe Logic Shape
- `currentUserId`: Optional UUID from authService
- `isWinner`: Safe check with nil guard
- `isLoser`: Explicit comparison, NOT `!isWinner`

### Role Swap Behavior
- Loser becomes challenger in rematch (via existing createReplayRequest)
- Winner becomes receiver (via existing incoming challenge flow)
- No changes needed to existing pipeline

### Edge Cases
- Missing `currentUserId`: Both winner and loser see disabled state
- No user authentication: No rematch initiation possible

## Testing Checklist

1. **Loser UI**: Loser sees active "Rematch" button
2. **Winner UI**: Winner sees disabled "Rematch" button + explanatory text
3. **Initiation**: Only loser can create replay request
4. **Reception**: Winner receives incoming replay request through existing flow
5. **Acceptance**: Winner accepts and both enter lobby normally
6. **Chain**: Replay chain works for subsequent matches
7. **Race Prevention**: No simultaneous-tap race condition (only one side can act)

## Stop Rules

- ✅ If above testing passes, stop implementation
- ❌ No refactors in this pass
- ❌ No architecture cleanup
- ❌ No symmetric rematch restoration

## Code Changes Summary

**File**: `EndGameViewRemote.swift`
**Lines**: ~25 lines modified
**Risk**: Minimal - only UI conditional logic
**Reuse**: 100% of existing replay infrastructure
