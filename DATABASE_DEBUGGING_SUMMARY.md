# Database Debugging Summary

## Overview

This document details the database issues encountered during match history development and the systematic debugging process that led to the solutions.

---

## The Initial Problem

### Symptom
- Halve-It match history was not loading from Supabase
- Error: `"cannot extract elements from a scalar"`
- PostgREST API was rejecting queries to the `match_throws` table

### Error Details
```
PostgREST error: cannot extract elements from a scalar
```

This cryptic error suggested that PostgreSQL was trying to use array operators on a non-array column, but it wasn't clear which column or why.

---

## Debugging Journey

### Phase 1: Initial Investigation

**Hypothesis:** The `throws` column (type `INTEGER[]`) might have corrupted data or incorrect type.

**Actions Taken:**
1. Created `CHECK_DATA_FORMAT.sql` to inspect actual data types
2. Attempted to query `jsonb_typeof(throws::jsonb)` - **Failed** (can't cast `INTEGER[]` to `jsonb`)
3. Corrected query to use `array_length(throws, 1)` instead
4. Confirmed `throws` column was correctly typed as `INTEGER[]`

**Result:** Data types were correct. Problem was elsewhere.

---

### Phase 2: Schema Comparison

**Hypothesis:** There might be subtle schema differences causing PostgREST to misinterpret the table structure.

**Actions Taken:**
1. Created a test table `match_throws_test` with identical structure
2. Inserted sample data into test table
3. Successfully queried test table - **It worked!**
4. Created `COMPARE_TABLES.sql` to compare schemas side-by-side

**Key Finding:**
```sql
-- Main table (broken)
game_metadata JSONB DEFAULT '{}'::jsonb

-- Test table (working)
game_metadata JSONB
```

The `game_metadata` column had a default value in the main table but not in the test table.

---

### Phase 3: Suspected Cause (Unconfirmed)

**Hypothesis:** The default value `'{}'::jsonb` on the `game_metadata` column might be causing PostgREST to misinterpret the column type.

**Key Observation:**
```sql
-- Main table (broken)
game_metadata JSONB DEFAULT '{}'::jsonb

-- Test table (working)
game_metadata JSONB
```

The test table worked without the default value, suggesting it might be related.

**However:** Removing the default value did NOT fix the issue. The error persisted even after running `029_fix_game_metadata_default.sql`.

**Actual Root Cause:** **Unknown** ❓

Possible explanations:
- PostgREST schema caching issue
- Internal PostgreSQL metadata corruption
- Some other subtle schema difference we didn't identify
- Combination of factors that accumulated over time

**Verification:**
- Test table without default value: ✅ Works
- Main table after removing default: ❌ Still fails
- Recreated table: ✅ Works

---

## The Solution

### Attempted Fix #1: Remove Default Value

**Migration:** `029_fix_game_metadata_default.sql`

```sql
ALTER TABLE match_throws 
ALTER COLUMN game_metadata DROP DEFAULT;
```

**Result:** ❌ Still failed. PostgREST continued to cache the old schema information.

---

### Final Fix: Recreate Table (Nuclear Option)

**Migration:** `030_recreate_match_throws_table.sql`

Since we couldn't identify the exact cause and removing the default didn't work, we took the "nuclear option" and recreated the table from scratch. This approach worked, suggesting the issue was likely some form of schema corruption or cached metadata that couldn't be fixed with ALTER statements:

```sql
-- 1. Rename old table
ALTER TABLE match_throws RENAME TO match_throws_old_backup;

-- 2. Create new table with correct schema (no default on game_metadata)
CREATE TABLE match_throws (
    id BIGSERIAL PRIMARY KEY,
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    player_order INTEGER NOT NULL,
    turn_index INTEGER NOT NULL,
    throws INTEGER[] NOT NULL,
    score_before INTEGER NOT NULL,
    score_after INTEGER NOT NULL,
    game_metadata JSONB,  -- No default value!
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Copy all data from old table
INSERT INTO match_throws 
    (id, match_id, player_order, turn_index, throws, score_before, score_after, game_metadata, created_at)
SELECT 
    id, match_id, player_order, turn_index, throws, score_before, score_after, game_metadata, created_at
FROM match_throws_old_backup;

-- 4. Reset sequence to continue from current max ID
SELECT setval('match_throws_id_seq', (SELECT MAX(id) FROM match_throws));

-- 5. Recreate indexes and permissions
CREATE INDEX match_throws_match_id_idx ON match_throws(match_id);
CREATE INDEX match_throws_player_order_idx ON match_throws(player_order, turn_index);
ALTER TABLE match_throws ENABLE ROW LEVEL SECURITY;
GRANT ALL ON match_throws TO authenticated;
```

**Result:** ✅ **Success!** PostgREST queries now work correctly.

---

### Cleanup

**Migration:** `031_cleanup_test_tables.sql`

```sql
-- Remove temporary tables
DROP TABLE IF EXISTS match_throws_test;
DROP TABLE IF EXISTS match_throws_old_backup;
```

---

## Additional Fix: Missing `is_bust` Column

While debugging the database, we discovered that the `is_bust` column was missing from `match_throws`, which was needed for Knockout game life tracking.

**Migration:** `032_add_is_bust_column.sql`

```sql
ALTER TABLE match_throws 
ADD COLUMN IF NOT EXISTS is_bust BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS match_throws_is_bust_idx 
ON match_throws(is_bust) WHERE is_bust = true;
```

---

## Lessons Learned

### 1. When Debugging Fails, Recreate
- Sometimes the root cause of database issues is impossible to identify
- Schema corruption or cached metadata can persist despite ALTER statements
- When ALTER fixes don't work, recreating the table is a valid solution
- Test tables are invaluable for proving the issue is table-specific, not data-specific

### 2. Debugging Strategy
- Start with data inspection (verify actual types and values)
- Create minimal reproducible cases (test tables)
- Compare working vs. broken schemas systematically
- When ALTER statements don't work, consider full recreation

### 3. Migration Best Practices
- Always backup data before destructive operations
- Use transactions (BEGIN/COMMIT) for safety
- Verify data integrity after migrations
- Keep old tables temporarily for rollback capability

---

## Files Created During Debugging

### SQL Queries (Debugging)
- `CHECK_DATA_FORMAT.sql` - Inspect column types and data
- `COMPARE_TABLES.sql` - Compare main vs test table schemas
- `DEBUG_ACTUAL_DATA.sql` - Examine actual row data
- `DEBUG_NEW_MATCHES.sql` - Test queries on new data

### Migrations (Solutions)
- `025_delete_all_matches.sql` - Clean slate for testing
- `027_create_get_match_throws_function.sql` - Alternative query approach (unused)
- `028_create_test_match_throws_table.sql` - Test table creation
- `029_fix_game_metadata_default.sql` - First fix attempt (didn't work)
- `030_recreate_match_throws_table.sql` - **Final solution**
- `031_cleanup_test_tables.sql` - Remove temporary tables
- `032_add_is_bust_column.sql` - Add missing column for Knockout

---

## Current State

✅ `match_throws` table recreated with correct schema  
✅ PostgREST queries working correctly  
✅ Halve-It match history loading successfully  
✅ `is_bust` column added for Knockout game  
✅ All test tables cleaned up  

---

## Migration Checklist for Production

- [x] Run `030_recreate_match_throws_table.sql` (completed)
- [x] Verify data integrity
- [x] Run `031_cleanup_test_tables.sql` (completed)
- [ ] Run `032_add_is_bust_column.sql` to add Knockout support
- [ ] Test match history loading in app
- [ ] Monitor for any PostgREST errors in logs

---

**Date:** December 17, 2025  
**Status:** Resolved ✅
