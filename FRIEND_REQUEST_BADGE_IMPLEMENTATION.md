# Friend Request Badge Implementation

## Feature
Added a notification badge to the Friends tab in MainTabView that displays the count of pending received friend requests.

## Implementation

### 1. MainTabView.swift - Badge Display

**Added State:**
```swift
@StateObject private var friendsService = FriendsService()
@State private var pendingRequestCount: Int = 0
```

**Added Badge to Friends Tab:**
```swift
.badge(pendingRequestCount > 0 ? "\(pendingRequestCount)" : "")
```

**Badge Behavior:**
- Shows number when count > 0
- Shows empty string (no badge) when count = 0
- Uses iOS standard red badge styling

### 2. Loading Badge Count

**loadPendingRequestCount() Method:**
- Queries `FriendsService.getPendingRequestCount(userId:)`
- Only counts **received** requests (not sent requests)
- Updates on:
  - App launch (`.onAppear`)
  - User sign in (`.onChange(of: authService.currentUser)`)
  - Friend request changes (NotificationCenter)

**Query Logic:**
```sql
SELECT COUNT(*) FROM friendships
WHERE addressee_id = 'user-uuid'
  AND status = 'pending';
```

### 3. Real-Time Updates

**NotificationCenter Integration:**
- MainTabView listens for `"FriendRequestsChanged"` notification
- FriendsListView posts notification when:
  - Friend request accepted
  - Friend request denied
- Badge count automatically refreshes

**Notification Flow:**
1. User accepts/denies request in FriendsListView
2. `NotificationCenter.default.post(name: "FriendRequestsChanged", ...)`
3. MainTabView receives notification
4. `loadPendingRequestCount()` called
5. Badge updates with new count

### 4. FriendsListView.swift - Notification Posting

**Added to acceptRequest():**
```swift
// Notify MainTabView to update badge
NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsChanged"), object: nil)
```

**Added to denyRequest():**
```swift
// Notify MainTabView to update badge
NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsChanged"), object: nil)
```

## User Experience

### Badge Display:
- **No requests:** No badge shown (clean tab bar)
- **1 request:** Shows "1" in red badge
- **5+ requests:** Shows "5" in red badge
- **iOS Standard:** Uses native iOS badge styling

### Badge Updates:
- **Instant:** Updates immediately when request accepted/denied
- **Automatic:** No manual refresh needed
- **Accurate:** Always shows current count from database

### Visual Example:
```
┌─────────────────────────────┐
│  Games    Friends②   History│  ← Badge shows "2" pending requests
└─────────────────────────────┘
```

## Technical Details

### Service Method (Already Existed):
**FriendsService.getPendingRequestCount(userId:)**
- Returns: `Int` count of pending received requests
- Query: Filters by `addressee_id` and `status = 'pending'`
- Error handling: Returns 0 on error

### Badge Modifier:
- Uses SwiftUI's `.badge()` modifier (iOS 15+)
- Accepts `String` parameter
- Empty string = no badge shown
- Number string = shows badge with number

### Memory Management:
- NotificationCenter observer added in `.onAppear`
- Observer removed in `.onDisappear`
- Prevents memory leaks

## Testing

1. **No Requests:**
   - Sign in with account that has no pending requests
   - Friends tab should show no badge

2. **With Requests:**
   - Have another user send friend request
   - Badge should appear with count "1"

3. **Accept Request:**
   - Accept the friend request
   - Badge should disappear (count becomes 0)

4. **Multiple Requests:**
   - Have multiple users send requests
   - Badge should show correct count (e.g., "3")

5. **Deny Request:**
   - Deny a request
   - Badge count should decrease by 1

## Files Modified

1. **MainTabView.swift**
   - Added `@StateObject friendsService`
   - Added `@State pendingRequestCount`
   - Added `.badge()` modifier to Friends tab
   - Added `loadPendingRequestCount()` method
   - Added NotificationCenter observer

2. **FriendsListView.swift**
   - Added NotificationCenter post in `acceptRequest()`
   - Added NotificationCenter post in `denyRequest()`

## Dependencies

- **Task 308:** Badge service method (already completed)
- **Task 303:** Accept friend request (already completed)
- **Task 304:** Deny friend request (already completed)
- **FriendsService:** getPendingRequestCount method

## Future Enhancements

Potential improvements (not currently implemented):
1. Badge animation when count changes
2. Push notifications for new friend requests
3. Badge on app icon (requires push notifications)
4. Sound/haptic when new request received
5. Real-time updates via Supabase Realtime subscriptions

## Notes

- Badge only counts **received** requests (not sent requests)
- Uses iOS standard red badge color
- Badge auto-hides when count is 0
- Updates happen on main thread (MainActor)
- Error handling: Shows 0 on query failure
- Notification name: `"FriendRequestsChanged"`
