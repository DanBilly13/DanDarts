# ✅ TASK 302 COMPLETED: Create Friend Requests View

## 📋 Task Requirements (from task-list-8.md)

**Checklist:**
- ✅ Create file: Views/Friends/FriendRequestsView.swift
- ✅ Add two sections: "Received Requests" and "Sent Requests"
- ✅ Display received requests with user cards
- ✅ Show "Accept" and "Deny" buttons on each received request
- ✅ Display sent requests with user cards
- ✅ Show "Withdraw" button on each sent request
- ✅ Add empty states for each section
- ✅ Show request date ("2 days ago")
- ✅ Style per design spec
- ✅ Add pull-to-refresh

**Acceptance Criteria:**
- ✅ Two clear sections visible
- ✅ All pending requests displayed
- ✅ Action buttons present and styled
- ✅ Empty states show when no requests
- ✅ Dates formatted nicely

**Dependencies:** Task 300

---

## 🔧 Implementation Summary

### **1. FriendsService.swift - Request Loading Methods**

**loadReceivedRequests(userId:)**
- Queries friendships where `addressee_id = userId` and `status = 'pending'`
- Orders by `created_at` descending (newest first)
- Fetches requester user data
- Returns array of `FriendRequest` objects with type `.received`

**loadSentRequests(userId:)**
- Queries friendships where `requester_id = userId` and `status = 'pending'`
- Orders by `created_at` descending (newest first)
- Fetches addressee user data
- Returns array of `FriendRequest` objects with type `.sent`

**FriendRequest Model:**
```swift
struct FriendRequest: Identifiable {
    let id: UUID              // Friendship ID
    let user: User            // The other user
    let createdAt: Date       // When request was created
    let type: RequestType     // .received or .sent
    
    enum RequestType {
        case received         // Current user is addressee
        case sent            // Current user is requester
    }
    
    var timeAgo: String      // "2 days ago" format
}
```

---

### **2. FriendRequestsView.swift - Main View**

**Layout Structure:**
```
NavigationStack
└── ScrollView
    ├── Received Requests Section
    │   ├── Section Header
    │   ├── Loading State (ProgressView)
    │   ├── Empty State (tray icon)
    │   └── Requests List (ReceivedRequestCard)
    ├── Divider
    └── Sent Requests Section
        ├── Section Header
        ├── Loading State (ProgressView)
        ├── Empty State (paperplane icon)
        └── Requests List (SentRequestCard)
```

**State Management:**
```swift
@State private var receivedRequests: [FriendRequest] = []
@State private var sentRequests: [FriendRequest] = []
@State private var isLoading: Bool = false
@State private var loadError: String?
@State private var isRefreshing: Bool = false
```

**Features:**
- Pull-to-refresh with `.refreshable` modifier
- Parallel loading of received and sent requests
- Error handling with console logging
- Auto-load on view appear

---

### **3. ReceivedRequestCard Component**

**Visual Design:**
```
┌─────────────────────────────────────┐
│ [Avatar] Name              2d ago   │
│          @nickname                  │
│          WINS | LOSSES     [✓] [✗]  │
└─────────────────────────────────────┘
```

**Elements:**
- **PlayerCard** - Shows user avatar, name, nickname, stats
- **Accept Button** - Green circle with checkmark icon
- **Deny Button** - Red circle with X icon
- **Time Label** - Top-right corner, relative time format

