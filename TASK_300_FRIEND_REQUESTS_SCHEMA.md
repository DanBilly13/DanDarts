# ✅ TASK 300 COMPLETED: Update Database Schema for Friend Requests

## 📋 Task Requirements (from task-list-8.md)

**Checklist:**
- ✅ Update `friendships` table in Supabase
- ✅ Change `status` field to enum: 'pending', 'accepted', 'blocked' (added to existing enum)
- ✅ Add `created_at` timestamp (already existed)
- ✅ Add `updated_at` timestamp with auto-update trigger
- ✅ Add `requester_id` field (who sent the request)
- ✅ Add `addressee_id` field (who received the request)
- ✅ Update RLS policies for pending requests
- ✅ Create index on status field (already existed)
- ✅ Create indexes on new fields (requester_id, addressee_id, updated_at)

**Acceptance Criteria:**
- ✅ Friendship table supports request states (pending, accepted, rejected, blocked)
- ✅ Can distinguish between requester and addressee
- ✅ RLS policies allow viewing own pending requests
- ✅ Timestamps track request lifecycle (created_at, updated_at)

**Dependencies:** Task 80, Task 81

---

## 🗄️ Database Schema Changes

### **New Columns Added:**

1. **`updated_at`** (TIMESTAMPTZ)
   - Auto-updates on every row modification
   - Trigger: `friendships_updated_at_trigger`
   - Default: `now()`

2. **`requester_id`** (UUID, NOT NULL)
   - References `users(id)` with CASCADE delete
   - User who initiated the friend request
   - Indexed for performance

3. **`addressee_id`** (UUID, NOT NULL)
   - References `users(id)` with CASCADE delete
   - User who received the friend request
   - Indexed for performance

### **Updated Status Enum:**

```sql
CHECK (status IN ('pending', 'accepted', 'rejected', 'blocked'))
```

- **pending**: Friend request awaiting response
- **accepted**: Users are friends
- **rejected**: Request was declined (deleted from DB)
- **blocked**: User has blocked the other user

### **New Indexes:**

- `friendships_requester_id_idx` - Fast lookups by requester
- `friendships_addressee_id_idx` - Fast lookups by addressee
- `friendships_updated_at_idx` - Sorting by update time
- `friendships_requester_addressee_unique` - Prevents duplicate requests

---

## 🔒 Updated RLS Policies

### **SELECT Policy:**
Users can view friendships where they are:
- Requester OR Addressee OR User OR Friend

### **INSERT Policy:**
Users can create friendships where they are the requester
- Ensures users can only send requests as themselves

### **UPDATE Policy:**
Users can update friendships where they are requester OR addressee
- Requester can withdraw requests
- Addressee can accept/reject requests

### **DELETE Policy:**
Users can delete friendships where they are requester OR addressee
- Both parties can remove the friendship

---

## 📊 Data Migration

Existing friendships are automatically migrated:
- `requester_id` = `user_id`
- `addressee_id` = `friend_id`
- `updated_at` = `created_at`

This preserves all existing friend relationships while adding request tracking.

---

## 🚀 Setup Instructions

### **1. Run the Migration:**

Execute the SQL migration in Supabase:

```bash
# In Supabase Dashboard:
# 1. Go to SQL Editor
# 2. Open: supabase_migrations/005_update_friendships_for_requests.sql
# 3. Click "Run"
```

Or via Supabase CLI:

```bash
supabase db push
```

### **2. Verify Migration:**

Check that the table has all required columns:

```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'friendships'
ORDER BY ordinal_position;
```

Expected columns:
- id (uuid)
- user_id (uuid) - legacy, can be deprecated
- friend_id (uuid) - legacy, can be deprecated
- status (text)
- created_at (timestamptz)
- updated_at (timestamptz) ✨ NEW
- requester_id (uuid) ✨ NEW
- addressee_id (uuid) ✨ NEW

### **3. Test with Sample Data:**

```sql
-- Create a pending friend request
INSERT INTO friendships (requester_id, addressee_id, status)
VALUES (
    'user-1-uuid',
    'user-2-uuid',
    'pending'
);

-- Accept the request
UPDATE friendships
SET status = 'accepted'
WHERE requester_id = 'user-1-uuid' 
  AND addressee_id = 'user-2-uuid';

-- Check updated_at was auto-updated
SELECT created_at, updated_at, status
FROM friendships
WHERE requester_id = 'user-1-uuid';
```

---

## 🔄 Friend Request Workflow

### **Send Request:**
```sql
INSERT INTO friendships (requester_id, addressee_id, status)
VALUES (current_user_id, friend_user_id, 'pending');
```

### **Accept Request:**
```sql
UPDATE friendships
SET status = 'accepted'
WHERE id = request_id;
```

### **Reject Request:**
```sql
DELETE FROM friendships
WHERE id = request_id;
```

### **Block User:**
```sql
-- If friendship exists, update status
UPDATE friendships
SET status = 'blocked'
WHERE (requester_id = current_user_id AND addressee_id = blocked_user_id)
   OR (requester_id = blocked_user_id AND addressee_id = current_user_id);

-- If no friendship exists, create block record
INSERT INTO friendships (requester_id, addressee_id, status)
VALUES (current_user_id, blocked_user_id, 'blocked');
```

---

## 📝 Notes

### **Legacy Columns:**
The `user_id` and `friend_id` columns are maintained for backward compatibility with existing code. They can be deprecated in a future migration once all code is updated to use `requester_id` and `addressee_id`.

### **Unique Constraint:**
The unique index on `(requester_id, addressee_id)` prevents duplicate requests in the same direction. If User A sends a request to User B, they cannot send another until the first is resolved.

### **Auto-Update Trigger:**
The `updated_at` column automatically updates whenever any field in the row changes, providing accurate tracking of request lifecycle.

---

## ✅ Task 300 Complete

**Status:** Database schema ready for friend request system

**Next Tasks:**
- Task 301: Implement Send Friend Request
- Task 302: Create Friend Requests View
- Task 303: Implement Accept Friend Request
- Task 304: Implement Deny Friend Request
- Task 305: Implement Withdraw Friend Request
- Task 306: Implement Block User
- Task 307: Create Block List Management
- Task 308: Add Friend Request Badge Indicators

**Files Created:**
- `/supabase_migrations/005_update_friendships_for_requests.sql`
- `/TASK_300_FRIEND_REQUESTS_SCHEMA.md`
