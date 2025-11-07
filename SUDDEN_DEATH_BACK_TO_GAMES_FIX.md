# Sudden Death "Back to Games" Navigation Fix

## Problem
The "Back to Games" button in GameEndView worked for 301/501 games but not for Sudden Death. The "Play Again" button worked fine, but "Back to Games" did nothing.

## Root Cause
**Nested Navigation Destinations**: SuddenDeathSetupView had a nested `.navigationDestination` structure that created a broken navigation stack:

```swift
// BROKEN: Nested navigation destinations
.navigationDestination(isPresented: $showGameView) {
    PreGameHypeView(...)
        .navigationDestination(isPresented: .constant(true)) {
            SuddenDeathGameplayView(...)  // ← Nested destination
        }
}
```

This nested structure prevented the `NavigationManager.shared.dismissToGamesList()` from properly popping the entire navigation stack back to the games list.

## How 301/501 Works Correctly
CountdownSetupView → PreGameHypeView → CountdownGameplayView

The navigation flow uses a **single-level navigation destination** in PreGameHypeView:
1. CountdownSetupView navigates to PreGameHypeView
2. PreGameHypeView has `.navigationDestination` that navigates to CountdownGameplayView
3. When "Back to Games" is pressed, `NavigationManager.shared.dismissToGamesList()` sets a flag
4. All views (PreGameHypeView, CountdownSetupView, MainTabView) observe this flag and dismiss themselves
5. The navigation stack cleanly pops back to the games list

## Solution
Updated Sudden Death to follow the same pattern as 301/501:

### 1. Added Sudden Death Support to PreGameHypeView
```swift
// Added suddenDeathLives parameter
let suddenDeathLives: Int?

init(game: Game, players: [Player], matchFormat: Int, 
     halveItDifficulty: HalveItDifficulty? = nil, 
     suddenDeathLives: Int? = nil) {
    // ...
    self.suddenDeathLives = suddenDeathLives
}

// Added Sudden Death case to navigation destination
.navigationDestination(isPresented: $navigateToGameplay) {
    if let difficulty = halveItDifficulty {
        HalveItGameplayView(...)
    } else if let lives = suddenDeathLives {
        SuddenDeathGameplayView(game: game, players: players, startingLives: lives)
    } else {
        CountdownGameplayView(...)
    }
}
```

### 2. Updated SuddenDeathSetupView
Removed the nested `.navigationDestination` and passed `suddenDeathLives` to PreGameHypeView:

```swift
// FIXED: Single-level navigation
.navigationDestination(isPresented: $showGameView) {
    ZStack {
        Color.black.ignoresSafeArea()
        
        if !navigationManager.shouldDismissToGamesList {
            PreGameHypeView(
                game: game,
                players: selectedPlayers,
                matchFormat: 1,
                suddenDeathLives: selectedLives  // ← Pass lives here
            )
        }
    }
}
```

## Navigation Flow (Fixed)
1. **SuddenDeathSetupView** → navigates to PreGameHypeView (with `suddenDeathLives`)
2. **PreGameHypeView** → navigates to SuddenDeathGameplayView (single-level destination)
3. **SuddenDeathGameplayView** → shows GameEndView when game ends
4. **GameEndView "Back to Games"** → calls `NavigationManager.shared.dismissToGamesList()`
5. **All views observe flag** → dismiss themselves in sequence
6. **Result** → Clean navigation back to games list ✅

## Key Principle
**Never nest `.navigationDestination` modifiers.** Each view should have at most one `.navigationDestination`, and navigation should flow linearly through the view hierarchy. This allows the dismiss mechanism to properly unwind the entire stack.

## Files Modified
- `/DanDart/Views/Games/Shared/PreGameHypeView.swift` - Added Sudden Death support
- `/DanDart/Views/Games/SuddenDeath/SuddenDeathSetupView.swift` - Removed nested navigation

## Testing
1. Start a Sudden Death game
2. Complete the game
3. Tap "Back to Games" button
4. Should navigate cleanly back to games list ✅

## Related Issues
This same pattern was previously fixed for:
- Task 35: Navigation from games list to detail
- Countdown games (301/501) navigation
- Halve It navigation

All game modes now follow the same consistent navigation pattern.
