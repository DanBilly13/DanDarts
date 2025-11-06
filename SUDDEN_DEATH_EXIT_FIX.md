# Sudden Death Exit Navigation Fix

**Date:** Nov 6, 2025  
**Issue:** Exit game functionality not working properly in Sudden Death

---

## Problem Identified

When exiting Sudden Death game via the menu button, the navigation didn't work as expected. The app would dismiss the current view but not properly navigate back to the games list, leaving the user in an inconsistent navigation state.

### Root Cause

The issue stems from the **PreGameHypeView** navigation stack. When a game starts:
1. User navigates from Games List → Game Setup → PreGameHypeView → GameplayView
2. This creates a deep navigation stack
3. Simply calling `dismiss()` only pops one level, leaving the user on PreGameHypeView
4. Need to use `NavigationManager.shared.dismissToGamesList()` to properly clear the entire stack

---

## Comparison: Before vs After

### ❌ Before (Broken):

**SuddenDeathGameplayView:**
```swift
// Exit alert
.alert("Exit Game?", isPresented: $showExitConfirmation) {
    Button("Exit", role: .destructive) {
        dismiss()  // ❌ Only dismisses one level
    }
}

// GameEndView callbacks
onChangePlayers: {
    dismiss()  // ❌ Doesn't clear navigation stack
},
onBackToGames: {
    dismiss()  // ❌ Doesn't clear navigation stack
}
```

### ✅ After (Fixed):

**SuddenDeathGameplayView:**
```swift
// Exit alert
.alert("Exit Game", isPresented: $showExitConfirmation) {
    Button("Leave Game", role: .destructive) {
        NavigationManager.shared.dismissToGamesList()  // ✅ Clears stack
        dismiss()                                       // ✅ Then dismisses
    }
}

// GameEndView callbacks
onChangePlayers: {
    NavigationManager.shared.dismissToGamesList()  // ✅ Clears stack
    dismiss()                                       // ✅ Then dismisses
},
onBackToGames: {
    NavigationManager.shared.dismissToGamesList()  // ✅ Clears stack
    dismiss()                                       // ✅ Then dismisses
}
```

---

## Changes Made

### File Modified:
`/Views/Games/SuddenDeath/SuddenDeathGameplayView.swift`

### 1. Exit Alert (Lines 125-133)
**Changed:**
- Alert title: "Exit Game?" → "Exit Game" (consistency)
- Button text: "Exit" → "Leave Game" (consistency)
- Added: `NavigationManager.shared.dismissToGamesList()` before `dismiss()`
- Message text: Updated for consistency with other games

### 2. GameEndView Callbacks (Lines 146-153)
**Changed:**
- `onChangePlayers`: Added `NavigationManager.shared.dismissToGamesList()`
- `onBackToGames`: Added `NavigationManager.shared.dismissToGamesList()`

---

## Pattern to Follow

All gameplay views must use this pattern for navigation dismissal:

```swift
// ALWAYS use this pattern when exiting gameplay
NavigationManager.shared.dismissToGamesList()
dismiss()
```

**Why both calls?**
1. `NavigationManager.shared.dismissToGamesList()` - Sets flag to clear navigation stack
2. `dismiss()` - Actually performs the dismissal

**Order matters!** Must call `dismissToGamesList()` FIRST, then `dismiss()`.

---

## Verified Working Games

✅ **CountdownGameplayView** (301/501) - Uses correct pattern  
✅ **HalveItGameplayView** - Uses correct pattern  
✅ **SuddenDeathGameplayView** - Now fixed to use correct pattern  

---

## Testing Checklist

- [x] Exit via menu button returns to Games List
- [x] "Change Players" from GameEndView returns to Games List
- [x] "Back to Games" from GameEndView returns to Games List
- [x] No navigation stack issues
- [x] Alert text matches other games
- [x] Button text matches other games

---

## Future Games

All future gameplay views MUST implement exit navigation using this pattern:

```swift
.alert("Exit Game", isPresented: $showExitAlert) {
    Button("Cancel", role: .cancel) { }
    Button("Leave Game", role: .destructive) {
        NavigationManager.shared.dismissToGamesList()
        dismiss()
    }
} message: {
    Text("Are you sure you want to leave the game? Your progress will be lost.")
}
```

And in GameEndView callbacks:
```swift
onChangePlayers: {
    NavigationManager.shared.dismissToGamesList()
    dismiss()
},
onBackToGames: {
    NavigationManager.shared.dismissToGamesList()
    dismiss()
}
```

---

## Related Documentation

- See `NavigationManager.swift` for implementation details
- PreGameHypeView creates the deep navigation stack that requires this pattern
- This pattern is necessary for ALL games that use PreGameHypeView
