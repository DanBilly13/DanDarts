# Remote Matches UI Gate Timing Implementation

**Date:** March 2, 2026  
**Status:** ✅ Implementation Complete - Ready for Testing

---

## Overview

Implemented a dedicated `turnUIGateActive` boolean that holds the lock overlay visible through the entire turn transition sequence: reveal hold → player card rotation → post-rotation padding. This ensures the input lock overlay doesn't drop prematurely during the rotation animation.

---

## Problem Fixed

**Previous Issue:**
- Lock overlay was driven by `isMyTurn` and `preTurnRevealIsActive`
- `preTurnRevealIsActive` cleared immediately after reveal hold (1.2s)
- Player card rotation animation started, but overlay already disappeared
- Result: Input became enabled DURING the rotation animation (too early)

**Root Cause:**
Input enablement was tied to reveal state, not to the complete UI transition sequence (reveal + rotation + padding).

---

## Solution: Dedicated UI Gate

### New State Variable: `turnUIGateActive`

**Purpose:** Hold lock overlay through entire turn transition sequence

**Lifecycle:**
1. **ON** when TURN_GATE triggers (opponent visit detected)
2. **Stays ON** through reveal hold (1.2s)
3. **Stays ON** through card rotation animation (0.35s)
4. **Stays ON** through post-rotation padding (0.15s)
5. **OFF** after total ~1.7s

### Timing Constants

```swift
private let revealHoldNs: UInt64 = 1_200_000_000         // 1.2s reveal duration
private let rotateAnimNs: UInt64 = 350_000_000           // 0.35s card rotation animation
private let postRotatePaddingNs: UInt64 = 150_000_000    // 0.15s extra padding
```

**Total lock duration:** 1.2s + 0.35s + 0.15s = **1.7 seconds**

---

## Implementation Details

### A. State Variables Added

```swift
// UI gate: holds lock overlay through reveal + rotation + padding
@State private var turnUIGateActive: Bool = false

// Timing constants for turn transition phases
private let revealHoldNs: UInt64 = 1_200_000_000
private let rotateAnimNs: UInt64 = 350_000_000
private let postRotatePaddingNs: UInt64 = 150_000_000
```

### B. Input Enablement Updated

**Before:**
```swift
private var isInputEnabled: Bool {
    isMyTurn && !turnTransitionLocked && !preTurnRevealIsActive && !gameViewModel.isSaving
}
```

**After:**
```swift
private var isInputEnabled: Bool {
    isMyTurn && !turnUIGateActive && !gameViewModel.isSaving
}
```

**Key Change:** Simplified to use only `turnUIGateActive` for lock overlay control.

### C. Turn Gate Trigger Updated

**When TURN_GATE triggers:**
```swift
// Cancel existing task and reset all gates for safety
revealTask?.cancel()
preTurnRevealIsActive = false
turnTransitionLocked = false
turnUIGateActive = false

// Set gates ON
turnTransitionLocked = true
turnUIGateActive = true
print("🎯 [TURN_GATE] LOCK ON")
print("🎯 [TurnGate] UI GATE ON (lock overlay held)")
```

### D. Two-Phase Timing Implementation

**Phase A: Reveal Hold (1.2s)**
```swift
// Hold reveal
try await Task.sleep(nanoseconds: revealHoldNs)

// Rotate card AFTER reveal hold
print("🎯 [TurnGate] ROTATE (after reveal hold)")
displayCurrentPlayerId = serverCurrentPlayerId
```

**Phase B: Rotation Animation + Padding (0.35s + 0.15s)**
```swift
// Keep overlay locked during rotation animation
try await Task.sleep(nanoseconds: rotateAnimNs + postRotatePaddingNs)

// Now unlock + clear reveal
print("🎯 [TurnGate] UNLOCK UI (after rotate)")
preTurnRevealIsActive = false
turnTransitionLocked = false
turnUIGateActive = false
```

### E. Cancellation Safety

**Before starting new transition:**
```swift
revealTask?.cancel()
preTurnRevealIsActive = false
turnTransitionLocked = false
turnUIGateActive = false
```

Ensures all gates are reset deterministically when cancelling existing task.

---

## User Experience Flow

### Complete Turn Transition Sequence

**Player 2's Device (receiving opponent's visit):**

1. **t=0.0s** - Player 1 saves turn
   - DB updated, realtime UPDATE fires
   - `fetchMatch()` called

2. **t=0.05s** - State arrives, TURN_GATE triggers
   - `turnUIGateActive = true` (lock overlay ON)
   - `turnTransitionLocked = true`
   - Player 1's score updates (e.g., 301 → 259)
   - Player 1's card still in front (frozen)
   - Reveal shows opponent's darts
   - **Lock overlay visible**

3. **t=0.0s - 1.2s** - Reveal hold phase
   - Opponent's darts displayed
   - Player 1's card stays in front
   - **Lock overlay still visible**

