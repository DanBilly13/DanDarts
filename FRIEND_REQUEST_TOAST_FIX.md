# Friend Request Toast Notification Fix

## Problem
Toast notifications for friend requests only appeared after visiting the Friends tab, even though the badge count worked correctly.

## Root Cause
The realtime subscription was only set up in `MainTabView.onChange(of: authService.currentUser?.id)`, which only triggers when the user ID **changes**. When a user was already authenticated at app launch, this never fired, so the subscription was never established.

The subscription only got set up when visiting the Friends tab because `FriendsListView` had its own setup in `.onAppear`.

## Solution Implemented

### 1. MainTabView.swift - Added Subscription Setup on App Launch
Added realtime subscription setup to `.onAppear` so it runs immediately when the app launches with an authenticated user:

```swift
.onAppear {
    configureTabBarAppearance()
    loadPendingRequestCount()

    if inviteTokenToClaim == nil, let token = PendingInviteStore.shared.getToken() {
        inviteTokenToClaim = InviteTokenToClaim(id: token, token: token)
    }
    
    // Setup realtime subscription on app launch if user is authenticated
    if let userId = authService.currentUser?.id {
        Task {
            await friendsService.setupRealtimeSubscription(userId: userId)
        }
    }
    
    // ... rest of existing code
}
```

### 2. FriendsListView.swift - Removed Duplicate Subscription
Removed duplicate realtime subscription setup/teardown since MainTabView now handles this globally:

**Before:**
```swift
.onAppear {
    loadFriends()
    loadRequests()
    loadGuests()
    
    // Setup realtime subscription
    if let userId = authService.currentUser?.id {
        Task {
            await friendsService.setupRealtimeSubscription(userId: userId)
        }
    }
}
.onDisappear {
    Task {
        await friendsService.removeRealtimeSubscription()
    }
}
```

**After:**
```swift
.onAppear {
    loadFriends()
    loadRequests()
    loadGuests()
}
```

### 3. FriendRequestsView.swift - Removed Duplicate Subscription
Same cleanup as FriendsListView - removed duplicate subscription setup/teardown.

## Result

✅ Toast notifications now appear immediately when friend request is received
✅ Works on any tab (Games, Friends, History)
✅ No need to visit Friends tab first
✅ Badge count continues to work correctly
✅ Single source of truth for realtime subscription lifecycle (MainTabView)

## Files Modified

1. **MainTabView.swift** (lines 110-115)
   - Added realtime subscription setup to `.onAppear`

2. **FriendsListView.swift** (lines 274-278)
   - Removed duplicate subscription setup/teardown

3. **FriendRequestsView.swift** (lines 149-151)
   - Removed duplicate subscription setup/teardown

## Testing

To verify the fix:
1. Sign in to the app
2. Stay on Games tab (or any tab except Friends)
3. Have another user send a friend request
4. Toast notification should appear immediately
5. Badge count should update on Friends tab
6. Toast should work on all tabs without visiting Friends first

## Technical Details

- **Realtime Subscription**: Supabase Realtime V2 listening to `friendships` table
- **Toast Manager**: `FriendRequestToastManager.shared` (singleton)
- **Subscription Lifecycle**: Managed by MainTabView (setup on app launch, teardown on logout)
- **Event Handlers**: `handleInsertToast`, `handleUpdateToast`, `handleDeleteToast` in FriendsService
