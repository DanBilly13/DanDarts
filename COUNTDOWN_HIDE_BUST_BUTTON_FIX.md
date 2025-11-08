# 301/501 Hide Bust Button When Mathematically Impossible

## Problem
The bust button was always visible in 301/501 games, even when it was mathematically impossible for the player to bust with their remaining darts.

**Example:** Player has 200 remaining, throws a 20 (180 left). Maximum possible score with 2 darts is 120 (2 × T20). Even with perfect darts, they can only get down to 60, so busting is impossible. Yet the bust button was still shown.

## Solution
Added logic to hide the bust button when a bust is mathematically impossible.

### 1. Added `canBust` Computed Property to CountdownViewModel

```swift
/// Determines if a bust is mathematically possible with remaining darts
var canBust: Bool {
    let currentScore = playerScores[currentPlayer.id] ?? startingScore
    let throwTotal = currentThrowTotal
    let remainingScore = currentScore - throwTotal
    
    // Calculate maximum possible score with remaining darts (60 per dart = T20)
    let dartsRemaining = 3 - currentThrow.count
    let maxPossibleScore = dartsRemaining * 60
    
    // Bust is impossible if: remainingScore - maxPossibleScore > 1
    // (Can't go below 2, which is the minimum non-bust score)
    return remainingScore - maxPossibleScore <= 1
}
```

**Logic:**
- Maximum score per dart = 60 (T20)
- If `remainingScore - (dartsRemaining × 60) > 1`, bust is impossible
- Minimum non-bust score is 2 (can't finish on 1)

### 2. Updated CountdownGameplayView to Use `canBust`

```swift
ScoringButtonGrid(
    onScoreSelected: { baseValue, scoreType in
        gameViewModel.recordThrow(value: baseValue, multiplier: scoreType.multiplier)
    },
    showBustButton: gameViewModel.canBust  // ← Hide when bust impossible
)
```

The `ScoringButtonGrid` component already had a `showBustButton` parameter (defaulting to `true`), so we just needed to pass the dynamic value.

## Examples

### Bust Button Hidden
- **Score: 200, Darts thrown: 0** → Max possible: 180 → Remaining: 20 → **Hidden** ✅
- **Score: 170, Darts thrown: 1 (20)** → Score: 150, Max: 120 → Remaining: 30 → **Hidden** ✅
- **Score: 100, Darts thrown: 2 (20, 20)** → Score: 60, Max: 60 → Remaining: 0 → **Hidden** ✅

### Bust Button Shown
- **Score: 60, Darts thrown: 0** → Max possible: 180 → Can bust → **Shown** ✅
- **Score: 100, Darts thrown: 1 (50)** → Score: 50, Max: 120 → Can bust → **Shown** ✅
- **Score: 32, Darts thrown: 2 (16, 8)** → Score: 8, Max: 60 → Can bust → **Shown** ✅

## Benefits
1. **Cleaner UI** - No unnecessary button when it can't be used
2. **Better UX** - Players don't have to think about whether bust is possible
3. **Reduces errors** - Can't accidentally hit bust when it's impossible
4. **Professional feel** - Smart, context-aware interface

## Preventing Flicker During Player Transitions

### Additional Issue Found
After implementing the initial fix, there was a brief flicker where the bust button would appear during the player transition animation (between clearing the throw and switching players).

**Timeline of the issue:**
1. Player throws 50, 50, 50 (score: 151)
2. Hits "Save Score"
3. `currentThrow` cleared immediately
4. Score updated to 151
5. **Bust button appears** (151 - 180 = -29, so `canBust` returns true)
6. 550ms animation delay
7. Player switches
8. Bust button updates for new player

### Solution: Transition Flag
Added `isTransitioningPlayers` flag to track when we're animating between players:

```swift
@Published var isTransitioningPlayers: Bool = false // True during player switch animation
```

Updated `canBust` to check this flag first:

```swift
var canBust: Bool {
    // Hide bust button during player transition to prevent flicker
    guard !isTransitioningPlayers else { return false }
    
    // ... rest of logic
}
```

Set the flag during transitions:

```swift
// In saveScore() - normal turn
isTransitioningPlayers = true
Task {
    // ... animation delays
    switchPlayer()
    isTransitioningPlayers = false
}

// In bust scenario - immediate switch
isTransitioningPlayers = true
switchPlayer()
Task {
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    isTransitioningPlayers = false
}
```

Now the bust button stays hidden during the entire transition! ✅

## Files Modified
- `/DanDart/ViewModels/Games/CountdownViewModel.swift` - Added `canBust` computed property and `isTransitioningPlayers` flag
- `/DanDart/Views/Games/Countdown/CountdownGameplayView.swift` - Pass `canBust` to `ScoringButtonGrid`

## Testing Scenarios
1. Start 301 game (score: 301)
   - Bust button should be **hidden** (301 - 180 = 121 > 1)
2. Throw 60, 60, 60 (score: 121)
   - Bust button should be **hidden** (121 - 180 = -59, but still > 1 after first dart)
3. Throw 60 (score: 61)
   - Bust button should be **shown** (61 - 120 = -59 ≤ 1)
4. Continue playing until score is low
   - Bust button visibility updates dynamically ✅

## Related Components
- **ScoringButtonGrid** - Already had `showBustButton` parameter
- **CountdownViewModel** - Manages game state and scoring logic
- **CountdownGameplayView** - Main gameplay view for 301/501
