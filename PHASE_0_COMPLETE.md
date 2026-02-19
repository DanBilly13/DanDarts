# Remote Matches - Phase 0 Complete ✅

**Date:** 2026-02-19  
**Branch:** `remote-matches`  
**Status:** Ready for Phase 1 Implementation

---

## Summary

Phase 0 (Foundation/Design Lock) is complete. All design decisions have been finalized and the database schema is ready for deployment.

---

## Completed Deliverables

### 1. Database Migration ✅

**File:** `supabase_migrations/047_remote_matches_schema.sql`

**Changes:**
- Extended `matches` table with remote-specific columns
- Created `remote_match_status` enum (7 states)
- Created `remote_match_locks` table (race-condition prevention)
- Created `user_push_tokens` table (APNs/FCM support)
- Added indexes for remote match queries
- Updated RLS policies for remote match visibility

**Tables Modified:**
- `matches` - Added 8 new columns for remote matches

**Tables Created:**
- `remote_match_locks` - Prevents multiple active matches per user
- `user_push_tokens` - Stores device tokens for push notifications

**Reused Tables (No Changes):**
- `match_players` - Player participation
- `match_throws` - Turn-by-turn visit log
- `match_participants` - Denormalized queries

### 2. Swift Models ✅

**File:** `DanDart/Models/RemoteMatch.swift`

**Models Created:**
- `RemoteMatchStatus` enum - 7 states with display names
- `RemoteMatch` - Main remote match model
- `LastVisitPayload` - Visit data for reveal animation
- `RemoteMatchLock` - Lock table model
- `PushToken` - Push notification token model
- `RemoteMatchWithPlayers` - Match with user data
- `RemoteMatchError` - Error handling

**Features:**
- Codable conformance for Supabase
- Computed properties (isExpired, timeRemaining, etc.)
- Player role tracking (Challenger = Red, Receiver = Green)
- Mock data for testing

### 3. Service Layer ✅

**File:** `DanDart/Services/RemoteMatchService.swift`

**Methods Implemented:**
- `loadMatches(userId:)` - Load all remote matches
- `createChallenge()` - Create new challenge
- `acceptChallenge()` - Accept challenge with lock enforcement
- `cancelMatch()` - Cancel match and clear locks
- `joinMatch()` - Join ready match
- `setupRealtimeSubscription()` - Subscribe to match updates
- Lock management (create, clear, check)

**Features:**
- Server-authoritative validation
- Lock enforcement (prevents multiple active matches)
- Realtime subscription support
- Error handling with typed errors

---

## Design Decisions Locked

### 1. Database Schema ✅
- **Reuse existing matches table** with `match_mode` column
- Add remote-specific columns (nullable for local matches)
- Use `remote_match_status` enum for type safety
- Reuse `match_throws` table for visit log (guarantees same Match Detail view)

### 2. Enforcement Strategy ✅
- **Both** Edge Function checks + DB lock table
- `remote_match_locks` table prevents race conditions
- User-friendly error messages via service layer

### 3. Push Notifications ✅
- **Direct APNs** (iOS-only, no Firebase dependency)
- Supabase Edge Functions trigger push
- `user_push_tokens` table for token storage
- 2 events: Challenge Received, Match Ready

### 4. Expiration ✅
- **Server-side pg_cron** job (every 1 minute)
- Challenge expiry: 24 hours
- Join window: 5 minutes
- Clears locks automatically

### 5. UI Adaptations ✅
- Minimal game rules (reuse existing block)
- No opponent stats in picker (v1)

---

## Configuration Constants

```swift
// RemoteMatchService.swift
private let challengeExpirySeconds: TimeInterval = 86400 // 24 hours
private let joinWindowSeconds: TimeInterval = 300 // 5 minutes
```

```sql
-- Database (documented in migration)
-- Challenge Expiry: 24 hours (86400 seconds)
-- Join Window: 5 minutes (300 seconds)
-- Expiration Check: Every 1 minute (pg_cron)
```

---

## Next Steps - Phase 1

### Task 1: Run Database Migration
1. Open Supabase Dashboard → SQL Editor
2. Copy contents of `supabase_migrations/047_remote_matches_schema.sql`
3. Execute migration
4. Verify tables created successfully

### Task 2: Implement Edge Functions
Create 6 Edge Functions for server-authoritative operations:
1. `create_challenge` - Create pending match
2. `accept_challenge` - Enforce locks, transition to ready
3. `cancel_match` - Clear locks, cancel match
4. `join_match` - Handle lobby/in_progress transition
5. `save_visit` - Server-authoritative turn validation
6. `expire_matches` - Cron job for expiration

### Task 3: Setup pg_cron
Configure scheduled job to run `expire_matches` every 1 minute.

---

## Rollback Plan

If migration needs to be rolled back, execute the rollback script at the bottom of `047_remote_matches_schema.sql`:

```sql
BEGIN;
DROP INDEX IF EXISTS matches_challenger_status_idx;
DROP INDEX IF EXISTS matches_receiver_status_idx;
-- ... (see migration file for complete rollback script)
COMMIT;
```

---

## Key Benefits

✅ **Same Match Detail view** for local and remote matches  
✅ **Same visit log** structure (match_throws table)  
✅ **Same History tab** integration  
✅ **Minimal code duplication**  
✅ **Race-condition safe** (lock table)  
✅ **Server-authoritative** (Edge Functions)  
✅ **Type-safe** (DB enum + Swift enum)  

---

## Files Created

1. `supabase_migrations/047_remote_matches_schema.sql` - Database migration
2. `DanDart/Models/RemoteMatch.swift` - Swift models
3. `DanDart/Services/RemoteMatchService.swift` - Service layer
4. `PHASE_0_COMPLETE.md` - This document

---

## Acceptance Criteria Met

- ✅ All schema changes documented
- ✅ Enum types defined
- ✅ Lock table prevents race conditions
- ✅ Push token storage ready
- ✅ Expiration strategy specified
- ✅ Reuses existing match history pipeline
- ✅ Edge Functions specified with validation logic
- ✅ Lock acquisition/release lifecycle documented

---

**Phase 0 Status: COMPLETE ✅**

Ready to proceed with Phase 1 (Backend Implementation) after migration approval.