4. **t=1.2s** - Rotation starts
   - `displayCurrentPlayerId = serverCurrentPlayerId`
   - Player card begins rotating to Player 2
   - **Lock overlay STILL visible** (key improvement!)

5. **t=1.2s - 1.55s** - Rotation animation (0.35s)
   - Card animating
   - **Lock overlay STILL visible**

6. **t=1.55s - 1.7s** - Post-rotation padding (0.15s)
   - Card rotation complete
   - **Lock overlay STILL visible**

7. **t=1.7s** - Unlock
   - `turnUIGateActive = false` (lock overlay OFF)
   - Input enabled
   - Player 2 can now score

---

## Expected Log Sequence

```
🎯 [TURN_GATE] TRIGGER(lvp.ts change): serverCP=5529 lvp.pid=abc123 ts=2026-03-02T...
🎯 [TURN_GATE] LOCK ON
🎯 [TurnGate] UI GATE ON (lock overlay held)
🎯 [PreTurnReveal] SHOW darts=[16, 16, 10] ts=2026-03-02T...
[... 1.2s reveal hold ...]
🎯 [TurnGate] ROTATE (after reveal hold)
[... 0.35s rotation animation ...]
[... 0.15s post-rotation padding ...]
🎯 [TurnGate] UNLOCK UI (after rotate)
🎯 [TurnGate] displayCP=5529... unlocked
```

---

## Timing Breakdown

| Phase | Duration | Lock Overlay | Card State | Input |
|-------|----------|--------------|------------|-------|
| Trigger | 0.0s | ✅ ON | Opponent in front | ❌ Locked |
| Reveal Hold | 1.2s | ✅ ON | Opponent in front | ❌ Locked |
| Rotation | 0.35s | ✅ ON | Animating to me | ❌ Locked |
| Padding | 0.15s | ✅ ON | Me in front | ❌ Locked |
| Unlocked | - | ❌ OFF | Me in front | ✅ Enabled |

**Total lock duration:** 1.7 seconds

---

## Files Modified

### RemoteGameplayView.swift

**Lines 36-47 (added):**
- `turnUIGateActive` state variable
- Timing constants: `revealHoldNs`, `rotateAnimNs`, `postRotatePaddingNs`

**Lines 133-136 (modified):**
- `isInputEnabled` now uses `turnUIGateActive` instead of `preTurnRevealIsActive`

**Lines 207-250 (modified):**
- `evaluateTurnGate()` function updated:
  - Sets `turnUIGateActive = true` on trigger
  - Implements two-phase timing
  - Resets all gates on cancellation
  - Unlocks `turnUIGateActive` after rotation + padding

---

## Key Features

✅ **Lock overlay held through entire sequence** - No premature unlock  
✅ **Two-phase timing** - Reveal hold → Rotation animation  
✅ **Configurable durations** - Easy to tune timing constants  
✅ **Cancellation safety** - All gates reset deterministically  
✅ **Simplified input logic** - Single gate controls lock overlay  
✅ **Comprehensive logging** - Clear phase transitions in logs  

---

## Tuning Guide

### Adjust Reveal Duration
```swift
private let revealHoldNs: UInt64 = 1_200_000_000  // Change to 1_000_000_000 for 1.0s
```

### Adjust Rotation Animation Duration
**Must match actual card rotation animation duration!**
```swift
private let rotateAnimNs: UInt64 = 350_000_000  // Match your animation
```

### Adjust Post-Rotation Padding
```swift
private let postRotatePaddingNs: UInt64 = 150_000_000  // 100-200ms feels right
```

---

## Testing Checklist

- [ ] Lock overlay visible when opponent saves
- [ ] Lock overlay stays visible during reveal (1.2s)
- [ ] Lock overlay stays visible during card rotation (0.35s)
- [ ] Lock overlay stays visible for padding after rotation (0.15s)
- [ ] Lock overlay disappears ~1.7s after trigger
- [ ] Input becomes enabled only after overlay disappears
- [ ] Logs show "UI GATE ON" when triggered
- [ ] Logs show "ROTATE (after reveal hold)" at 1.2s
- [ ] Logs show "UNLOCK UI (after rotate)" at 1.7s
- [ ] Timing feels natural and polished

---

## Why This Works

1. **Dedicated UI gate** - Separate from reveal state and turn state
2. **Holds through animation** - Doesn't unlock until rotation completes
3. **Post-rotation padding** - Extra buffer for polish ("feels right")
4. **Single source of truth** - `isInputEnabled` only checks `turnUIGateActive`
5. **Deterministic lifecycle** - Clear ON/OFF points in code

---

## Performance

**Total turn transition time:** ~1.7 seconds
- Reveal hold: 1.2s
- Rotation animation: 0.35s
- Post-rotation padding: 0.15s

**User perception:** Smooth, polished, deliberate transition with clear visual feedback throughout.
