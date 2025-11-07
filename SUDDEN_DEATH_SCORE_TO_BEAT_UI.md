# Sudden Death: Score to Beat UI Update

**Date:** Nov 7, 2025  
**Change:** Replace "Player to Beat" card with "Score to Beat" component

---

## Overview

Updated Sudden Death UI to show a cleaner, more focused display by replacing the "Player to Beat" card with a simple "Score to Beat" component that shows just the number to beat.

---

## Changes Made

### Before:
```
┌─────────────────────────────────┐
│     Avatar Lineup               │
├─────────────────────────────────┤
│  Player to Beat Card            │
│  [Avatar] Name      Score: 180  │ ← Removed
├─────────────────────────────────┤
│  Current Player Card            │
│  [Avatar] Name      Score: 45   │
└─────────────────────────────────┘
```

### After:
```
┌─────────────────────────────────┐
│     Avatar Lineup               │
├─────────────────────────────────┤
│     Score to beat               │
│       180 💀                     │ ← New Component
├─────────────────────────────────┤
│  Current Player Card            │
│  [Avatar] Name      Score: 45   │
└─────────────────────────────────┘
```

---

## New Component: ScoreToBeatView

### File Created:
`/Views/Games/SuddenDeath/ScoreToBeatView.swift`

### Design Specifications:
- **Caption:** "Score to beat" - `.caption` font, `TextSecondary` color
- **Score:** Large red number - `.largeTitle` font, `AccentPrimary` color
- **Icon:** White skull - 24px × 24px, template rendering mode
- **Layout:** Vertical stack with 4px spacing between caption and score/icon row
- **Icon Position:** 8px spacing between score and skull icon

### Implementation:
```swift
struct ScoreToBeatView: View {
    let score: Int
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Score to beat")
                .font(.caption)
                .foregroundColor(Color("TextSecondary"))
            
            HStack(spacing: 8) {
                Text("\(score)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color("AccentPrimary"))
                
                Image("skull")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.vertical, 8)
    }
}
```

### Usage:
```swift
ScoreToBeatView(score: viewModel.scoreToBeat)
```

---

## Updated SuddenDeathGameplayView

### Changes:

**1. Replaced playerCardsSection with ScoreToBeatView + currentPlayerCard:**
```swift
// OLD:
playerCardsSection  // Showed both player to beat AND current player

// NEW:
ScoreToBeatView(score: viewModel.scoreToBeat)  // Just the score
    .padding(.bottom, 12)

currentPlayerCard  // Only current player
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
```

**2. Simplified computed property:**
```swift
// OLD: playerCardsSection
private var playerCardsSection: some View {
    VStack(spacing: 10) {
        // Player to Beat Card
        SuddenDeathPlayerCard(player: viewModel.playerToBeat, ...)
        
        // Current Player Card
        SuddenDeathPlayerCard(player: viewModel.currentPlayer, ...)
    }
}

// NEW: currentPlayerCard
private var currentPlayerCard: some View {
    SuddenDeathPlayerCard(
        player: viewModel.currentPlayer,
        lives: viewModel.playerLives[viewModel.currentPlayer.id] ?? 0,
        score: viewModel.currentTurnTotal,
        isPlayerToBeat: false,
        borderColor: Color("AccentSecondary")
    )
}
```

---

## Game Behavior

### First Player (Round Start):
- **Score to beat:** `0`
- **Display:** "Score to beat" + `0` + 💀
- **Meaning:** No one has played yet, any score will set the bar

### Subsequent Players:
- **Score to beat:** Highest score from current round (e.g., `180`)
- **Display:** "Score to beat" + `180` + 💀
- **Meaning:** Must score higher than 180 to stay in the game

### No Game Mechanics Changes:
- ✅ Game logic unchanged
- ✅ Elimination rules unchanged
- ✅ Lives system unchanged
- ✅ Only UI presentation changed

---

## Assets

### Skull Icon:
- **Location:** `/Assets.xcassets/icons/skull.imageset/skull.svg`
- **Format:** SVG (vector)
- **Size:** 24px × 24px
- **Color:** White (template rendering mode)
- **Usage:** `Image("skull")`

---

## Benefits

### 1. **Cleaner UI**
- Less visual clutter
- Focus on the number that matters
- More dramatic presentation

### 2. **Better Hierarchy**
- Score to beat is prominent
- Current player card stands out more
- Clearer game state at a glance

### 3. **Thematic**
- Skull icon reinforces "Sudden Death" theme
- Red number emphasizes danger/challenge
- More arcade-style presentation

### 4. **Space Efficient**
- Removed redundant player card
- More room for game controls
- Better vertical spacing

---

## Testing Checklist

- [x] ScoreToBeatView displays correctly
- [x] Shows "0" for first player
- [x] Shows correct high score for subsequent players
- [x] Skull icon renders at 24px
- [x] Typography matches design (caption + largeTitle)
- [x] Colors correct (TextSecondary caption, AccentPrimary score, white skull)
- [x] Current player card displays correctly
- [x] Layout spacing is balanced
- [x] Game mechanics unchanged

---

## Files Modified

1. ✅ **Created:** `/Views/Games/SuddenDeath/ScoreToBeatView.swift`
2. ✅ **Modified:** `/Views/Games/SuddenDeath/SuddenDeathGameplayView.swift`
   - Added ScoreToBeatView component
   - Replaced playerCardsSection with currentPlayerCard
   - Updated layout structure

---

## Preview

The component includes a SwiftUI preview showing both states:
- Score to beat: 0 (first player)
- Score to beat: 180 (subsequent players)

Run preview to verify styling and layout.
