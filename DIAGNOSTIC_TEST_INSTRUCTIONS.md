# Friend Request Notification Diagnostic Test

## Changes Made

Added comprehensive logging to `MainTabView.swift` to track the entire friend request notification flow:

1. **Notification Reception** (lines 128-132)
   - Logs when `FriendRequestsChanged` notification is received
   - Shows current badge count
   - Shows thread information

2. **Badge Count Loading** (lines 180-205)
   - Logs when `loadPendingRequestCount()` is called
   - Logs current user ID
   - Logs query execution
   - Logs query result
   - Logs badge count update (before/after)

## How to Run the Test

### Setup
1. **Device A** (Your phone): 
   - Connect to Xcode
   - Build and run the app
   - Sign in as yourself
   - Stay on the **Games tab** (important!)

2. **Device B** (Test phone/simulator):
   - Sign in as a different test user
   - Navigate to Friends → Search

### Test Procedure

1. **Open Xcode Console** for Device A
2. **Clear the console** (Cmd+K) for a clean view
3. **From Device B**: Send a friend request to Device A
4. **Watch Device A console** for the log sequence

### Expected Log Sequence (If Working Correctly)

```
🔵 [Realtime] SUBSCRIPTION ACTIVE
🔔 [Realtime] INSERT CALLBACK FIRED!
📝 [Handler] handleFriendshipInsert CALLED
📝 [Handler] Posted FriendRequestsChanged notification
🎯 [MainTabView] ========================================
🎯 [MainTabView] Received FriendRequestsChanged notification
🎯 [MainTabView] Current badge count: 0
🎯 [MainTabView] Thread: <_NSMainThread: 0x...>
🎯 [MainTabView] ========================================
🎯 [MainTabView] loadPendingRequestCount() called
🎯 [MainTabView] Current user: [USER-UUID]
🎯 [MainTabView] Querying pending requests for user: [USER-UUID]
✅ [MainTabView] Query returned count: 1
🎯 [MainTabView] Updating badge count from 0 to 1
✅ [MainTabView] Badge count updated successfully
📝 [Toast] Creating toast for: [Test User Name]
🎯 [ToastManager] showToast called
```

## What to Look For

### Scenario 1: No Realtime Callback
**Logs Stop At:** Nothing appears after sending request
**Problem:** Supabase realtime subscription not working
**Next Steps:** 
- Check Supabase dashboard → Realtime is enabled
- Check RLS policies on friendships table
- Verify channel subscription in `setupRealtimeSubscription()`

### Scenario 2: Callback Fires, No Notification Posted
**Logs Stop At:** `🔔 [Realtime] INSERT CALLBACK FIRED!` but no `Posted FriendRequestsChanged`
**Problem:** Handler not executing properly
**Next Steps:**
- Check `handleFriendshipInsert()` method
- Verify async/await execution
- Check for early returns in handler

### Scenario 3: Notification Posted, Not Received
**Logs Stop At:** `Posted FriendRequestsChanged notification` but no `Received FriendRequestsChanged`
**Problem:** NotificationCenter observer not working
**Next Steps:**
- Verify observer is registered (check onAppear logs)
- Check if MainTabView is actually mounted
- Verify queue is .main

### Scenario 4: Notification Received, Badge Not Updated
**Logs Stop At:** `Received FriendRequestsChanged notification` but no `Query returned count`
**Problem:** Badge count query failing
**Next Steps:**
- Check error logs
- Verify user authentication
- Check FriendsService.getPendingRequestCount()

### Scenario 5: Query Works, UI Not Updating
**Logs Show:** All logs appear including "Badge count updated successfully"
**But:** Badge still doesn't show on screen
**Problem:** UI state not triggering view refresh
**Next Steps:**
- Check @State/@Published properties
- Verify MainActor execution
- Check TabView badge binding

## After the Test

1. **Copy the console logs** from Device A
2. **Identify where the logs stop** using the scenarios above
3. **Share the logs** so we can pinpoint the exact issue
4. **Implement targeted fix** based on the diagnosis

## Quick Verification

After sending the friend request, check:
- [ ] Did any logs appear in console?
- [ ] Did badge appear on Friends tab?
- [ ] Did toast notification appear?
- [ ] Does request show in FriendsListView?

## Notes

- The extensive logging in `FriendsService.swift` is already in place
- The logging in `FriendRequestToastManager.swift` is already in place
- We only added logging to `MainTabView.swift` to complete the diagnostic chain
- These logs can be removed after we fix the issue
