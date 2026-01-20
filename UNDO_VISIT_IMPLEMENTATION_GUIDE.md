# Undo Last Visit - Implementation Guide

**Status:** ✅ Implemented for 301/501 games  
**Date:** January 20, 2026  
**Purpose:** Allow players to undo their most recent visit (turn) if a mistake was made

---

## Overview

The "Undo Last Visit" feature allows players to revert the last committed turn in a game. This is particularly useful when a score is entered incorrectly. The implementation is designed to be simple (only undo the last visit, not full history) and safe (confirmation alert prevents accidents).

---

## Architecture

### Core Components

1. **Visit Model** (`/Models/Visit.swift`)
   - Stores all data needed to undo a visit
   - Reusable across all game types

2. **ViewModel Integration**
   - Tracks the last visit
   - Provides undo logic
   - Manages state restoration

3. **UI Components**
   - Menu button integration
   - Confirmation alert
   - Clear user feedback

---

## Implementation Steps for New Games

### Step 1: ViewModel Updates

Add the following to your game's ViewModel:

```swift
// MARK: - Undo functionality
@Published private(set) var lastVisit: Visit? = nil

/// Check if undo is available
var canUndo: Bool {
    return lastVisit != nil && winner == nil
}
```

### Step 2: Record Visit Before Saving Score

In your `saveScore()` or equivalent method, **before** applying the score change:

```swift
// Record visit for undo functionality (before applying changes)
lastVisit = Visit(
    playerID: currentPlayer.id,
    playerName: currentPlayer.displayName,
    dartsThrown: currentThrow,           // Array of ScoredThrow
    scoreChange: throwTotal,              // Points scored this visit
    previousScore: currentScore,          // Score before this visit
    newScore: newScore,                   // Score after this visit
    currentPlayerIndex: currentPlayerIndex // Current player index
)

// Then apply the score change...
playerScores[currentPlayer.id] = newScore
```

### Step 3: Implement Undo Method

Add this method to your ViewModel:

```swift
/// Undo the last visit (restore previous state)
func undoLastVisit() {
    guard let visit = lastVisit else { return }
    guard winner == nil else { return } // Can't undo after game is won
    
    // Restore player score to previous value
    playerScores[visit.playerID] = visit.previousScore
    
    // Restore player index to what it was before the visit
    currentPlayerIndex = visit.currentPlayerIndex
    
    // Remove the last turn from history (if your game tracks history)
    if let lastHistoryTurn = turnHistory.last,
       lastHistoryTurn.player.id == visit.playerID {
        turnHistory.removeLast()
        self.lastTurn = turnHistory.last
    }
    
    // Clear the last visit (can only undo once)
    lastVisit = nil
    
    // Clear current throw
    currentThrow.removeAll()
    selectedDartIndex = nil
    
    // Update any game-specific UI (e.g., checkout suggestions)
    updateCheckoutSuggestion() // If applicable
    
    // Play subtle sound feedback
    SoundManager.shared.playButtonTap()
}
```

### Step 4: Update GameplayView

Add state variable for confirmation alert:

```swift
@State private var showUndoConfirmation: Bool = false
```

Update the `GameplayMenuButton` call:

```swift
GameplayMenuButton(
    onInstructions: { showInstructions = true },
    onRestart: { showRestartAlert = true },
    onExit: { showExitAlert = true },
    onUndo: { showUndoConfirmation = true },  // Add this
    canUndo: gameViewModel.canUndo             // Add this
)
```

Add the confirmation alert (place with other alerts):

```swift
.alert("Undo Last Visit", isPresented: $showUndoConfirmation) {
    Button("Cancel", role: .cancel) { }
    Button("Undo", role: .destructive) {
        gameViewModel.undoLastVisit()
    }
} message: {
    if let visit = gameViewModel.lastVisit {
        Text("Undo visit by \(visit.playerName)?\n\nScore will revert from \(visit.newScore) to \(visit.previousScore).")
    } else {
        Text("Undo the last visit?")
    }
}
```

---

## Visit Model Reference

The `Visit` struct is already created and available at `/Models/Visit.swift`:

```swift
struct Visit {
    let playerID: UUID
    let playerName: String
    let dartsThrown: [ScoredThrow]
    let scoreChange: Int        // Points scored this visit
    let previousScore: Int      // Score before this visit
    let newScore: Int          // Score after this visit
    let currentPlayerIndex: Int // Player index before this visit
}
```

---

## GameplayMenuButton Reference

The menu button component has been updated to support undo functionality:

**Parameters:**
- `onUndo: (() -> Void)?` - Optional closure called when undo is tapped
- `canUndo: Bool` - Controls visibility of undo menu item

**Behavior:**
- "Undo Last Visit" menu item only appears when `canUndo == true`
- Icon: `arrow.uturn.backward.circle`
- Positioned between "Instructions" and "Restart Game"

---

## Game-Specific Considerations

### For Score-Based Games (301/501, Cricket, etc.)
- Record visit when score is saved
- Restore previous score on undo
- Update any score-dependent UI (checkouts, suggestions)

### For Lives-Based Games (Knockout, Sudden Death, etc.)
- Record visit when lives change
- Restore previous lives count on undo
- Handle elimination state carefully

### For Target-Based Games (Halve-It, Killer, etc.)
- Record visit when target progress changes
- Restore previous target state on undo
- Update target indicators/progress

---

## Key Features

✅ **Simple** - Only tracks last visit, not full history  
✅ **Safe** - Confirmation alert prevents accidents  
✅ **Clear** - Shows exactly what will be undone  
✅ **Smart** - Disabled when game is won  
✅ **Reusable** - Visit model works for all game types  
✅ **Feedback** - Sound and visual confirmation  

---

## Testing Checklist

When implementing for a new game, test:

- [ ] Play a game and save a score
- [ ] Menu shows "Undo Last Visit" option
- [ ] Tapping undo shows confirmation alert
- [ ] Alert shows correct player name and scores
- [ ] Confirming undo restores previous state
- [ ] Player index is restored correctly
- [ ] Undo option disappears after use (can only undo once)
- [ ] Saving another score makes undo available again
- [ ] Undo is disabled when game is won
- [ ] Sound feedback plays on undo

---

## Files Modified (301/501 Implementation)

### Created:
- `/Models/Visit.swift` - Visit data model

### Modified:
- `/ViewModels/Games/CountdownViewModel.swift` - Added undo logic
- `/Views/Components/GameplayMenuButton.swift` - Added undo menu item
- `/Views/Games/Countdown/CountdownGameplayView.swift` - Added undo UI

---

## Future Enhancements (Not Implemented)

These features were considered but not implemented in the initial version:

- ❌ Undo multiple visits (full history)
- ❌ Redo functionality
- ❌ Persist undo history across app restarts
- ❌ Visual history timeline
- ❌ Undo entire rounds (all players)

---

## Notes

- The `Visit` model uses `ScoredThrow` (not `Dart`) for dart data
- Player name is accessed via `player.displayName` (not `player.name`)
- Only one visit can be undone at a time (no redo)
- Undo is cleared when a new visit is saved
- Undo is disabled when the game is won

---

**Implementation Time Estimate:** ~30-45 minutes per game type  
**Complexity:** Low to Medium (depending on game logic)