**Styling:**
- Background: InputBackground
- Corner radius: 12pt
- Padding: 16pt horizontal, 12pt vertical
- Button size: 44pt circles
- Accept: Green (#30D158)
- Deny: Red opacity 0.8 (#FF453A)

---

### **4. SentRequestCard Component**

**Visual Design:**
```
┌─────────────────────────────────────┐
│ [Avatar] Name              2d ago   │
│          @nickname                  │
│          WINS | LOSSES        [↶]   │
└─────────────────────────────────────┘
```

**Elements:**
- **PlayerCard** - Shows user avatar, name, nickname, stats
- **Withdraw Button** - Gray circle with back arrow icon
- **Time Label** - Top-right corner, relative time format

**Styling:**
- Background: InputBackground
- Corner radius: 12pt
- Padding: 16pt horizontal, 12pt vertical
- Button size: 44pt circle
- Withdraw: TextSecondary opacity 0.15

---

## 🎯 UI States

### **Received Requests Section**

**Loading State:**
- ProgressView centered
- AccentPrimary color
- 32pt vertical padding

**Empty State:**
- Tray icon (48pt, light weight)
- "No pending requests" text
- TextSecondary color
- 32pt vertical padding

**With Requests:**
- Scrollable list of ReceivedRequestCard
- 12pt spacing between cards
- 16pt horizontal padding

### **Sent Requests Section**

**Loading State:**
- ProgressView centered
- AccentPrimary color
- 32pt vertical padding

**Empty State:**
- Paperplane icon (48pt, light weight)
- "No pending requests" text
- TextSecondary color
- 32pt vertical padding

**With Requests:**
- Scrollable list of SentRequestCard
- 12pt spacing between cards
- 16pt horizontal padding

---

## 📅 Date Formatting

**RelativeDateTimeFormatter:**
```swift
var timeAgo: String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: createdAt, relativeTo: Date())
}
```

**Examples:**
- "2 minutes ago"
- "1 hour ago"
- "2 days ago"
- "1 week ago"
- "3 months ago"

---

## 🔄 Data Flow

### **Load Requests Flow:**

1. View appears → `onAppear` triggers
2. Validate user is signed in
3. Set `isLoading = true`
4. Load received and sent requests in parallel:
   ```swift
   async let received = friendsService.loadReceivedRequests(userId:)
   async let sent = friendsService.loadSentRequests(userId:)
   ```
5. Update state with results
6. Set `isLoading = false`

### **Refresh Flow (Pull-to-Refresh):**

1. User pulls down on ScrollView
2. `.refreshable` modifier triggers
3. Set `isRefreshing = true`
4. Load requests in parallel
5. Update state with results
6. Set `isRefreshing = false`
7. ScrollView automatically hides refresh indicator

---

## 🎬 User Interactions

### **Accept Request (Placeholder):**
```swift
private func acceptRequest(_ request: FriendRequest) {
    print("✅ Accept request from: \(request.user.displayName)")
    // TODO: Implement in Task 303
}
```

### **Deny Request (Placeholder):**
```swift
private func denyRequest(_ request: FriendRequest) {
    print("❌ Deny request from: \(request.user.displayName)")
    // TODO: Implement in Task 304
}
```

### **Withdraw Request (Placeholder):**
```swift
private func withdrawRequest(_ request: FriendRequest) {
    print("🔙 Withdraw request to: \(request.user.displayName)")
    // TODO: Implement in Task 305
}
```

**Note:** These methods are placeholders that will be fully implemented in Tasks 303-305.

---

## 🗄️ Database Queries

### **Load Received Requests:**
```sql
SELECT * FROM friendships
WHERE addressee_id = 'current-user-uuid'
  AND status = 'pending'
ORDER BY created_at DESC;
```

Then join with users table:
```sql
SELECT * FROM users
WHERE id IN (requester_ids);
```

### **Load Sent Requests:**
```sql
SELECT * FROM friendships
WHERE requester_id = 'current-user-uuid'
  AND status = 'pending'
ORDER BY created_at DESC;
```

Then join with users table:
```sql
SELECT * FROM users
WHERE id IN (addressee_ids);
```

---

## ✅ Features Implemented

### **Two Clear Sections:**
- ✅ "Received Requests" section with header
- ✅ "Sent Requests" section with header
- ✅ Visual divider between sections

### **All Pending Requests Displayed:**
- ✅ Loads from Supabase on view appear
- ✅ Parallel loading for performance
- ✅ Sorted by date (newest first)
- ✅ Displays user information via PlayerCard

### **Action Buttons Present and Styled:**
- ✅ Accept button (green checkmark)
- ✅ Deny button (red X)
- ✅ Withdraw button (gray back arrow)
- ✅ 44pt touch targets
- ✅ Circular design
- ✅ Color-coded for clarity

### **Empty States:**
- ✅ Received: Tray icon + "No pending requests"
- ✅ Sent: Paperplane icon + "No pending requests"
- ✅ Centered layout
- ✅ Proper spacing

### **Dates Formatted Nicely:**
- ✅ RelativeDateTimeFormatter
- ✅ "X time ago" format
- ✅ Positioned in top-right corner
- ✅ TextSecondary color
- ✅ 12pt font size

### **Additional Features:**
- ✅ Pull-to-refresh functionality
- ✅ Loading states with spinners
- ✅ Error handling
- ✅ Dark mode support
- ✅ Navigation with back button

---

## 📱 Navigation Integration

**Access from FriendsListView:**
```swift
// Add navigation button in FriendsListView
NavigationLink(destination: FriendRequestsView()) {
    HStack {
        Image(systemName: "bell.badge")
        Text("Requests")
        if requestCount > 0 {
            Text("\(requestCount)")
                .badge()
        }
    }
}
```

**Note:** Navigation integration will be added in Task 308.1

---

## 🎨 Design Consistency

**Follows DanDarts Design System:**
- ✅ Dark-first theme (BackgroundPrimary, InputBackground)
- ✅ SF Pro font family
- ✅ 44pt minimum touch targets
- ✅ 16pt/12pt/8pt spacing rhythm
- ✅ AccentPrimary for interactive elements
- ✅ TextPrimary/TextSecondary hierarchy
- ✅ 12pt corner radius for cards
- ✅ Consistent with PlayerCard component

---

## 📝 Code Examples

### **Using the View:**
```swift
// Present as sheet
.sheet(isPresented: $showRequests) {
    FriendRequestsView()
        .environmentObject(authService)
}

// Or navigate with NavigationLink
NavigationLink(destination: FriendRequestsView()) {
    Text("View Requests")
}
```

### **Loading Requests:**
```swift
let friendsService = FriendsService()

Task {
    // Load received requests
    let received = try await friendsService.loadReceivedRequests(
        userId: currentUser.id
    )
    
    // Load sent requests
    let sent = try await friendsService.loadSentRequests(
        userId: currentUser.id
    )
    
    print("Received: \(received.count)")
    print("Sent: \(sent.count)")
}
```

---

## 🚀 Next Steps

**Task 303: Implement Accept Friend Request**
- Update friendship status from 'pending' to 'accepted'
- Update both users' friends lists
- Remove from received requests UI
- Show success feedback
- Add haptic feedback

**Task 304: Implement Deny Friend Request**
- Delete friendship record from database
- Remove from received requests UI
- Show subtle feedback
- Add haptic feedback

**Task 305: Implement Withdraw Friend Request**
- Delete friendship record from database
- Remove from sent requests UI
- Show feedback
- Add haptic feedback

**Task 306-308: Block, Badge, Navigation**
- Block user functionality
- Badge indicators on Friends tab
- Navigation to requests view

---

## 📁 Files Created

1. **FriendRequestsView.swift**
   - Main view with two sections
   - ReceivedRequestCard component
   - SentRequestCard component
   - Pull-to-refresh
   - Empty states

2. **TASK_302_FRIEND_REQUESTS_VIEW.md**
   - Complete documentation

---

## 📁 Files Modified

1. **FriendsService.swift**
   - Added `loadReceivedRequests()` method
   - Added `loadSentRequests()` method
   - Added `FriendRequest` model
   - Added `RequestType` enum

---

## ✅ Acceptance Criteria Met

- ✅ **Two clear sections visible** - Received and Sent with headers
- ✅ **All pending requests displayed** - Loaded from Supabase, sorted by date
- ✅ **Action buttons present and styled** - Accept, Deny, Withdraw with proper colors
- ✅ **Empty states show when no requests** - Tray and paperplane icons
- ✅ **Dates formatted nicely** - "X time ago" format in top-right

---

## 🎉 Task 302 Complete

**Status:** Friend Requests View fully implemented and ready for testing

**Dependencies Satisfied:**
- Task 300: Database schema ✅
- Task 301: Send friend request ✅

**Ready for:** Task 303 - Implement Accept Friend Request

**Note:** Action button handlers are placeholders that will be implemented in Tasks 303-305.
