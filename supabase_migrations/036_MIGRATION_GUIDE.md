# Migration 036: Fix Realtime Notifications

## Problem
Realtime friend request notifications don't appear immediately. The `friendships` table has both old (`user_id`, `friend_id`) and new (`requester_id`, `addressee_id`) columns, causing realtime filter mismatches.

## Solution
Drop the old columns since Swift code exclusively uses the new ones.

---

## Pre-Migration Steps

### 1. Backup Your Data
Open Supabase Dashboard → SQL Editor and run:
```sql
-- Copy from: 036_backup_friendships.sql
SELECT 
    id,
    requester_id,
    addressee_id,
    user_id,
    friend_id,
    status,
    created_at,
    updated_at
FROM public.friendships
ORDER BY created_at DESC;
```
**Save the results** (copy to a text file or spreadsheet).

### 2. Note Current Row Count
In Supabase Dashboard → Database → Table Editor → friendships:
- Note the total number of rows (e.g., "5 rows")
- You'll verify this matches after migration

---

## Running the Migration

### Step 1: Run Migration Script
1. Open **Supabase Dashboard** → **SQL Editor**
2. Click **New Query**
3. Copy contents of `036_drop_old_friendship_columns.sql`
4. Paste and click **Run**

### Step 2: Check for Success Messages
You should see:
```
✅ Safety check passed: All rows have requester_id and addressee_id populated
📊 Current friendships count: X
✅ RLS policies updated to use only requester_id and addressee_id
✅ Old indexes dropped
✅ Old unique constraint dropped
✅ Old columns (user_id, friend_id) dropped
✅ Verified indexes on new columns
✅ Verified unique constraint on (requester_id, addressee_id)
📊 Final friendships count: X
✅ Migration 036 completed successfully!
🔔 Realtime subscriptions should now work with requester_id/addressee_id filters
```

### Step 3: Verify Row Count
- Initial count should match final count
- No data loss

---

## Testing Realtime Notifications

### 1. Prepare Test Environment
- **Device 1**: Your phone (connected to Xcode with console visible)
- **Device 2**: Christina's phone (latest build)

### 2. Run Test
1. **Your phone**: Keep app open (any tab)
2. **Christina's phone**: Send you a friend request
3. **Watch console** on your phone for:
   ```
   🔔 [Realtime] INSERT CALLBACK FIRED!
   📝 [Handler] handleFriendshipInsert CALLED
   📝 [Toast] Starting toast task...
   ```
4. **Verify**:
   - ✅ Toast notification appears immediately
   - ✅ Badge count updates on Friends tab
   - ✅ No need to exit/return to app

### 3. Success Criteria
- ✅ Realtime callback fires in console
- ✅ Toast appears within 1-2 seconds
- ✅ Badge updates immediately
- ✅ Request visible in Friends tab

---

## If Something Goes Wrong

### Rollback Process

1. Open **Supabase Dashboard** → **SQL Editor**
2. Copy contents of `036_rollback_friendship_columns.sql`
3. Paste and click **Run**
4. Verify success messages:
   ```
   ✅ Old columns (user_id, friend_id) restored
   ✅ Data copied from requester_id/addressee_id to user_id/friend_id
   ✅ Old indexes restored
   ✅ Old unique constraint restored
   ✅ RLS policies restored to support both old and new columns
   📊 Final friendships count: X
   ✅ Rollback completed successfully!
   ```

### After Rollback
- Your data is restored to previous state
- All friendships intact
- Realtime still won't work (same as before)
- No harm done - you can try alternative fixes

---

## What Changed

### Before Migration
```
friendships table:
- id
- user_id (OLD - not used by Swift)
- friend_id (OLD - not used by Swift)
- requester_id (NEW - used by Swift)
- addressee_id (NEW - used by Swift)
- status
- created_at
- updated_at
```

### After Migration
```
friendships table:
- id
- requester_id (used by Swift)
- addressee_id (used by Swift)
- status
- created_at
- updated_at
```

### Why This Fixes Realtime
- Swift code filters: `addressee_id=eq.YOUR_UUID`
- Old columns caused confusion/conflicts
- Clean schema = clean realtime broadcasts
- Supabase can now match filters correctly

---

## Files Created

1. **036_drop_old_friendship_columns.sql** - Main migration
2. **036_rollback_friendship_columns.sql** - Rollback script
3. **036_backup_friendships.sql** - Backup query
4. **036_MIGRATION_GUIDE.md** - This guide

---

## Support

If you encounter errors:
1. Copy the error message
2. Check if it's a safety check failure
3. Run rollback if needed
4. Share error with developer for investigation

**Remember**: This only affects the `friendships` table. No other tables are touched.
