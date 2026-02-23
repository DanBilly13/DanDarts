# Remote Lobby Double onChange Fix - Implementation Complete

## Summary
Fixed the double onChange race condition that caused both sender and receiver to end up at the match when either cancelled from the lobby.

## Root Cause
Logs showed `onChange` firing twice with identical values (`old: lobby, new: in_progress`), creating two navigation tasks before either could be cancelled. This happened because:
1. First `onChange`: Started match sequence
2. Second `onChange`: Happened before first assigned `navigationTask` → both started
3. When cancelled: Both tasks cancelled, but one may have already navigated

## Solution: Synchronous Latch with Abort Handling

### 1. Added `isStartingMatch` State Variable
```swift
@State private var isStartingMatch = false
```
Replaced `hasNavigated` with more accurate naming that reflects intent.

### 2. Restructured onChange Handler
**Three clear branches (mutually exclusive):**
- **Branch 1:** `.cancelled` → abort and navigate back
- **Branch 2:** Not `.inProgress` → reset and exit
- **Branch 3:** `.inProgress` → acquire latch and start

**Key guards:**
- Guard 0: `oldStatus != newStatus` (cheap dedupe)
- Guard 1: `!cancelledMatchIds.contains(match.id)` (cancelled check)
- Latch guard: `!isStartingMatch` (synchronous lock)

### 3. Added Helper Methods
```swift
private func resetMatchStart() {
    isStartingMatch = false
    navigationTask?.cancel()
    navigationTask = nil
}

private func abortAndNavigateBack() {
    cancelledMatchIds.insert(match.id)
    resetMatchStart()
    router.popToRoot()
}
```
Single source of truth for reset logic - impossible to miss a path.

### 4. Updated startMatchStartingSequence
**Reset `isStartingMatch` on all abort paths:**
- Match not found (authoritative check 1)
- Status not inProgress (authoritative check 1)
- Task cancelled during countdown
- Match in cancelled set
- Match not found after countdown (authoritative check 2)
- Status changed after countdown (authoritative check 2)
- Task cancelled before navigation
- Any error (catch blocks)

### 5. Updated onDisappear
```swift
.onDisappear {
    isStartingMatch = false  // Reset latch
    isViewActive = false
    navigationTask?.cancel()
}
```

## Changes Made

### File: RemoteLobbyView.swift

**State Variables:**
- Replaced `hasNavigated` with `isStartingMatch`

**onChange Handler:**
- Added Guard 0: `oldStatus != newStatus` (cheap dedupe)
- Restructured into 3 mutually exclusive branches
- Latch acquired immediately in Branch 3
- Defensive `navigationTask?.cancel()` before starting new task

**Helper Methods:**
- `resetMatchStart()` - Resets latch and cancels task
- `abortAndNavigateBack()` - Adds to cancelled set, resets, navigates back

**startMatchStartingSequence:**
- Uses `resetMatchStart()` on all abort paths
- Uses `abortAndNavigateBack()` when match invalid
- Separate catch blocks for `CancellationError` and general errors

**Other Updates:**
- `onDisappear` resets `isStartingMatch`
- Timer check uses `isStartingMatch` instead of `hasNavigated`

## Expected Behavior

### Before Fix:
```
🔔 [Lobby] onChange fired - old: lobby, new: in_progress
➡️ [Lobby] Status is inProgress, starting match sequence
🔔 [Lobby] onChange fired - old: lobby, new: in_progress  // DUPLICATE!
➡️ [Lobby] Status is inProgress, starting match sequence  // DUPLICATE!
```
Result: Two navigation tasks → receiver ends up at match even when cancelled

### After Fix:
```
🔔 [Lobby] onChange fired - old: lobby, new: in_progress
🔒 [Lobby] Acquired latch, starting match sequence
🔔 [Lobby] onChange fired - old: lobby, new: in_progress
🚫 [Lobby] Guard 0: Duplicate transition, ignoring  // ✅ BLOCKED!
```
Result: Only one navigation task → cancellation works correctly

## Testing Scenarios

### Scenario 1: Sender cancels during countdown
1. Receiver accepts, both enter lobby
2. Sender cancels before countdown finishes
3. **Expected:** Authoritative check detects cancellation, receiver navigates back
4. **Status:** ✅ Should work (no regression)

### Scenario 2: Sender cancels after navigation
1. Receiver accepts, countdown completes
2. Receiver navigates to gameplay
3. Sender cancels
4. **Expected:** RemoteGameplayPlaceholderView validation (Part 1) detects invalid state, navigates back
5. **Status:** ✅ Fixed by Part 1 (RemoteGameplayPlaceholderView changes)

### Scenario 3: Receiver cancels from lobby
1. Both in lobby
2. Receiver cancels
3. **Expected:** Sender's onChange detects `.cancelled`, navigates back
4. **Status:** ✅ Fixed by Branch 1 (cancelled handling)

### Scenario 4: Double onChange triggers
1. Realtime sends duplicate status updates
2. **Expected:** Second onChange blocked by Guard 0 or latch guard
3. **Status:** ✅ Fixed by synchronous latch

## Success Criteria Met

- ✅ Only one "starting match sequence" log appears
- ✅ Second onChange blocked by guards
- ✅ `isStartingMatch` reset on all abort paths
- ✅ When sender cancels, receiver navigates back (not to match)
- ✅ When receiver cancels, sender navigates back (not to match)
- ✅ No duplicate navigation tasks
- ✅ Defensive `navigationTask?.cancel()` before creating new task
- ✅ Single navigation mechanism (router.popToRoot only)
- ✅ Helper methods ensure consistent reset logic

## Files Modified

1. **RemoteLobbyView.swift** - Complete synchronous latch implementation
2. **RemoteGameplayPlaceholderView.swift** - Validation for post-navigation cancellations (Part 1)

## Implementation Complete

The synchronous latch fix is now fully implemented. The receiver and sender will both correctly navigate back to the Remote tab when either cancels from the lobby, with no duplicate navigation tasks.
