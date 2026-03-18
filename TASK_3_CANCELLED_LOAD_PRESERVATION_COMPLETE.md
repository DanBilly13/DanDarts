# Task 3: Stop Cancelled Loads from Clearing Remote Match List UI - COMPLETE ✅

## Summary of the Bug

**Problem:** Cancelled network requests caused temporary empty-state flicker and unstable list presentation:
```
NSURLErrorDomain Code=-999 "cancelled"
```

**Observed Behavior:**
1. User navigates away during match load
2. Network request gets cancelled (Code -999)
3. Error handler clears all match lists
4. UI briefly shows empty state
5. Next load repopulates lists
6. Result: Jarring flicker and unstable UI

**Root Cause:** The `loadMatches` error handler treated cancellation the same as real errors, clearing all published arrays (`pendingChallenges`, `sentChallenges`, `readyMatches`, `activeMatch`) even though cancellation is expected control flow, not a failure.

**Impact:** Poor UX with flickering lists, especially during navigation or when multiple overlapping requests occur.

---

## Summary of the Fix

**Solution:** Special-case cancellation errors to preserve current UI state instead of clearing it.

**Implementation:**
1. Check if error is `NSURLErrorCancelled` (domain: NSURLErrorDomain, code: -999)
2. If cancelled: Log as benign, preserve current state, return early (no throw)
3. If real error: Clear lists and propagate error as before

**Key Insight:** Cancellation is not a failure - it's expected control flow when:
- User navigates away during load
- New load request supersedes old one
- Component unmounts before request completes
- Network conditions change

---

## Files Changed

### RemoteMatchService.swift

**Lines 439-459:** Added cancellation-aware error handling in `loadMatches`

```swift
// BEFORE (treated all errors the same):
} catch {
    FlowDebug.log("LOAD: RUN \(runNumber) ERROR \(error.localizedDescription)", matchId: nil)
    // Clear lists to prevent stale UI state from persisting
    await MainActor.run {
        self.pendingChallenges = []
        self.sentChallenges = []
        self.readyMatches = []
        self.activeMatch = nil
    }
    throw error
}

// AFTER (special-case cancellation):
} catch {
    // Check if this is a cancellation error
    let isCancelled = (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled
    
    if isCancelled {
        // Cancellation is expected control flow - preserve current UI state
        FlowDebug.log("LOAD: RUN \(runNumber) CANCELLED - preserving current UI state", matchId: nil)
        // Don't clear lists, don't throw - just return quietly
        return
    }
    
    // For real errors, clear lists and propagate
    FlowDebug.log("LOAD: RUN \(runNumber) ERROR \(error.localizedDescription)", matchId: nil)
    await MainActor.run {
        self.pendingChallenges = []
        self.sentChallenges = []
        self.readyMatches = []
        self.activeMatch = nil
    }
    throw error
}
```

---

## Schema/API Impact

**None.** This is a client-side error handling fix only. No database, edge function, or API changes.

---

## Expected Before/After Logs

### Before (Broken - Cancellation Clears UI)

**User navigates away during load:**
```
🔄 LOAD: RUN 5 BEGIN inRemoteFlow=true enteringFlow=false
🔄 LOAD: RUN 5 QUERY returned 3 matches
🔄 LOAD: RUN 5 ERROR The operation couldn't be completed. (NSURLErrorDomain error -999.)
🔄 LOAD: RUN 5 PUBLISH pending=[] ready=[] sent=[] active=none
```

**Result:** Lists cleared, empty state shown briefly, then next load repopulates.

---

### After (Fixed - Cancellation Preserves UI)

**User navigates away during load:**
```
🔄 LOAD: RUN 5 BEGIN inRemoteFlow=true enteringFlow=false
🔄 LOAD: RUN 5 QUERY returned 3 matches
🔄 LOAD: RUN 5 CANCELLED - preserving current UI state
```

**Result:** Current lists preserved, no empty state flicker, stable UI.

---

### Real Error Still Handled Correctly

**Network failure (not cancellation):**
```
🔄 LOAD: RUN 6 BEGIN inRemoteFlow=true enteringFlow=false
🔄 LOAD: RUN 6 ERROR The Internet connection appears to be offline.
🔄 LOAD: RUN 6 PUBLISH pending=[] ready=[] sent=[] active=none
```

**Result:** Lists cleared, error propagated, UI shows empty state (correct behavior for real errors).

---

## Where Cancellation Is Now Handled

### Detection Logic

**NSURLErrorCancelled Check:**
```swift
let isCancelled = (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled
```

**Why this check:**
- `NSURLErrorDomain` - Foundation networking errors
- Code `-999` - `NSURLErrorCancelled` constant
- Standard iOS pattern for detecting cancelled requests

### Cancellation Scenarios Handled

**Scenario 1: Navigation During Load**
- User taps back while matches loading
- Request cancelled automatically
- **Before:** Empty state flicker
- **After:** Current state preserved

**Scenario 2: Overlapping Requests**
- New load starts before old one finishes
- Old request cancelled
- **Before:** Brief empty state between requests
- **After:** Smooth transition, no flicker

**Scenario 3: Component Unmount**
- View dismissed during load
- Request cancelled on cleanup
- **Before:** Unnecessary state clearing
- **After:** Silent cancellation, no side effects

**Scenario 4: Network Condition Change**
- WiFi to cellular transition
- Pending requests cancelled
- **Before:** Empty state flash
- **After:** Current data remains visible

---

## How UI State Is Preserved

### Preservation Strategy

**When cancellation detected:**
1. ✅ Keep current `pendingChallenges` array
2. ✅ Keep current `sentChallenges` array
3. ✅ Keep current `readyMatches` array
4. ✅ Keep current `activeMatch` value
5. ✅ Log cancellation as benign event
6. ✅ Return early (no throw, no error propagation)

