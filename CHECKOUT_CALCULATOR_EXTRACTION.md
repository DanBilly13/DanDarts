# Checkout Calculator Extraction Complete ✅

## Summary

Extracted duplicated checkout chart logic from both `CountdownViewModel` and `RemoteGameViewModel` into a shared `CheckoutCalculator` utility.

## Changes Made

### Created Shared Utility
**File:** `DanDart/Utilities/CheckoutCalculator.swift`

**Features:**
- `suggestCheckout()` - Main calculation method
- `isCheckoutAvailable()` - Check if score has checkout
- Private `checkouts` dictionary - 170 checkout entries (2-170)
- Pure static functions (no state, no side effects)

### Updated Local ViewModel
**File:** `DanDart/ViewModels/Games/CountdownViewModel.swift`

**Before:** 120 lines of checkout logic + 170-entry dictionary
**After:** 17 lines calling shared utility

**Removed:**
- `calculateCheckout()` method (45 lines)
- `CheckoutChart` struct with 170 entries (75 lines)

### Updated Remote ViewModel
**File:** `DanDart/ViewModels/RemoteGameViewModel.swift`

**Before:** 120 lines of checkout logic + 170-entry dictionary
**After:** 17 lines calling shared utility

**Removed:**
- `calculateCheckout()` method (45 lines)
- `CheckoutChart` struct with 170 entries (75 lines)

## Code Reduction

- **Before:** ~240 lines duplicated across 2 files
- **After:** ~140 lines in shared utility + 34 lines in VMs
- **Reduction:** ~240 lines of duplication eliminated
- **Total savings:** Combined with engine extraction = ~930 lines eliminated

## Benefits

1. ✅ **Single Source of Truth** - Checkout chart defined once
2. ✅ **Easier Maintenance** - Update checkout logic in one place
3. ✅ **Consistency** - Both local and remote use identical logic
4. ✅ **Testable** - Can unit test checkout calculations independently
5. ✅ **Reusable** - Can be used by future game modes if needed

## Usage Example

```swift
// Before (duplicated in both VMs):
let remainingAfterThrow = currentScore - currentThrowTotal
let dartsLeft = 3 - currentThrow.count
guard remainingAfterThrow >= 2 && remainingAfterThrow <= 170 && dartsLeft > 0 else {
    if turnStartedWithCheckout && !currentThrow.isEmpty && remainingAfterThrow > 1 {
        suggestedCheckout = "Not Available \(remainingAfterThrow)pts left"
    } else {
        suggestedCheckout = nil
    }
    return
}
// ... 40+ more lines

// After (shared utility):
suggestedCheckout = CheckoutCalculator.suggestCheckout(
    currentScore: currentScore,
    currentThrowTotal: currentThrowTotal,
    dartsThrown: currentThrow.count,
    turnStartedWithCheckout: turnStartedWithCheckout
)
```

## Files Modified

**Created:**
- `DanDart/Utilities/CheckoutCalculator.swift` (new)

**Modified:**
- `DanDart/ViewModels/Games/CountdownViewModel.swift` (removed 120 lines)
- `DanDart/ViewModels/RemoteGameViewModel.swift` (removed 120 lines)

## Testing

Both local and remote games should continue to show checkout suggestions identically to before. The logic is unchanged, just centralized.

---

**Status:** Complete. Ready for testing alongside the engine extraction.
