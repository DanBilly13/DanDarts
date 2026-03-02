# Remote Matches Gated Overlay Fix

**Date:** March 2, 2026  
**Status:** ✅ Implementation Complete - Ready for Testing

---

## Overview

Implemented gated overlay state that forces the bottom lock overlay to stay visible through the entire turn transition sequence (score update + reveal + rotation + padding) by overriding the adapter's overlay state when `turnUIGateActive` is true.

---

## Problem Fixed

**Previous Issue:**
- Bottom lock overlay was driven solely by `adapter.overlayState(isSaving:isRevealing:)`
- When score reveal happened, `overlayState` could change and overlay disappeared
- This happened even though `turnUIGateActive` still wanted the UI locked
- Result: Lock overlay disappeared during score update or rotation animation (too early)

**Root Cause:**
Overlay state was independent of turn gate state, causing premature unlock during the transition sequence.

---

## Solution: Gated Overlay State

### Force `.inactiveLockout` When Turn Gate Active

**Implementation in `contentWithNavigation(using:adapter:)`:**

```swift
let baseOverlayState = adapter.overlayState(
    isSaving: gameViewModel.isSaving,
    isRevealing: gameViewModel.isRevealingScore
)

// 🎯 UI GATE: keep the lock overlay up through reveal + rotate + padding
let overlayState: RemoteGameStateAdapter.OverlayState = {
    if turnUIGateActive {
        return .inactiveLockout
    }
    return baseOverlayState
}()
```

**Key Change:** When `turnUIGateActive == true`, overlay state is forced to `.inactiveLockout` regardless of base state.

---

## Complete Turn Transition Flow

### Timeline with Lock Overlay Visibility

| Time | Event | turnUIGateActive | overlayState | Lock Overlay |
|------|-------|------------------|--------------|--------------|
| 0.0s | TURN_GATE triggers | ✅ true | .inactiveLockout | ✅ Visible |
| 0.0s | Opponent score updates | ✅ true | .inactiveLockout | ✅ Visible |
| 0.0-1.2s | Reveal hold | ✅ true | .inactiveLockout | ✅ Visible |
| 1.2s | Rotation starts | ✅ true | .inactiveLockout | ✅ Visible |
| 1.2-1.55s | Rotation anim | ✅ true | .inactiveLockout | ✅ Visible |
| 1.55-1.7s | Post-padding | ✅ true | .inactiveLockout | ✅ Visible |
| 1.7s | Unlock | ❌ false | baseOverlayState | ❌ Hidden |

**Total lock overlay duration:** 1.7 seconds (through entire sequence)

---

## Implementation Details

### File: RemoteGameplayView.swift

**Lines 638-652 (modified):**

**Before:**
```swift
private func contentWithNavigation(using m: RemoteMatch, adapter: RemoteGameStateAdapter) -> some View {
    let overlayState = adapter.overlayState(isSaving: gameViewModel.isSaving, isRevealing: gameViewModel.isRevealingScore)
    
    return gameplayContent(overlayState, using: m, adapter: adapter)
```

**After:**
```swift
private func contentWithNavigation(using m: RemoteMatch, adapter: RemoteGameStateAdapter) -> some View {
    let baseOverlayState = adapter.overlayState(
        isSaving: gameViewModel.isSaving,
        isRevealing: gameViewModel.isRevealingScore
    )
    
    // 🎯 UI GATE: keep the lock overlay up through reveal + rotate + padding
    let overlayState: RemoteGameStateAdapter.OverlayState = {
        if turnUIGateActive {
            return .inactiveLockout
        }
        return baseOverlayState
    }()
    
    return gameplayContent(overlayState, using: m, adapter: adapter)
```

### Timing Verification

**Turn gate unlock sequence (already correct):**

```swift
revealTask = Task { @MainActor in
    do {
        // Phase A: Hold reveal (1.2s)
        try await Task.sleep(nanoseconds: revealHoldNs)
        
        // Rotate card AFTER reveal hold
        print("🎯 [TurnGate] ROTATE (after reveal hold)")
        displayCurrentPlayerId = serverCurrentPlayerId
        
        // Phase B: Keep overlay locked during rotation animation (0.5s)
        try await Task.sleep(nanoseconds: rotateAnimNs + postRotatePaddingNs)
        
        // NOW unlock + clear reveal (at 1.7s total)
        print("🎯 [TurnGate] UNLOCK UI (after rotate)")
        preTurnRevealIsActive = false
        turnTransitionLocked = false
        turnUIGateActive = false  // ← This triggers overlay to hide
        print("🎯 [TurnGate] displayCP=\(displayCurrentPlayerId?.uuidString.prefix(8) ?? "nil") unlocked")
    } catch {
        print("🎯 [TURN_GATE] cancelled")
    }
}
```