**Why this is safe:**
- Cancellation means "request superseded" not "data invalid"
- Current state is still valid, just not updated
- Next successful load will update state properly
- No stale data risk (next load overwrites)

### Empty State Prevention

**Before:**
```
Visible matches → Load starts → Cancelled → Empty state → Next load → Visible matches
                                    ↑
                              Jarring flicker
```

**After:**
```
Visible matches → Load starts → Cancelled → Visible matches (preserved) → Next load → Updated matches
                                                ↑
                                          Smooth, stable
```

---

## Distinction: Cancellation vs Real Errors

### Cancellation (Preserve State)

**Characteristics:**
- Error domain: `NSURLErrorDomain`
- Error code: `-999` (NSURLErrorCancelled)
- Meaning: Request intentionally stopped
- Action: Preserve current UI state
- Logging: Benign event, no alarm

**Examples:**
- User navigated away
- New request superseded old one
- Component unmounted
- Network transition

---

### Real Errors (Clear State)

**Characteristics:**
- Any other error domain/code
- Meaning: Actual failure occurred
- Action: Clear lists, show empty state
- Logging: Error event, needs attention

**Examples:**
- Network offline
- Server error (500)
- Authentication failure
- Timeout
- Invalid response

---

## Risks / Edge Cases

### Edge Case 1: Rapid Navigation
- **Scenario:** User rapidly navigates back and forth
- **Handling:** Multiple cancellations, all preserve state
- **Result:** Stable UI, no flicker

### Edge Case 2: Cancellation After Partial Data
- **Scenario:** Request cancelled mid-stream after receiving some data
- **Handling:** Cancellation detected before state update
- **Result:** Previous complete state preserved

### Edge Case 3: Cancellation Then Real Error
- **Scenario:** Cancelled request followed by failed request
- **Handling:** Cancellation preserves, error clears
- **Result:** Correct behavior for each case

### Edge Case 4: Multiple Overlapping Loads
- **Scenario:** 3 loads in quick succession
- **Handling:** First 2 cancelled (preserve), last succeeds (update)
- **Result:** Smooth progression to final state

### Edge Case 5: Cancellation During Empty State
- **Scenario:** Lists already empty, load cancelled
- **Handling:** Empty arrays preserved (still empty)
- **Result:** No change, correct behavior

---

## Why It Is Safe to Move to Next Task

### 1. Minimal, Targeted Change
- Only modified error handling in `loadMatches`
- No changes to success path
- No changes to query logic
- No changes to state publishing

### 2. Preserves Existing Flow
- Successful loads still work identically
- Real errors still handled correctly
- State updates unchanged
- UI binding unchanged

### 3. No Breaking Changes
- Backward compatible
- No API changes
- No schema changes
- No new dependencies

### 4. Standard Pattern
- Cancellation detection is standard iOS pattern
- `NSURLErrorCancelled` is well-documented
- Preserving state on cancellation is common practice
- No custom logic needed

### 5. Defensive Programming
- Explicit check for cancellation
- Clear separation of cancellation vs errors
- Detailed logging for debugging
- No silent failures

### 6. Better UX
- Eliminates empty-state flicker
- Stable list presentation
- Smooth navigation experience
- No jarring transitions

---

## Acceptance Criteria

✅ **No empty-state flicker caused by cancelled reloads**
- Cancellation detected and handled specially
- Current state preserved during cancellation

✅ **Pending/ready cards remain stable during overlapping requests**
- Multiple cancellations don't cause UI instability
- Smooth progression to final state

✅ **Cancellation logs remain visible but non-destructive**
- Logged as benign event: "CANCELLED - preserving current UI state"
- No error propagation
- No alarm raised

✅ **True empty results still publish correctly**
- Real errors still clear state
- Successful loads with 0 matches still show empty state
- Only cancellation preserves state

✅ **True failures are still observable**
- Real errors still logged with ERROR prefix
- Error still propagated to callers
- Empty state shown for real failures

---

## Testing Recommendations

### Test 1: Navigation During Load
1. Start loading matches
2. Navigate away before load completes
3. **Verify:** No empty state flicker
4. **Verify:** Log shows "CANCELLED - preserving current UI state"
5. **Verify:** Previous matches still visible

### Test 2: Overlapping Requests
1. Trigger multiple loads in quick succession
2. **Verify:** No empty state between loads
3. **Verify:** Multiple "CANCELLED" logs
4. **Verify:** Final load succeeds and updates UI

### Test 3: Real Network Error
1. Disconnect network
2. Attempt to load matches
3. **Verify:** Empty state shown
4. **Verify:** Log shows "ERROR The Internet connection appears to be offline"
5. **Verify:** Error propagated correctly

### Test 4: Successful Load After Cancellation
1. Start load, cancel it
2. Start new load, let it complete
3. **Verify:** First load cancelled (state preserved)
4. **Verify:** Second load succeeds (state updated)
5. **Verify:** No flicker between states

---

## Summary

Task 3 is complete. Cancelled network requests no longer clear the remote match list UI. Cancellation is now treated as expected control flow rather than a destructive error, preserving current UI state and eliminating empty-state flicker. The fix is minimal, uses standard iOS patterns, and maintains correct error handling for real failures.

**Ready to proceed to Task 4.**

---

**Status:** Complete ✅  
**Date:** 2026-03-18  
**Files Changed:** 1 (RemoteMatchService.swift)  
**Lines Changed:** ~20 lines (cancellation detection and handling)  
**Schema Changes:** None  
**Risk:** Low (standard pattern, minimal change)  
**Next:** Task 4 - Reduce redundant navigation/state updates during accept/lobby flow
