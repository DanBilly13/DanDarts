# Sudden Death Tap-to-Edit Fix

## Problem
In Sudden Death, when a user enters a wrong score and taps on a dart in the current throw display (which shows a red border), tapping another score button doesn't replace the selected dart - it just appends a new dart instead.

This tap-to-edit functionality works correctly in Halve It but was broken in Sudden Death.

## Root Cause
The `recordThrow` method in **SuddenDeathViewModel** was missing the tap-to-edit logic that checks if a dart is selected and replaces it.

### Before (Broken)
```swift
func recordThrow(_ scoredThrow: ScoredThrow) {
    guard currentThrow.count < 3 else { return }
    
    currentThrow.append(scoredThrow)  // ← Always appends, never replaces
    
    // Play sound...
    // Update score...
}
```

This only appended new darts and ignored the `selectedDartIndex` state.

### How Halve It Works (Correct)
```swift
func recordThrow(baseValue: Int, scoreType: ScoreType) {
    // If a dart is selected, replace it instead of appending
    if let selectedIndex = selectedDartIndex, selectedIndex < currentThrow.count {
        let dart = ScoredThrow(baseValue: baseValue, scoreType: scoreType)
        currentThrow[selectedIndex] = dart
        selectedDartIndex = nil  // Clear selection after replacement
    } else {
        // Normal append behavior
        guard currentThrow.count < 3 else { return }
        let dart = ScoredThrow(baseValue: baseValue, scoreType: scoreType)
        currentThrow.append(dart)
    }
}
```

## Solution
Updated `recordThrow` in **SuddenDeathViewModel** to match the Halve It pattern:

```swift
func recordThrow(_ scoredThrow: ScoredThrow) {
    // If a dart is selected, replace it instead of appending
    if let selectedIndex = selectedDartIndex, selectedIndex < currentThrow.count {
        currentThrow[selectedIndex] = scoredThrow
        selectedDartIndex = nil  // Clear selection after replacement
    } else {
        // Normal append behavior
        guard currentThrow.count < 3 else { return }
        currentThrow.append(scoredThrow)
    }
    
    // Play appropriate sound
    if scoredThrow.totalValue == 0 {
        soundManager.playMissSound()
    } else {
        soundManager.playScoreSound()
    }
    
    // Update current turn score
    currentTurnScores[currentPlayer.id] = currentTurnTotal
}
```

## Tap-to-Edit Flow (Now Fixed)
1. User enters darts: 20, 5, 10
2. User realizes 5 was wrong, should be 15
3. User taps on the "5" dart in CurrentThrowDisplay
4. Dart shows red border, `selectedDartIndex = 1`
5. User taps "15" on scoring grid
6. `recordThrow` checks `selectedDartIndex` is set
7. Replaces `currentThrow[1]` with new dart (15)
8. Clears `selectedDartIndex = nil`
9. Red border disappears
10. Current throw now shows: 20, 15, 10 ✅

## Related Components
- **CurrentThrowDisplay** - Shows darts with tap-to-select functionality (shared component)
- **SuddenDeathViewModel.selectDart(at:)** - Sets `selectedDartIndex` when dart tapped
- **SuddenDeathViewModel.recordThrow()** - Now checks for selected dart and replaces it

## Files Modified
- `/DanDart/ViewModels/Games/SuddenDeathViewModel.swift` - Added tap-to-edit logic to `recordThrow`

## Testing
1. Start a Sudden Death game
2. Enter 3 darts (e.g., 20, 5, 10)
3. Tap on the middle dart (5) - should show red border
4. Tap a different score (e.g., 15)
5. Middle dart should be replaced with 15 ✅
6. Red border should disappear ✅
7. Current throw should show: 20, 15, 10 ✅

## Consistency
All game modes now have consistent tap-to-edit behavior:
- ✅ Countdown (301/501) - Uses CurrentThrowDisplay with tap-to-edit
- ✅ Halve It - Uses CurrentThrowDisplay with tap-to-edit
- ✅ Sudden Death - Now uses CurrentThrowDisplay with tap-to-edit (FIXED)
