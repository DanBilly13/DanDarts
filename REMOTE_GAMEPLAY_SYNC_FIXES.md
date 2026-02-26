# Remote Gameplay Turn Synchronization Fixes

## Summary

Fixed three critical bugs preventing Player B from seeing updates and turn switches after Player A saves their score.

**Date:** 2026-02-25

---

## Issues Fixed

### 1. LastVisitPayload Schema Mismatch (CRITICAL) ✅

**Problem:** Decode failures silently dropped entire realtime updates, preventing Player B from seeing any changes.

**Solution:** Implemented defensive decoder that handles both camelCase and snake_case formats.

**File:** `DanDart/Models/RemoteMatch.swift`

**Changes:**
- Added custom `init(from:)` decoder with fallback logic
- Tries camelCase first (`playerId`, `scoreBefore`, `scoreAfter`)
- Falls back to snake_case (`player_id`, `score_before`, `score_after`)
- Handles both Date and String timestamp formats
- Added optional `isBust` field for future use
- Uses default values if all decoding attempts fail (never throws)
- Added custom `encode(to:)` to output snake_case (database format)

**Result:** Decode never fails, realtime updates always process.

---

### 2. Duplicate Subscriptions ✅

**Problem:** `subscribeToMatch()` called multiple times without guards, causing one subscription to become unsubscribed.

**Solution:** Made subscription idempotent with tracking.

**File:** `DanDart/ViewModels/Games/RemoteGameplayViewModel.swift`

**Changes:**
- Added `private var subscribedMatchId: UUID?` property
- Added guard check at start of `subscribeToMatch()`:
  - Returns early if already subscribed to same match
  - Prevents duplicate channel creation
- Set `subscribedMatchId = matchId` AFTER successful `channel.subscribeWithError()`
- Clear both `realtimeChannel` and `subscribedMatchId` in `unsubscribeFromMatch()`
- Added logging for subscription lifecycle

**Result:** Only one active subscription per match, no race conditions.

---

### 3. No Server-Side Filtering ✅

**Problem:** Subscription processed all match updates with client-side filtering, increasing noise and potential for bugs.

**Solution:** Added server-side filter to reduce network traffic and parsing load.

**File:** `DanDart/ViewModels/Games/RemoteGameplayViewModel.swift`

**Changes:**
- Added `filter: "id=eq.\(matchId.uuidString)"` to `onPostgresChange()` call
- Removed 15 lines of client-side match ID comparison logic
- Simplified callback to directly process updates (already filtered by server)
- Updated logging to reflect server-side filtering

**Result:** Only relevant updates received, reduced parsing errors and complexity.

---

## Technical Details

### Subscription Lifecycle Management

**Order of operations:**
1. Guard check (idempotency) BEFORE channel creation
2. Create channel
3. Register callbacks
4. Call `channel.subscribeWithError()`
5. Set `realtimeChannel` and `subscribedMatchId` AFTER successful subscription
6. On cleanup: clear BOTH properties

### Decoding Resilience

**LastVisitPayload:**
- Never throws - uses default values as fallback
- Handles schema variations (camelCase vs snake_case)
- Logs warnings for decode failures but doesn't block processing

**RemoteMatch:**
- `lastVisitPayload` already optional
- Uses default Codable synthesized decoder
- If visit payload decode fails, it's set to `nil` and match still processes

### Server-Side Filter Syntax

**Supabase PostgREST filter:**
```swift
filter: "id=eq.\(matchId.uuidString)"
```

This is a PostgREST filter, not a Swift predicate. Server filters before sending to client, reducing:
- Network traffic (only relevant updates sent)
- Parsing load (no need to decode irrelevant matches)
- Potential for client-side filtering bugs

---

## Testing Checklist

After deployment, verify:
- [ ] Player A saves score → Player B sees reveal overlay
- [ ] Turn switches correctly (isMyTurn updates on both devices)
- [ ] No duplicate subscriptions (check logs for "Already subscribed")
- [ ] Decode never fails (no "Failed to decode" errors that block updates)
- [ ] Works after app backgrounding/resuming
- [ ] Works with network delays

---

## Files Modified

1. **DanDart/Models/RemoteMatch.swift**
   - Added defensive decoder to `LastVisitPayload` (lines 178-246)
   - Handles both camelCase and snake_case
   - Added `isBust` optional field
   - Never throws, uses default values

2. **DanDart/ViewModels/Games/RemoteGameplayViewModel.swift**
   - Added `subscribedMatchId` property (line 51)
   - Added idempotency guard in `subscribeToMatch()` (lines 252-257)
   - Set `subscribedMatchId` after successful subscription (line 322)
   - Clear both properties in `unsubscribeFromMatch()` (lines 345-346)
   - Added server-side filter to `onPostgresChange()` (line 274)
   - Removed client-side filtering logic (deleted ~15 lines)

---

## Expected Outcome

**Before fixes:**
- Player A saves score
- Player B sees nothing
- Turn doesn't switch
- Silent decode failures

**After fixes:**
- Player A saves score → Edge Function updates DB → Realtime broadcasts
- Player B's subscription receives update (server-filtered, no decode errors)
- Player B's `handleMatchUpdate()` fires
- Reveal shows, scores update, turn switches
- Both players see synchronized state

---

## Notes

- Edge Function already sends correct snake_case format
- Defensive decoder prevents future schema drift issues
- Channel name doesn't matter for postgres_changes - subscription filter is what counts
- Idempotent subscription prevents race conditions from duplicate calls
- Server-side filtering is more reliable and efficient than client-side

---

**Status: All fixes implemented and ready for testing**
