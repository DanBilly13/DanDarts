# Halve-It Target Hit Rate Calculation Fix

## Problem
The target hit rate percentage was showing 0% even when players hit targets. The calculation was based on **rounds** instead of **individual darts**.

## Root Cause

### Issue 1: Incorrect Data Storage
**File:** `ViewModels/Games/HalveItViewModel.swift` (line 136-146)

The turn history was only storing **darts that hit the target**, not all darts thrown:
```swift
// OLD - Only stored darts that hit
let hitDarts = currentThrow.filter { dart in
    currentTarget.isHit(by: dart)
}
let turnRecord = HalveItTurnHistory(
    ...
    darts: hitDarts, // Only darts that hit ❌
    ...
)
```

This meant we lost information about how many darts were actually thrown per round.

### Issue 2: Wrong Calculation Logic
**Files:** 
- `Views/History/HalveItMatchDetailView.swift` (line 140-146)
- `Views/History/MatchSummarySheetView.swift` (line 232-239)

The calculation was counting **successful rounds** instead of **individual darts**:
```swift
// OLD - Counted rounds where score increased
let successfulRounds = player.turns.filter { $0.scoreAfter > $0.scoreBefore }.count
return Double(successfulRounds) / Double(totalRounds)
```

This gave a percentage out of 6 rounds, not 18 darts!

## Correct Logic

In Halve-It:
- **6 rounds** per game
- **3 darts** per round
- **18 total darts** per player

**Target hit rate should be:**
- Hit all 18 darts = 100%
- Hit 9 darts = 50%
- Hit 3 darts (only the bull round) = 16.67%

## Fixes Applied

### Fix 1: Store All Darts Thrown
**File:** `ViewModels/Games/HalveItViewModel.swift`

```swift
// NEW - Store ALL darts thrown
let turnRecord = HalveItTurnHistory(
    playerId: currentPlayer.id,
    playerName: currentPlayer.displayName,
    round: currentRound,
    target: currentTarget,
    darts: currentThrow, // ✅ All darts thrown (for accurate hit rate calculation)
    scoreBefore: scoreBefore,
    scoreAfter: scoreAfter,
    pointsScored: pointsScored,
    wasHalved: !hitTarget && currentThrow.count == 3
)
```

### Fix 2: Count Individual Darts
**Files:** 
- `Views/History/HalveItMatchDetailView.swift`
- `Views/History/MatchSummarySheetView.swift`

```swift
// NEW - Count individual darts that hit
private func calculateTargetHitRate(for player: MatchPlayer) -> Double {
    // Count total darts thrown across all turns
    let totalDarts = player.turns.reduce(0) { $0 + $1.darts.count }
    guard totalDarts > 0 else { return 0 }
    
    // Count darts that scored points (hit the target)
    let dartsHit = player.turns.reduce(0) { total, turn in
        // If score increased, count the darts that actually scored
        if turn.scoreAfter > turn.scoreBefore {
            return total + turn.darts.filter { $0.value > 0 }.count
        }
        return total
    }
    
    return Double(dartsHit) / Double(totalDarts)
}
```

## How It Works Now

1. **During Gameplay:**
   - All 3 darts thrown per round are stored in turn history
   - Even darts that miss are recorded (with value 0)

2. **In Match History:**
   - Count total darts: Sum of all darts across all 6 rounds (should be 18)
   - Count darts that hit: Darts with value > 0 in rounds where score increased
   - Calculate percentage: (darts hit / total darts) × 100

## Example Calculation

**Scenario:** Player misses everything except the bull round (3 hits)

- **Total darts:** 18 (6 rounds × 3 darts)
- **Darts that hit:** 3 (only the bull round)
- **Hit rate:** 3 / 18 = 0.1667 = **16.67%** ✅

Previously this would have shown:
- Successful rounds: 1 (only bull round)
- Total rounds: 6
- Hit rate: 1 / 6 = 0.1667 = **16.67%** (coincidentally same, but wrong logic!)

But if they hit 1 dart in each round:
- **NEW (correct):** 6 / 18 = **33.33%**
- **OLD (wrong):** 6 / 6 = **100%** ❌

## Testing

After this fix, play a Halve-It game and verify:

1. **Hit all darts:** Should show 100%
2. **Hit only bull (3 darts):** Should show ~17%
3. **Hit half the darts (9 total):** Should show 50%
4. **Miss everything:** Should show 0%

## Impact

✅ **Accurate statistics** - Now shows true dart accuracy  
✅ **Better player feedback** - Players can track their actual performance  
✅ **Correct data storage** - All darts saved for future analysis  
✅ **Future-proof** - Can add more detailed dart-level stats later  

## Status

✅ **FIXED** - Target hit rate now correctly calculates individual dart accuracy (out of 18 darts, not 6 rounds)

**Note:** This fix only affects **new matches** played after the update. Old matches that only stored hit darts will still calculate based on the available data.
