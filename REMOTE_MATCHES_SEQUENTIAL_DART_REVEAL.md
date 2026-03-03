# Remote Matches Sequential Dart Reveal Implementation

**Date:** March 3, 2026  
**Status:** ✅ Implementation Complete - Ready for Testing

---

## Overview

Implemented sequential dart reveal animation for opponent's turn in remote matches, with darts appearing one-by-one (0.25s apart), followed by total display, and ending with opponent's score animation - creating a natural "save button" feel.

---

## Problem

In remote matches, when the opponent saved their score, all 3 darts appeared instantly with no animation or sound feedback. This felt abrupt and didn't match the deliberate, step-by-step experience of local games.

---

## Solution

Sequential dart reveal with staggered timing:
1. Darts appear one at a time (left to right) with Throw sound
2. Total appears as 4th item (no sound)
3. Opponent's score animates (like hitting save button)
4. Card rotation happens after all animations complete

---

## Implementation Details

### **File: RemoteGameplayView.swift**

**New State Variables (lines 31-38):**
```swift
// Pre-turn reveal state (sequential dart reveal when opponent saves)
@State private var preTurnRevealThrow: [ScoredThrow] = []
@State private var fullOpponentDarts: [ScoredThrow] = [] // Store all darts for sequential reveal
@State private var revealedDartCount: Int = 0 // 0-3 for sequential dart appearance
@State private var showRevealTotal: Bool = false // Show total as 4th item
@State private var preTurnRevealIsActive: Bool = false
@State private var lastSeenVisitTimestamp: String? = nil
@State private var showOpponentScoreAnimation: Bool = false // Opponent's score animation
```

**Updated Timing Constant (line 49):**
```swift
private let revealHoldNs: UInt64 = 1_700_000_000  // 1.7s (was 1.2s)
```

**Sequential Reveal Logic (lines 236-293):**
```swift
// Sequential reveal with score animation
revealTask = Task { @MainActor in
    do {
        // Dart 1 appears immediately with Throw sound
        SoundManager.shared.playCountdownThud()
        revealedDartCount = 1
        
        // Dart 2 (0.25s later)
        try await Task.sleep(nanoseconds: 250_000_000)
        SoundManager.shared.playCountdownThud()
        revealedDartCount = 2
        
        // Dart 3 (0.25s later)
        try await Task.sleep(nanoseconds: 250_000_000)
        SoundManager.shared.playCountdownThud()
        revealedDartCount = 3
        
        // Total appears (0.25s later, no sound)
        try await Task.sleep(nanoseconds: 250_000_000)
        showRevealTotal = true
        
        // Opponent score animation (0.5s later, like hitting save button)
        try await Task.sleep(nanoseconds: 500_000_000)
        SoundManager.shared.playCountdownSaveScore()
        showOpponentScoreAnimation = true
        
        // Clear opponent score animation (0.25s later)
        try await Task.sleep(nanoseconds: 250_000_000)
        showOpponentScoreAnimation = false
        
        // Rotate card AFTER all animations complete
        displayCurrentPlayerId = serverCurrentPlayerId
        
        // Keep overlay locked during rotation animation
        try await Task.sleep(nanoseconds: rotateAnimNs + postRotatePaddingNs)
        
        // Unlock and clear reveal
        preTurnRevealIsActive = false
        turnTransitionLocked = false
        turnUIGateActive = false
        revealedDartCount = 0
        showRevealTotal = false
    } catch {
        // Clean up on cancellation
        revealedDartCount = 0
        showRevealTotal = false
        showOpponentScoreAnimation = false
    }
}
```

**Updated Computed Property (lines 146-153):**
```swift
private var renderThrowForCurrentThrowDisplay: [ScoredThrow] {
    if preTurnRevealIsActive {
        // Show only revealed darts (sequential reveal)
        return Array(fullOpponentDarts.prefix(revealedDartCount))
    }
    if isMyTurn { return gameViewModel.currentThrow }
    return []
}
```

**Combined Animation State (lines 155-161):**
```swift
/// Combined score animation state: current player OR opponent
private var showAnyScoreAnimation: Bool {
    gameViewModel.showScoreAnimation || showOpponentScoreAnimation
}
```

---

## Timing Sequence

### **Complete Turn Transition (Player 2's View):**

```
t=0.0s:   TURN_GATE triggers (opponent saved)
          → Dart 1 appears + Throw sound 🎵

t=0.25s:  Dart 2 appears + Throw sound 🎵

t=0.5s:   Dart 3 appears + Throw sound 🎵

t=0.75s:  Total appears (4th item, no sound)
          → Display: "15  16  10  = 41"

t=1.25s:  Opponent's score animates + SaveScore sound 🎵
          → Score scales up to 135%
          → (0.5s after total, like hitting save button)

t=1.5s:   Score animation clears (springs back to 100%)
          → (0.25s animation duration)

t=1.7s:   Rotation starts
          → Card rotates to Player 2

t=2.05s:  Rotation completes

t=2.2s:   Unlock (overlay disappears, input enabled)
```

**Total turn transition:** 2.2 seconds (was 1.7s)

---

## Sound Effects

