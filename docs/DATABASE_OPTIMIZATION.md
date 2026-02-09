# Database Optimization: Friend Profile Performance

## Overview

This document describes the database optimization work completed on **February 9, 2026** to improve the performance of the Friend Profile view's head-to-head match statistics.

### Problem Statement

The Friend Profile view was experiencing severe performance issues when loading head-to-head match statistics:
- **Loading time:** 24+ seconds for 30 matches
- **Root cause:** N+1 query problem (186 individual database queries for turn data)
- **User impact:** "Painfully slow" loading, poor user experience

### Solution Summary

Implemented a denormalized `match_participants` table with optimized queries:
- **New loading time:** ~1 second for 30+ matches
- **Performance improvement:** 24x faster (96% reduction in load time)
- **Scalability:** Query time remains constant regardless of total matches in database

---

## Database Schema Changes

### New Table: `match_participants`

A denormalized lookup table for fast participant-based queries.

```sql
CREATE TABLE public.match_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    is_guest BOOLEAN NOT NULL DEFAULT false,
    display_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### Indexes

```sql
-- Primary lookup: find matches by user
CREATE INDEX idx_match_participants_user_id 
    ON public.match_participants(user_id) 
    WHERE is_guest = false;

-- Reverse lookup: find participants by match
CREATE INDEX idx_match_participants_match_id 
    ON public.match_participants(match_id);

-- Composite index for head-to-head queries
CREATE INDEX idx_match_participants_user_match 
    ON public.match_participants(user_id, match_id) 
    WHERE is_guest = false;
```

#### Row Level Security (RLS)

```sql
-- Allow all authenticated users to query the table
CREATE POLICY "Authenticated users can view all match participants"
    ON public.match_participants
    FOR SELECT
    TO authenticated
    USING (true);

-- Allow authenticated users to insert (for new matches)
CREATE POLICY "Authenticated users can insert match participants"
    ON public.match_participants
    FOR INSERT
    TO authenticated
    WITH CHECK (true);
