# Fix: Friend Request Realtime Notifications Not Working

## Problem Identified

**Root Cause:** Supabase Realtime callbacks are not firing when friend requests are sent.

### Diagnostic Evidence

From console logs:
```
✅ [Realtime] SUBSCRIPTION ACTIVE
✅ [Realtime] Channel status: subscribed
```

But when Christina sends a friend request:
```
❌ No "🔔 INSERT CALLBACK FIRED!" log appears
❌ No notification posted
❌ No badge update
```

**The subscription is active, but callbacks never fire.**

## Root Cause

The `friendships` table is missing **REPLICA IDENTITY FULL**, which is required for Supabase Realtime to:
1. Send complete row data in realtime events
2. Properly trigger INSERT/UPDATE/DELETE callbacks
3. Work with Row Level Security (RLS) policies

Without `REPLICA IDENTITY FULL`, Realtime can't determine what data to send in the callback, so it doesn't trigger at all.

## Solution

Run migration `055_enable_realtime_for_friendships.sql` to:
1. Set `REPLICA IDENTITY FULL` on friendships table
2. Add friendships table to `supabase_realtime` publication

## How to Apply the Fix

### Step 1: Run the Migration in Supabase

1. Open **Supabase Dashboard** → Your Project
2. Go to **SQL Editor**
3. Open the file: `supabase_migrations/055_enable_realtime_for_friendships.sql`
4. Copy the entire contents
5. Paste into SQL Editor
6. Click **Run**

You should see:
```
✅ Realtime enabled for friendships table with REPLICA IDENTITY FULL
✅ Friendships table added to supabase_realtime publication
```

### Step 2: Verify Realtime is Enabled in Dashboard

1. In Supabase Dashboard → **Database** → **Replication**
2. Find `supabase_realtime` publication
3. Verify `friendships` table is listed
4. If not listed, toggle it ON

### Step 3: Test the Fix

1. **Device A** (your phone): 
   - Build and run the app
   - Sign in
   - Stay on Games tab
   - Watch Xcode console

2. **Device B** (Christina's phone):
   - Send a friend request to Device A

3. **Expected Console Output:**
```
🔔 [Realtime] ========================================
🔔 [Realtime] INSERT CALLBACK FIRED!
🔔 [Realtime] Filter: addressee_id=eq.22978663-6C1A-4D48-A717-BA5F18E9A1BB
🔔 [Realtime] Record: [record data]
🔔 [Realtime] ========================================
🔔 [Realtime] Calling handleFriendshipInsert on MainActor
📝 [Handler] handleFriendshipInsert CALLED
📝 [Handler] Posted FriendRequestsChanged notification
🎯 [MainTabView] Received FriendRequestsChanged notification
🎯 [MainTabView] Query returned count: 1
✅ [MainTabView] Badge count updated successfully
🎯 [ToastManager] showToast called
```

4. **Verify:**
   - ✅ Badge appears on Friends tab immediately
   - ✅ Toast notification appears immediately
   - ✅ No need to exit and return to app

## Why This Fixes It

### Before (Broken):
```
Christina sends request → Supabase inserts row → Realtime sees change
→ ❌ No REPLICA IDENTITY → Can't determine what to send
→ ❌ Callback never fires → No notification → No badge
```

### After (Fixed):
```
Christina sends request → Supabase inserts row → Realtime sees change
→ ✅ REPLICA IDENTITY FULL → Knows to send complete row
→ ✅ Callback fires with full data → Notification posted → Badge updates
```

## Technical Details

### What is REPLICA IDENTITY?

PostgreSQL setting that determines what information is logged for replication:
- **DEFAULT**: Only primary key (not enough for Realtime)
- **FULL**: Complete row data (required for Realtime with RLS)

### Why Realtime Needs REPLICA IDENTITY FULL

1. **RLS Policies**: Realtime needs full row data to evaluate RLS policies
2. **Callback Data**: Callbacks need complete row to show user info
3. **Filter Matching**: Realtime needs all columns to match filters like `addressee_id=eq.UUID`

### Supabase Realtime Publication

The `supabase_realtime` publication is a PostgreSQL logical replication publication that:
- Broadcasts changes to subscribed clients
- Respects RLS policies
- Requires tables to be explicitly added

## Alternative: Enable via Supabase Dashboard

If the SQL migration doesn't work, you can enable it manually:

1. **Supabase Dashboard** → **Database** → **Tables**
2. Find `friendships` table
3. Click the **⋮** menu → **Edit Table**
4. Under **Realtime** section:
   - Toggle **Enable Realtime** to ON
   - Set **Replica Identity** to **FULL**
5. Click **Save**

## Files Modified

- `supabase_migrations/055_enable_realtime_for_friendships.sql` - New migration
- `DIAGNOSTIC_TEST_INSTRUCTIONS.md` - Test instructions (already created)
- `MainTabView.swift` - Enhanced logging (already added)

## Cleanup After Fix

Once confirmed working, you can optionally remove the diagnostic logs from `MainTabView.swift` (lines 128-132 and 180-205) to reduce console noise.

## Related Documentation

- [Supabase Realtime Documentation](https://supabase.com/docs/guides/realtime)
- [PostgreSQL REPLICA IDENTITY](https://www.postgresql.org/docs/current/sql-altertable.html#SQL-ALTERTABLE-REPLICA-IDENTITY)
- [Supabase Realtime with RLS](https://supabase.com/docs/guides/realtime/postgres-changes#replication-setup)