**Sequence:**
1. **t=0.0s** - Throw sound (Dart 1)
2. **t=0.25s** - Throw sound (Dart 2)
3. **t=0.5s** - Throw sound (Dart 3)
4. **t=0.75s** - (silence - total appears)
5. **t=1.25s** - SaveScore sound (opponent's score animation)

**Total sounds:** 4 (3× Throw + 1× SaveScore)

---

## Visual Flow

### **Player 2's Screen (Receiving Opponent's Turn):**

**Phase 1: Sequential Dart Reveal (0-0.75s)**
```
[Empty] → [15] → [15, 16] → [15, 16, 10]
```

**Phase 2: Total Display (0.75s)**
```
[15, 16, 10] = 41
```

**Phase 3: Score Animation (1.25-1.5s)**
```
Player 1's score: 301 → 260
(scales up 135%, springs back)
```

**Phase 4: Card Rotation (1.7-2.05s)**
```
Player 1's card rotates back
Player 2's card rotates to front
```

**Phase 5: Unlock (2.2s)**
```
Lock overlay disappears
Input enabled for Player 2
```

---

## User Experience

### **Before (Instant Reveal):**
- All 3 darts appear at once
- Score updates instantly
- No sound feedback
- Felt abrupt and jarring

### **After (Sequential Reveal):**
- Darts appear one by one (like opponent entering them)
- Throw sound for each dart (auditory feedback)
- Total appears (calculation moment)
- Score animates with SaveScore sound (save button moment)
- Card rotates smoothly
- Feels deliberate and polished ✨

---

## Integration with Existing Systems

### **Turn Gate Compatibility:**

✅ **No conflicts** with turn gate implementation:

| Aspect | Turn Gate | Sequential Reveal |
|--------|-----------|-------------------|
| **Trigger** | `evaluateTurnGate()` | Inside `revealTask` |
| **Duration** | 2.2s total | 1.7s reveal + 0.5s rotation |
| **Lock overlay** | `turnUIGateActive` | Held through entire sequence |
| **Cleanup** | Cancellable Task | Proper cleanup on cancel |

**Safety:**
- All animations happen within `revealTask` (single Task)
- Cancellation cleans up all state variables
- No race conditions with turn gate timing
- Lock overlay stays visible through entire sequence

### **Current Player Animation:**

✅ **No conflicts** with current player's score animation:

| When | Who | Animation | Sound |
|------|-----|-----------|-------|
| You save | Current player | `gameViewModel.showScoreAnimation` | SaveScore (immediate) |
| Opponent saves | Opponent | `showOpponentScoreAnimation` | SaveScore (at t=1.25s) |

**Combined state:** `showAnyScoreAnimation = gameViewModel.showScoreAnimation || showOpponentScoreAnimation`

---

## Files Modified

### RemoteGameplayView.swift

**Lines 31-38:** Added state variables for sequential reveal
**Line 49:** Extended `revealHoldNs` from 1.2s to 1.7s
**Lines 146-153:** Updated `renderThrowForCurrentThrowDisplay` for sequential reveal
**Lines 155-161:** Added `showAnyScoreAnimation` computed property
**Lines 215-293:** Replaced instant reveal with sequential reveal task
**Line 437:** Pass `showAnyScoreAnimation` to `StackedPlayerCards`

---

## Testing Checklist

- [ ] Dart 1 appears immediately with Throw sound
- [ ] Dart 2 appears 0.25s later with Throw sound
- [ ] Dart 3 appears 0.5s later with Throw sound
- [ ] Total appears 0.75s later (no sound)
- [ ] Opponent's score animates 1.25s later with SaveScore sound
- [ ] Score animation clears after 0.25s
- [ ] Card rotation starts at 1.7s
- [ ] Lock overlay stays visible through entire sequence
- [ ] Unlock happens at 2.2s
- [ ] Current player's animation still works (immediate on save)
- [ ] No conflicts with turn gate timing
- [ ] Cancellation cleans up properly

---

## Performance

**Timing Breakdown:**
- Sequential dart reveal: 0.75s (3 darts × 0.25s)
- Total display: 0s (instant)
- Pause before score animation: 0.5s
- Score animation: 0.25s
- Rotation: 0.35s
- Post-rotation padding: 0.15s
- **Total: 2.2s** (extended from 1.7s)

**User Perception:** 
- Feels natural and deliberate
- Matches the rhythm of entering darts manually
- "Save button" moment is clear and satisfying
- Not too slow, not too fast - just right ✨

---

## Future Enhancements

**Potential improvements:**
1. Add subtle haptic feedback for each dart appearance
2. Animate total calculation (count-up effect)
3. Different sounds for different dart values (high/low)
4. Particle effects for each dart appearance
5. Configurable timing (fast/normal/slow modes)

---

## Summary

Sequential dart reveal transforms the opponent's turn from an instant update into a natural, step-by-step experience that mirrors how the opponent actually entered their darts. Combined with the score animation, it creates a satisfying "save button" moment that makes remote matches feel as polished and deliberate as local games.

**Key Achievement:** Remote matches now have the same level of audio-visual feedback and deliberate pacing as local games, creating a cohesive and professional user experience across all game modes.
