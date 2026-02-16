# Supabase Realtime Setup Guide for iOS/Swift

**Complete guide for implementing real-time database change notifications with Supabase Realtime V2 in Swift.**

This document covers the complete setup process, common pitfalls, and debugging steps based on real-world implementation of friend request notifications.

---

## Table of Contents

1. [Overview](#overview)
2. [Database Setup](#database-setup)
3. [Swift Client Setup](#swift-client-setup)
4. [Common Pitfalls & Solutions](#common-pitfalls--solutions)
5. [Debugging Checklist](#debugging-checklist)
6. [Testing](#testing)

---

## Overview

Supabase Realtime allows your Swift app to receive instant notifications when database rows are inserted, updated, or deleted. This is powered by PostgreSQL's replication system and WebSocket connections.

**Key Concepts:**
- **Realtime Channel**: A WebSocket connection to listen for events
- **postgres_changes**: Database change events (INSERT, UPDATE, DELETE)
- **Row Level Security (RLS)**: Controls which events users can receive
- **REPLICA IDENTITY**: Determines what data is included in change events

---

## Database Setup

### Step 1: Enable Realtime for Your Table

In Supabase Dashboard:
1. Go to **Database** → **Replication**
2. Find your table (e.g., `friendships`)
3. Toggle **Realtime** to **ON**

Or via SQL:
```sql
-- Add table to realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE friendships;
```

### Step 2: Set REPLICA IDENTITY FULL

This ensures that all column values are included in change events (required for filtering):

```sql
ALTER TABLE friendships REPLICA IDENTITY FULL;
```

**Why this matters:** Without `REPLICA IDENTITY FULL`, only the primary key is included in DELETE events, making it impossible to filter by other columns.

### Step 3: Configure Row Level Security (RLS)

**CRITICAL:** RLS policies control which realtime events are delivered to clients. If a user can't SELECT a row, they won't receive realtime events for it.

```sql
-- Enable RLS
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

-- SELECT policy (REQUIRED for Realtime delivery)
DROP POLICY IF EXISTS "friendships_select_self" ON public.friendships;
CREATE POLICY "friendships_select_self"
ON public.friendships
FOR SELECT
TO authenticated
USING (
  requester_id = auth.uid()
  OR addressee_id = auth.uid()
);

-- INSERT policy (who can create rows)
DROP POLICY IF EXISTS "friendships_insert_self" ON public.friendships;
CREATE POLICY "friendships_insert_self"
ON public.friendships
FOR INSERT
TO authenticated
WITH CHECK (
  requester_id = auth.uid()
);

-- UPDATE policy (who can modify rows)
DROP POLICY IF EXISTS "friendships_update_self" ON public.friendships;
CREATE POLICY "friendships_update_self"
ON public.friendships
FOR UPDATE
TO authenticated
USING (
  requester_id = auth.uid()
  OR addressee_id = auth.uid()
)
WITH CHECK (
  requester_id = auth.uid()
  OR addressee_id = auth.uid()
);

-- DELETE policy (who can delete rows)
DROP POLICY IF EXISTS "friendships_delete_self" ON public.friendships;
CREATE POLICY "friendships_delete_self"
ON public.friendships
FOR DELETE
TO authenticated
USING (
  requester_id = auth.uid()
  OR addressee_id = auth.uid()
);
```

### Step 4: Verify Database Configuration

Run these queries to confirm setup:

```sql
-- Check if table is in realtime publication
SELECT schemaname, tablename, rowfilter 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime' 
  AND tablename = 'friendships';
-- Expected: 1 row, rowfilter should be NULL

-- Check replica identity
SELECT relreplident 
FROM pg_class 
WHERE relname = 'friendships';
-- Expected: 'f' (FULL)

-- Check RLS is enabled
SELECT relrowsecurity
FROM pg_class
WHERE relname = 'friendships';
-- Expected: true

-- List RLS policies
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'friendships';
-- Expected: 4 policies (SELECT, INSERT, UPDATE, DELETE)
```

---

## Swift Client Setup

### Step 1: Create Service Class

```swift
import Foundation
import Supabase

@MainActor
class FriendsService: ObservableObject {
    private let supabaseService = SupabaseService.shared
    
    // CRITICAL: Retain channel and subscriptions to prevent deallocation
    private var realtimeChannel: RealtimeChannelV2?
    private var insertSubscription: RealtimeSubscription?
    private var updateSubscription: RealtimeSubscription?
    private var deleteSubscription: RealtimeSubscription?
    
    @Published var friendshipChanged: Bool = false
}
```

**Why retain subscriptions?** If you don't store the subscription tokens, Swift's ARC may deallocate the callback closures, causing events to be silently dropped.

### Step 2: Setup Realtime Subscription

```swift
func setupRealtimeSubscription(userId: UUID) async {
    print("🔵 [Realtime] Setting up subscription for user: \(userId)")
    
    // Remove existing subscription first
    await removeRealtimeSubscription()
    
    // Create channel with shared name (all users listen to same channel)
    let channelName = "public:friendships"
    let channel = supabaseService.client.realtimeV2.channel(channelName)
    
    // CRITICAL: Retain channel BEFORE subscribing
    realtimeChannel = channel
    
    // Register INSERT callback with client-side filtering
    insertSubscription = channel.onPostgresChange(
        InsertAction.self,
        schema: "public",
        table: "friendships"
        // NO server-side filter - use client-side filtering instead
    ) { [weak self] action in
        print("🚨 [Realtime] INSERT event received")
        
        // Client-side filter: only process if user is involved
        let record = action.record
        guard
            let requesterIdString = record["requester_id"]?.stringValue,
            let addresseeIdString = record["addressee_id"]?.stringValue,
            let requesterId = UUID(uuidString: requesterIdString),
            let addresseeId = UUID(uuidString: addresseeIdString),
            requesterId == userId || addresseeId == userId
        else {
            return
        }
        
        Task { @MainActor in
            self?.handleFriendshipInsert(action, userId: userId)
        }
    }
    
    // Register UPDATE callback
    updateSubscription = channel.onPostgresChange(
        UpdateAction.self,
        schema: "public",
        table: "friendships"
    ) { [weak self] action in
        // Same client-side filtering logic
        Task { @MainActor in
            self?.handleFriendshipUpdate(action, userId: userId)
        }
    }
    
    // Register DELETE callback
    deleteSubscription = channel.onPostgresChange(
        DeleteAction.self,
        schema: "public",
        table: "friendships"
    ) { [weak self] action in
        // Use action.oldRecord for DELETE events
        Task { @MainActor in
            self?.handleFriendshipDelete(action, userId: userId)
        }
    }
    
    // Subscribe to channel
    do {
        try await channel.subscribe()
        print("✅ [Realtime] Subscription active")
    } catch {
        print("❌ [Realtime] Subscription failed: \(error)")
    }
}

func removeRealtimeSubscription() async {
    if let channel = realtimeChannel {
        await channel.unsubscribe()
        realtimeChannel = nil
        insertSubscription = nil
        updateSubscription = nil
        deleteSubscription = nil
    }
}
```

### Step 3: Handle Events

```swift
private func handleFriendshipInsert(_ action: InsertAction, userId: UUID) {
    print("📝 [Handler] Processing INSERT event")
    
    // Update UI state
    friendshipChanged.toggle()
    
    // Post notification for badge updates
    NotificationCenter.default.post(
        name: NSNotification.Name("FriendRequestsChanged"), 
        object: nil
    )
    
    // Show toast notification
    Task {
        await showToastNotification(record: action.record, userId: userId)
    }
}

private func showToastNotification(record: [String: AnyJSON], userId: UUID) async {
    // CRITICAL: Compare UUIDs, not strings (avoid case-sensitivity issues)
    guard let addresseeIdString = record["addressee_id"]?.stringValue,
          let addresseeId = UUID(uuidString: addresseeIdString),
          addresseeId == userId else {
        return
    }
    
    // Fetch user data and show toast
    // ... implementation details
}
```

### Step 4: Integrate with App Lifecycle

```swift
struct MainTabView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var friendsService = FriendsService()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        TabView {
            // ... tabs
        }
        .onAppear {
            // Setup realtime on app launch
            if let userId = authService.currentUser?.id {
                Task {
                    await friendsService.setupRealtimeSubscription(userId: userId)
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Reconnect when returning to foreground
            if newPhase == .active && oldPhase == .background {
                if let userId = authService.currentUser?.id {
                    Task {
                        await friendsService.setupRealtimeSubscription(userId: userId)
                    }
                }
            }
        }
    }
}
```

---

## Common Pitfalls & Solutions

### 1. Callbacks Never Fire

**Symptom:** Subscription shows as "subscribed" but callbacks don't execute.

**Causes & Solutions:**

**A) RLS Blocking Events**
- **Problem:** User can't SELECT the row, so Realtime doesn't deliver the event
- **Solution:** Verify SELECT policy allows access for both requester and addressee
- **Test:** Run `SELECT * FROM friendships WHERE requester_id = auth.uid() OR addressee_id = auth.uid()`

**B) Subscriptions Not Retained**
- **Problem:** Callback closures are deallocated by ARC
- **Solution:** Store subscription tokens as properties: `private var insertSubscription: RealtimeSubscription?`

**C) Channel Deallocated**
- **Problem:** Channel is created in a function and not retained
- **Solution:** Store channel as property on long-lived object (e.g., `@StateObject` service)

### 2. Case-Sensitivity Issues

**Symptom:** UUID comparison fails even though values look identical.

**Problem:** Supabase returns lowercase UUIDs, Swift uses uppercase.

**Wrong:**
```swift
guard addresseeIdString == currentUserId.uuidString else { return }
// "22978663-6c1a-4d48-a717-ba5f18e9a1bb" != "22978663-6C1A-4D48-A717-BA5F18E9A1BB"
```

**Correct:**
```swift
guard let addresseeId = UUID(uuidString: addresseeIdString),
      addresseeId == currentUserId else { return }
// UUID comparison is case-insensitive
```

### 3. Server-Side Filters Don't Work

**Symptom:** Events don't fire when using `filter: "column=eq.value"`.

**Problem:** Supabase Realtime V2 server-side filters are unreliable in Swift SDK.

**Solution:** Use client-side filtering instead:

```swift
// ❌ Don't use server-side filters
channel.onPostgresChange(
    InsertAction.self,
    schema: "public",
    table: "friendships",
    filter: "addressee_id=eq.\(userId)"  // Unreliable
)

// ✅ Use client-side filtering
channel.onPostgresChange(
    InsertAction.self,
    schema: "public",
    table: "friendships"
) { action in
    guard let addresseeId = UUID(uuidString: action.record["addressee_id"]?.stringValue ?? ""),
          addresseeId == userId else { return }
    // Process event
}
```

### 4. Events Stop After Backgrounding

**Symptom:** Realtime works initially but stops after app goes to background.

**Problem:** iOS suspends WebSocket connections in background.

**Solution:** Reconnect when app returns to foreground:

```swift
.onChange(of: scenePhase) { oldPhase, newPhase in
    if newPhase == .active && oldPhase == .background {
        Task {
            await friendsService.setupRealtimeSubscription(userId: userId)
        }
    }
}
```

### 5. Multiple Instances of Service

**Symptom:** Some views receive events, others don't.

**Problem:** Creating new service instances instead of using shared one.

**Wrong:**
```swift
func acceptRequest() {
    let service = FriendsService()  // ❌ New instance, no realtime channel
    await service.acceptFriendRequest(id: requestId)
}
```

**Correct:**
```swift
@StateObject private var friendsService = FriendsService()  // ✅ Shared instance

func acceptRequest() {
    await friendsService.acceptFriendRequest(id: requestId)
}
```

---

## Debugging Checklist

When realtime events aren't working, check these in order:

### Database Configuration

- [ ] Table is in `supabase_realtime` publication
- [ ] `REPLICA IDENTITY` is set to `FULL`
- [ ] RLS is enabled on the table
- [ ] SELECT policy allows access for relevant users
- [ ] Test manual SELECT query with `auth.uid()` filter

### Swift Client

- [ ] Channel is stored as property on long-lived object
- [ ] Subscription tokens are retained
- [ ] Callbacks use `[weak self]` to avoid retain cycles
- [ ] Client-side filtering (not server-side)
- [ ] UUID comparison (not string comparison)
- [ ] Callbacks dispatch to `@MainActor` for UI updates

### Network & Lifecycle

- [ ] Subscription shows as "subscribed" in logs
- [ ] No WebSocket timeout errors
- [ ] Reconnect logic on app foreground
- [ ] Test with app in foreground (not background)

### Testing

- [ ] Add loud logs inside callback closures
- [ ] Test with SQL INSERT (bypasses app logic)
- [ ] Verify both users have updated builds
- [ ] Check console for callback execution logs

---

## Testing

### Test 1: SQL Insert (Bypass App Logic)

Run this in Supabase SQL Editor while app is running:

```sql
-- Insert test friend request
INSERT INTO friendships (requester_id, addressee_id, status, created_at)
VALUES (
  'sender-uuid'::uuid,
  'receiver-uuid'::uuid,
  'pending',
  now()
);
```

**Expected:** Callback logs appear in Xcode console within 1-2 seconds.

### Test 2: Real Friend Request

1. Build and install app on both devices
2. User A sends friend request to User B
3. User B should see:
   - Badge count updates immediately
   - Toast notification appears
   - Console shows callback logs

### Test 3: Background/Foreground

1. User A sends request while User B's app is in background
2. User B brings app to foreground
3. Expected: Reconnect logs appear, then catch-up toast shows

---

## Example Console Logs (Success)

```
🔵 [Realtime] Setting up subscription for user: 22978663-6C1A-4D48-A717-BA5F18E9A1BB
🔵 [Realtime] Creating channel: public:friendships
✅ [Realtime] Subscription active
✅ [Realtime] Channel status: subscribed

// When event arrives:
🚨 [Realtime] INSERT event received
📝 [Handler] Processing INSERT event
📝 [Handler] friendshipChanged toggled
📝 [Handler] Posted FriendRequestsChanged notification
✅ [Toast] Showing toast for: Christina Billingham
```

---

## Summary

**Key Success Factors:**

1. **Database:** RLS SELECT policy must allow access for both sides of relationship
2. **Swift:** Retain channel and subscription tokens on long-lived objects
3. **Filtering:** Use client-side filtering, not server-side
4. **Comparison:** Compare UUIDs, not strings
5. **Lifecycle:** Reconnect on app foreground

**Common Mistakes:**

- ❌ Forgetting to set `REPLICA IDENTITY FULL`
- ❌ RLS SELECT policy too restrictive
- ❌ Not retaining subscription tokens
- ❌ Using string comparison for UUIDs
- ❌ Relying on server-side filters

**Debugging Priority:**

1. Add logs inside callback closures (proves events arrive)
2. Test with SQL INSERT (bypasses app logic)
3. Verify RLS policies with manual SELECT query
4. Check subscription token retention

---

## Additional Resources

- [Supabase Realtime Docs](https://supabase.com/docs/guides/realtime)
- [Supabase Swift SDK](https://github.com/supabase/supabase-swift)
- [PostgreSQL Replication](https://www.postgresql.org/docs/current/logical-replication.html)

---

**Document Version:** 1.0  
**Last Updated:** February 15, 2026  
**Based on:** Friend Request Notification Implementation