**Critical:** `turnUIGateActive = false` happens AFTER both sleep phases, ensuring overlay stays visible through entire sequence.

---

## User Experience Flow

### Player 2's Device (receiving opponent's visit)

1. **t=0.0s** - Opponent saves
   - TURN_GATE triggers
   - `turnUIGateActive = true`
   - **Lock overlay appears** (forced to `.inactiveLockout`)

2. **t=0.0s** - Score updates
   - Opponent's score changes (e.g., 301 → 259)
   - **Lock overlay STAYS visible** (still `.inactiveLockout`)

3. **t=0.0-1.2s** - Reveal hold
   - Opponent's darts displayed
   - **Lock overlay STAYS visible**

4. **t=1.2s** - Rotation starts
   - Player card begins rotating to Player 2
   - **Lock overlay STAYS visible** (key improvement!)

5. **t=1.2-1.55s** - Rotation animation
   - Card animating
   - **Lock overlay STAYS visible**

6. **t=1.55-1.7s** - Post-rotation padding
   - Card rotation complete
   - **Lock overlay STAYS visible**

7. **t=1.7s** - Unlock
   - `turnUIGateActive = false`
   - Overlay state returns to `baseOverlayState`
   - **Lock overlay disappears**
   - Input enabled for Player 2

---

## Expected Log Sequence

```
🎯 [TURN_GATE] TRIGGER(lvp.ts change): serverCP=5529 lvp.pid=abc123...
🎯 [TURN_GATE] LOCK ON
🎯 [TurnGate] UI GATE ON (lock overlay held)
🎯 [PreTurnReveal] SHOW darts=[16, 16, 10]...
[... opponent score updates, overlay stays visible ...]
[... 1.2s reveal hold, overlay stays visible ...]
🎯 [TurnGate] ROTATE (after reveal hold)
[... 0.35s rotation animation, overlay stays visible ...]
[... 0.15s post-rotation padding, overlay stays visible ...]
🎯 [TurnGate] UNLOCK UI (after rotate)
🎯 [TurnGate] displayCP=5529... unlocked
[... overlay disappears, input enabled ...]
```

---

## Key Features

✅ **Lock overlay held through entire sequence** - No premature disappearance  
✅ **Forced `.inactiveLockout` state** - Overrides base overlay state  
✅ **Score updates visible while locked** - Opponent score changes immediately  
✅ **Overlay stays during rotation** - Key visual improvement  
✅ **Clean unlock after padding** - Overlay disappears slightly after rotation  
✅ **Simple implementation** - Single conditional in overlay state computation  

---

## Tuning Options

### Extend Lock Overlay Duration

Increase post-rotation padding for longer overlay visibility:

```swift
private let postRotatePaddingNs: UInt64 = 250_000_000  // 0.25s instead of 0.15s
```

This would make total lock duration: 1.2s + 0.35s + 0.25s = **1.8 seconds**

### Shorten Lock Overlay Duration

Decrease post-rotation padding for quicker unlock:

```swift
private let postRotatePaddingNs: UInt64 = 100_000_000  // 0.1s instead of 0.15s
```

This would make total lock duration: 1.2s + 0.35s + 0.1s = **1.65 seconds**

---

## Files Modified

### RemoteGameplayView.swift

**Lines 638-652:**
- Replaced direct `overlayState` computation with gated version
- Added `baseOverlayState` intermediate variable
- Added conditional logic to force `.inactiveLockout` when `turnUIGateActive == true`

---

## Testing Checklist

- [ ] Lock overlay visible when opponent saves
- [ ] Lock overlay stays visible when opponent's score updates
- [ ] Lock overlay stays visible during reveal hold (1.2s)
- [ ] Lock overlay stays visible during card rotation animation (0.35s)
- [ ] Lock overlay stays visible during post-rotation padding (0.15s)
- [ ] Lock overlay disappears at ~1.7s (after all phases complete)
- [ ] Input becomes enabled only after overlay disappears
- [ ] Logs show "UI GATE ON" when triggered
- [ ] Logs show "UNLOCK UI (after rotate)" when overlay should disappear
- [ ] Transition feels smooth and polished

---

## Why This Works

1. **Overlay state override** - Forces lock overlay regardless of base state
2. **Tied to turn gate** - Lock overlay lifecycle matches turn transition lifecycle
3. **Simple conditional** - Single `if turnUIGateActive` check
4. **No timing dependencies** - Overlay state automatically updates when gate changes
5. **Clean separation** - Base overlay state still computed, just overridden when needed

---

## Performance

**Lock overlay visibility duration:** 1.7 seconds total
- Reveal hold: 1.2s
- Rotation animation: 0.35s
- Post-rotation padding: 0.15s

**User perception:** Lock overlay provides clear visual feedback that the UI is locked throughout the entire turn transition, creating a smooth and deliberate experience.
