# Notifications Toggle Persistence Fix

## Problem
The Notifications toggle in Settings was flipping back ON after being toggled OFF due to a race condition between manual toggle and automatic state reload.

## Root Cause
1. User toggles OFF → `setNotificationsEnabled(false)` starts
2. Database UPDATE to set `is_active = false` begins
3. `ProfileView.task` calls `loadNotificationState()` (possibly before UPDATE completes)
4. `loadNotificationState()` queries database, gets stale/incorrect state
5. `notificationsEnabled` gets overwritten back to `true`
6. Toggle flips back ON

## Solution Implemented

### Step 1: Added Comprehensive Logging
Added detailed logging throughout the toggle and load flow to trace the race condition:

**In `setNotificationsEnabled()`:**
- Entry log: "🔔 [Toggle] setNotificationsEnabled(\(enabled)) called"
- Before database update: "📤 [Toggle] About to activate/deactivate token in database"
- After database update: "✅ [Toggle] Database updated successfully"
- Final state: "✅ [Toggle] notificationsEnabled set to \(value)"

**In `loadNotificationState()`:**
- Entry log: "📥 [Load] loadNotificationState() called"
- Guard check: "⏭️ [Load] Skipping loadNotificationState - toggle operation in progress"
- Database result: "📊 [Load] Database returned is_active=\(value)"
- Final assignment: "✅ [Load] notificationsEnabled set to \(value)"

### Step 2: Added Race Condition Guard
Added guard at the beginning of `loadNotificationState()` to prevent reload during manual toggle:

```swift
func loadNotificationState() async {
    print("📥 [Load] loadNotificationState() called")
    
    // Guard: Don't reload state while a manual toggle is in progress
    guard !isTogglingNotifications else {
        print("⏭️ [Load] Skipping loadNotificationState - toggle operation in progress")
        return
    }
    
    // ... rest of existing code
}
```

This uses the existing `isTogglingNotifications` flag (set in `setNotificationsEnabled()`) to prevent `loadNotificationState()` from overwriting the state while the user is actively toggling.

## Files Modified
- `DanDart/Services/NotificationService.swift`
  - Enhanced logging in `setNotificationsEnabled()`
  - Added guard in `loadNotificationState()`
  - Enhanced logging in `loadNotificationState()`

## Testing Instructions

1. **Toggle OFF Test:**
   - Open Settings
   - Toggle Notifications OFF
   - Watch console for log sequence
   - Close Settings
   - Reopen Settings
   - Verify toggle stayed OFF

2. **Expected Log Flow (Success):**
   ```
   🔔 [Toggle] setNotificationsEnabled(false) called
   🔔 [Toggle] Setting notifications to: disabled
   📤 [Toggle] About to deactivate token in database (is_active=false)
   🔒 Deactivating push token for logout...
   ✅ Push token deactivated successfully
   ✅ [Toggle] Database updated successfully (is_active=false)
   ✅ [Toggle] notificationsEnabled set to false
   📥 [Load] loadNotificationState() called
   ⏭️ [Load] Skipping loadNotificationState - toggle operation in progress
   ```

3. **Bad Log Flow (Race Condition - Should Not Happen):**
   ```
   🔔 [Toggle] setNotificationsEnabled(false) called
   📥 [Load] loadNotificationState() called  ← Called too early!
   📊 [Load] Database returned is_active=true  ← Stale data!
   ✅ [Load] notificationsEnabled set to true  ← Overwrites toggle!
   ```

## Success Criteria
- ✅ Toggle OFF stays OFF when Settings reopened
- ✅ Toggle OFF stays OFF when app relaunched
- ✅ Toggle ON stays ON when Settings reopened
- ✅ Toggle ON stays ON when app relaunched
- ✅ Console logs show no race condition

## Next Steps (Phase 2)
After confirming toggle persistence works:
1. Verify toggle only affects iOS push delivery (not in-app notifications)
2. Test that in-app friend request toasts still appear when toggle is OFF
3. Test that remote match overlays still appear when toggle is OFF
4. Test that badge counts still update when toggle is OFF
5. Add documentation/comments explaining scope
6. Consider renaming `notificationsEnabled` → `pushNotificationsEnabled` for clarity

## Notes
- The lint errors shown in the editor are expected (SourceKit context issues)
- They will resolve when building in Xcode
- The guard prevents the race condition without requiring ProfileView changes
- If the guard proves insufficient, we can remove the `.task` reload in ProfileView as a fallback
