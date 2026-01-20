# Game Tips System Implementation

## Overview
Implemented a flexible, JSON-based tip system that shows game-specific tips to players on their first play of each game type.

## Files Created

### 1. `game_tips.json`
**Location:** `/DanDart/documents/gameText/game_tips.json`

Contains tip definitions for all 7 games:
- **301**: "Reach exactly zero by finishing on a double. Long-press any number to choose single, double, or treble."
- **501**: Same as 301
- **Halve-It**: "Hit the target with at least one dart or your score gets halved! Long-press any number to choose single, double, or treble."
- **Killer**: "Hit your own double first to become a Killer, then attack others! Long-press any number to choose single, double, or treble."
- **Knockout**: "Beat the current high score or lose a life. Long-press any number to choose single, double, or treble."
- **Sudden Death**: "The lowest score each round is eliminated. Score high to survive! Long-press any number to choose single, double, or treble."
- **English Cricket**: "Batters score runs on 15-20 and bull. Bowlers take wickets by hitting the bull. Long-press any number to choose single, double, or treble."

Each tip includes:
- `gameTitle`: Matches the game title exactly
- `icon`: SF Symbol name for the tip icon
- `title`: Short tip title
- `message`: Full tip message (includes game-specific tip + long-press instruction)

### 2. `TipManager.swift`
**Location:** `/DanDart/Services/TipManager.swift`

Singleton service that manages game tips:

**Key Methods:**
- `getTip(for: String) -> GameTip?` - Get tip for a specific game
- `shouldShowTip(for: String) -> Bool` - Check if tip should be shown
- `markTipAsSeen(for: String)` - Mark tip as seen (saves to UserDefaults)
- `hasSeenTip(for: String) -> Bool` - Check if user has seen the tip
- `resetAllTips()` - Reset all tips (for testing)
- `resetTip(for: String)` - Reset specific tip (for testing)

**Storage:**
- Tips stored in UserDefaults with keys: `hasSeenTip_301`, `hasSeenTip_Killer`, etc.
- Loads tips from JSON on initialization

## Files Modified

### 1. `CountdownGameplayView.swift` (301/501)
**Changes:**
- Added `@State private var showGameTip: Bool = false`
- Added `@State private var currentTip: GameTip? = nil`
- Updated `PositionedTip` to show `TipBubble` with dynamic content from `currentTip`
- Added tip loading logic in `onAppear` using `TipManager`
- Removed old hardcoded tip logic and DEBUG override

### 2. `HalveItGameplayView.swift`
**Changes:**
- Added `@State private var showGameTip: Bool = false`
- Added `@State private var currentTip: GameTip? = nil`
- Updated `PositionedTip` to show `TipBubble` (replaced `EmptyView()`)
- Added tip loading logic in `onAppear` using `TipManager`

## How It Works

1. **On Game Start:**
   - View calls `TipManager.shared.shouldShowTip(for: game.title)`
   - Returns `true` if tip exists AND hasn't been seen before

2. **Show Tip:**
   - Loads tip from `TipManager.shared.getTip(for: game.title)`
   - Displays `TipBubble` with tip content after 0.5s delay
   - Positioned at center of screen (50% x, 55% y)

3. **Dismiss Tip:**
   - User taps X button on tip
   - Calls `TipManager.shared.markTipAsSeen(for: game.title)`
   - Saves to UserDefaults: `hasSeenTip_<GameTitle> = true`
   - Tip won't show again for that game

4. **Per-Game Tracking:**
   - Each game tracks separately
   - First time playing 301: Shows 301 tip
   - First time playing Killer: Shows Killer tip
   - Already played 301: No tip shown

## Still TODO

Add tip support to remaining game views:
- [ ] KillerGameplayView.swift
- [ ] KnockoutGameplayView.swift
- [ ] SuddenDeathGameplayView.swift
- [ ] CricketGameplayView.swift (if it exists)

**Pattern to follow:**
```swift
// 1. Add state variables
@State private var showGameTip: Bool = false
@State private var currentTip: GameTip? = nil

// 2. Update PositionedTip
PositionedTip(...) {
    if showGameTip, let tip = currentTip {
        TipBubble(
            systemImageName: tip.icon,
            title: tip.title,
            message: tip.message,
            onDismiss: {
                showGameTip = false
                TipManager.shared.markTipAsSeen(for: game.title)
            }
        )
        .padding(.horizontal, 24)
    }
} background: { ... }

// 3. Add to onAppear
.onAppear {
    // ... existing code ...
    
    if TipManager.shared.shouldShowTip(for: game.title) {
        currentTip = TipManager.shared.getTip(for: game.title)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                showGameTip = true
            }
        }
    }
}
```

## Testing

### Reset All Tips (for testing):
```swift
// In Xcode console or add a debug button
TipManager.shared.resetAllTips()
```

### Reset Specific Tip:
```swift
TipManager.shared.resetTip(for: "301")
```

### Check Tip Status:
```swift
print(TipManager.shared.hasSeenTip(for: "Halve-It"))
```

## Benefits

✅ **Easy to maintain:** All tip text in one JSON file
✅ **Flexible:** Each game can have unique tips
✅ **Consistent:** All games use same TipManager
✅ **User-friendly:** Shows once per game type
✅ **Testable:** Easy to reset tips for testing
✅ **Scalable:** Easy to add new games/tips

## Next Steps

1. Add tip support to remaining 4 game views
2. Test on device with fresh install
3. Verify tips show correctly for each game
4. Verify tips don't show again after dismissal
5. Consider adding more tips in future (e.g., checkout hints for 301/501)
