# Database Migration Setup - Player Stats Fix

## Problem Summary
Player stats (`total_wins` and `total_losses`) are not updating because match saves are failing due to database schema mismatch.

## Root Cause
The Swift code expects a newer database schema with:
- New columns in `matches` table (`started_at`, `ended_at`, `game_id`, `metadata`)
- Two new tables (`match_players`, `match_throws`)

Your Supabase database has the old schema without these.

## Solution
Run the comprehensive migration to update your database schema.

---

## 🚀 How to Run the Migration

### Step 1: Open Supabase Dashboard
1. Go to https://supabase.com/dashboard
2. Select your DanDarts project
3. Click **SQL Editor** in the left sidebar

### Step 2: Run the Migration
1. Click **New Query**
2. Copy the entire contents of `supabase_migrations/011_complete_matches_schema_migration.sql`
3. Paste into the SQL editor
4. Click **Run** (or press Cmd+Enter)

### Step 3: Verify Success
You should see output like:
```
NOTICE: Complete matches schema migration successful!
NOTICE: Tables created: match_players, match_throws
NOTICE: Matches table updated with new columns
NOTICE: All indexes and RLS policies created
Success. No rows returned
```

---

## ✅ What This Migration Does

### 1. Updates `matches` Table
**Adds new columns:**
- `started_at` (TIMESTAMPTZ) - When match started
- `ended_at` (TIMESTAMPTZ) - When match ended
- `game_id` (TEXT) - Game type identifier
- `metadata` (JSONB) - Match metadata (legs, etc.)

**Makes old columns nullable:**
- `game_type`, `game_name`, `winner_id`, `duration`, `players`
- This ensures backward compatibility

**Migrates existing data:**
- Calculates `started_at` from `timestamp - duration`
- Copies `timestamp` to `ended_at`
- Copies `game_type` to `game_id`
- Sets empty metadata for old matches

### 2. Creates `match_players` Table
Stores player participation data:
- `match_id` - Links to matches table
- `player_user_id` - Links to users table (null for guests)
- `guest_name` - Guest player name (null for users)
- `player_order` - Player position (0, 1, 2, etc.)

**Constraints:**
- Each player must be either a user OR a guest (not both)
- Unique constraint on (match_id, player_order)

### 3. Creates `match_throws` Table
Stores individual turn/throw data:
- `match_id` - Links to matches table
- `player_order` - Which player threw
- `turn_index` - Turn number
- `throws` - Array of dart scores
- `score_before` - Score before turn
- `score_after` - Score after turn
- `game_metadata` - Game-specific data (e.g., Halve-It targets)

**Constraints:**
- Unique constraint on (match_id, player_order, turn_index)

### 4. Creates Indexes
Performance indexes on:
- `matches`: started_at, ended_at, game_id, metadata
- `match_players`: match_id, player_user_id
- `match_throws`: match_id, player_order

### 5. Sets Up RLS Policies
Row Level Security policies ensure:
- Users can only view their own matches
- Users can only view players/throws for their matches
- All authenticated users can insert new data

---

## 🧪 Testing After Migration

### Test 1: Play a Match
1. Build and run the app in Xcode
2. Sign in as your user
3. Play a 301 match against a friend or guest
4. Finish the match

### Test 2: Check Console Logs
You should see:
```
✅ Supabase connection test: SUCCESS
Player IDs in match:
  - Daniel Billingham: [UUID]
  - Diana Prince: [UUID]
🔍 Updating stats for 2 players. Winner ID: [UUID]
🔍 Player: Daniel Billingham, userId: [UUID], isGuest: false
✅ Updated stats for Daniel Billingham: 0W/1L (or 1W/0L)
🔍 Player: Diana Prince, userId: [UUID], isGuest: false
✅ Updated stats for Diana Prince: 1W/0L (or 0W/1L)
✅ Match saved successfully: [UUID]
```

### Test 3: Verify Database
1. Go to Supabase → Table Editor
2. Check `users` table - `total_wins` and `total_losses` should be updated!
3. Check `matches` table - New match should be there
4. Check `match_players` table - Should have 2 rows (one per player)
5. Check `match_throws` table - Should have all the turns

### Test 4: Check App UI
1. Sign out and sign back in
2. Your player card should show correct stats (e.g., "1W 0L")
3. Profile page should show games played and win rate

---

## 🔧 Troubleshooting

### If Migration Fails
**Error: "column already exists"**
- Some columns may already exist from previous attempts
- This is fine - the migration uses `IF NOT EXISTS` to handle this

**Error: "table already exists"**
- Tables may already exist from previous attempts
- This is fine - the migration uses `IF NOT EXISTS` to handle this

**Error: "relation does not exist"**
- Make sure you're running the migration in the correct Supabase project
- Check that the `matches` and `users` tables exist

### If Stats Still Don't Update
1. Check Xcode console for error messages
2. Verify the migration ran successfully (check for NOTICE messages)
3. Make sure you're signed in (not playing as a guest)
4. Try a clean build in Xcode (Product → Clean Build Folder)

---

## 📊 Schema Comparison

### Before Migration
```
matches:
├── id
├── game_type
├── game_name
├── winner_id
├── timestamp
├── duration
├── players (JSONB)
└── (synced_at, created_at, updated_at)
```

### After Migration
```
matches:
├── id
├── started_at ← NEW
├── ended_at ← NEW
├── game_id ← NEW
├── metadata ← NEW
├── game_type (nullable)
├── game_name (nullable)
├── winner_id (nullable)
├── timestamp
├── duration (nullable)
├── players (JSONB, nullable)
└── (synced_at, created_at, updated_at)

match_players: ← NEW TABLE
├── id
├── match_id
├── player_user_id
├── guest_name
├── player_order
└── created_at

match_throws: ← NEW TABLE
├── id
├── match_id
├── player_order
├── turn_index
├── throws (array)
├── score_before
├── score_after
├── game_metadata
└── created_at
```

---

## ✨ Expected Results

After running this migration and playing a match:

1. ✅ Match saves successfully to Supabase
2. ✅ Player stats update in `users` table
3. ✅ Match data stored in `matches` table
4. ✅ Player participation stored in `match_players` table
5. ✅ Turn-by-turn data stored in `match_throws` table
6. ✅ Your player card shows correct W/L stats
7. ✅ Match history displays properly
8. ✅ All future matches will save and update stats correctly

---

## 🎯 Next Steps

1. Run the migration in Supabase SQL Editor
2. Build and run the app in Xcode
3. Play a test match
4. Verify stats update correctly
5. Celebrate! 🎉

**Questions or issues?** Check the Xcode console logs for detailed error messages.