```

**Note:** RLS is intentionally permissive because `match_participants` only contains lookup data (match_id, user_id, display_name). Actual match data security is enforced by RLS on the `matches` table.

---

## Migration Files

### Migration 042: Create Table
**File:** `supabase_migrations/042_create_match_participants_table.sql`

**Purpose:** Creates the `match_participants` table schema, indexes, and RLS policies.

**Key Features:**
- Foreign key constraint to `matches` table with CASCADE delete
- Three indexes for different query patterns
- RLS policies for authenticated users
- Grants and documentation

**Run:** Copy entire file contents and execute in Supabase SQL Editor.

---

### Migration 043: Populate Data
**File:** `supabase_migrations/043_populate_match_participants_v2.sql`

**Purpose:** Backfills `match_participants` table with data from existing matches.

**Key Features:**
- Handles double-encoded JSON in `matches.players` column
- Extracts player data using `jsonb_array_elements`
- Includes verification step (counts and samples)
- Includes rollback script

**Important:** This migration handles a data quirk where the `players` column contains double-encoded JSON strings. The migration casts the data correctly:
```sql
jsonb_array_elements(
    CASE 
        WHEN jsonb_typeof(m.players) = 'string' 
        THEN (m.players #>> '{}')::jsonb
        ELSE m.players
    END
) AS player
```

**Run:** Copy entire file contents and execute in Supabase SQL Editor.

---

### Migration 046: Fix RLS Policy
**File:** `supabase_migrations/046_disable_match_participants_rls.sql`

**Purpose:** Fixes infinite recursion error in RLS policy.

**Problem:** Initial RLS policies tried to check `match_participants` within the policy for `match_participants`, causing infinite recursion.

**Solution:** Simplified policy to allow all authenticated users to query the table:
```sql
CREATE POLICY "Authenticated users can view all match participants"
    ON public.match_participants
    FOR SELECT
    TO authenticated
    USING (true);
```

**Run:** Copy entire file contents and execute in Supabase SQL Editor.

---

## Code Changes

### 1. MatchesService.swift

#### New Method: `loadHeadToHeadMatchesOptimized()`
```swift
func loadHeadToHeadMatchesOptimized(userId: UUID, friendId: UUID, limit: Int = 50) async throws -> [MatchResult]
```

**Query Flow:**
1. Query `match_participants` to find match IDs where both users participated (server-side filtering)
2. Load match metadata for those specific match IDs (without `players` column)
3. Load participants from `match_participants` table
4. Batch-load ALL turn data in ONE query using `IN` clause
5. Combine data into `MatchResult` objects

**Key Optimization:** Server-side filtering using indexed `match_participants` table instead of loading all matches and filtering client-side.

#### New Method: `loadMatchesByIds()`
```swift
private func loadMatchesByIds(_ matchIds: [UUID]) async throws -> [MatchResult]
```

**Purpose:** Efficiently loads specific matches by ID with batched turn data.

**Key Features:**
- Excludes problematic `players` JSONB column from query
- Reconstructs player data from `match_participants` table
- Batch-loads turn data (1 query instead of N queries)

#### New Method: `insertMatchParticipants()`
```swift
private func insertMatchParticipants(matchId: UUID, players: [MatchPlayer]) async throws
```

**Purpose:** Populates `match_participants` table when syncing a match.

**Called by:** `syncMatch()` method after successfully inserting match record.

---

### 2. MatchService.swift

#### Updated Method: `saveMatch()`

**Change:** Added call to `insertMatchParticipants()` after match insert:
```swift
// Insert match record
try await supabaseService.client
    .from("matches")
    .insert(matchRecord)
    .execute()

// Insert into match_participants table for fast queries
try await insertMatchParticipants(matchId: matchId, players: playersToSave)
```

#### New Method: `insertMatchParticipants()`
```swift
private func insertMatchParticipants(matchId: UUID, players: [Player]) async throws
```

**Purpose:** Same as MatchesService version but works with `Player` objects instead of `MatchPlayer`.

**Key Feature:** Deletes old participants before inserting (handles re-saves).

---

### 3. FriendProfileView.swift

#### Updated Method: `loadHeadToHeadMatches()`

**Before:**
```swift
let supabaseMatches = try await matchesService.loadMatches(userId: userId)
let filteredMatches = supabaseMatches.filter { /* client-side filtering */ }
```

**After:**
```swift
let matches = try await matchesService.loadHeadToHeadMatchesOptimized(
    userId: userId,
    friendId: friendUserId,
    limit: 50
)
```

**Change:** Uses new optimized query method that performs server-side filtering.

---

## Architecture

### Query Flow Comparison

#### Before (Slow)
```
1. Load ALL matches for user (includes players JSONB)
2. For each match (N times):
   - Query match_throws for turn data
3. Filter matches client-side for head-to-head
```
**Result:** 1 + N queries, client-side filtering, slow

#### After (Fast)
```
1. Query match_participants for match IDs (server-side filter)
2. Load specific matches by ID (without players column)
3. Load participants from match_participants
4. Batch-load ALL turns in ONE query
5. Combine data
```
**Result:** 4 queries total, server-side filtering, fast

---

## Performance Metrics

### Before Optimization
- **Load time:** 24+ seconds
- **Queries executed:** 187 (1 match query + 186 turn queries)
- **Data transferred:** Large (all matches + individual turn queries)
- **Scalability:** O(N) - gets slower as total matches increase

### After Optimization
- **Load time:** ~1 second
- **Queries executed:** 4 (participants, matches, participants data, turns batch)
- **Data transferred:** Small (only relevant matches)
- **Scalability:** O(1) - constant time regardless of total matches

### Test Results
- **Army (30 matches):** 1.09s → 0.93s
- **BoseBose (22 matches):** 1.01s
- **Tony Blair (2 matches):** 0.97s

**Improvement:** 24x faster (96% reduction in load time)

---

## Troubleshooting

### Issue: "cannot extract elements from a scalar"

**Cause:** The `players` column in `matches` table contains double-encoded JSON.

**Solution:** Migration 043 handles this by casting the data correctly. If you see this error:
1. Verify migration 043 was run successfully
2. Check that queries exclude the `players` column
3. Use `match_participants` table for player data instead

---

### Issue: "infinite recursion detected in policy"

**Cause:** RLS policy on `match_participants` references itself.

**Solution:** Run migration 046 to simplify the RLS policy.

---

### Issue: New matches don't appear in friend profile

**Cause:** `insertMatchParticipants()` not being called when saving matches.

**Solution:** 
1. Verify `MatchService.saveMatch()` calls `insertMatchParticipants()`
2. Check logs for `🔵 [Participants] Inserting...` message
3. Verify RLS policies allow INSERT on `match_participants`

---

## Rollback Instructions

### To Rollback Migration 046 (RLS Policy)
```sql
BEGIN;
DROP POLICY IF EXISTS "Authenticated users can view all match participants" ON public.match_participants;
DROP POLICY IF EXISTS "Authenticated users can insert match participants" ON public.match_participants;
-- Add back restrictive policy if needed
COMMIT;
```

### To Rollback Migration 043 (Data Population)
```sql
BEGIN;
DELETE FROM public.match_participants;
COMMIT;
```

### To Rollback Migration 042 (Table Creation)
```sql
BEGIN;
DROP TABLE IF EXISTS public.match_participants CASCADE;
COMMIT;
```

**Warning:** Dropping `match_participants` will break the optimized queries. You'll need to revert code changes as well.

---

## Future Considerations

### Potential Enhancements
1. **Add more indexes** if new query patterns emerge
2. **Add player stats** to `match_participants` (e.g., score, darts thrown)
3. **Add game type** to enable game-specific filtering
4. **Add timestamp** to enable time-based queries

### Maintenance
- **Data Consistency:** The `insertMatchParticipants()` method ensures new matches populate the table automatically
- **Backfills:** If data gets out of sync, re-run migration 043 to repopulate
- **Monitoring:** Watch for slow queries using Supabase dashboard

---

## Summary

This optimization demonstrates the power of denormalization for read-heavy workloads:
- **24x performance improvement** with minimal code changes
- **Scalable architecture** that handles growth gracefully
- **Automatic maintenance** through insert hooks
- **Backward compatible** - existing queries still work

The `match_participants` table is a classic denormalization pattern: duplicate data in a specialized structure optimized for specific query patterns, while maintaining the source of truth in the original `matches` table.

---

**Last Updated:** February 9, 2026  
**Author:** Cascade AI Assistant  
**Status:** Production Ready ✅
