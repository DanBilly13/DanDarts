# Enter-Lobby Validation Measurements

**Purpose:** Track timing data to validate whether the `match_players` constraint fix resolves the slow `enter-lobby` path.

**Hypothesis:** Missing `UNIQUE (match_id, player_user_id)` constraint causes database error 42P10, triggering retries/timeouts that result in variable 2-10 second delays.

**Date Started:** 2026-03-18

---

## Deployment Status

- [ ] Database migration 080 applied
- [ ] Edge function `enter-lobby` deployed with instrumentation
- [ ] Client code already has timing logs (no deployment needed)

---

## Test Runs

### Test Run #1

**Date/Time:** _______________  
**Match ID:** _______________  
**Challenger:** _______________  
**Receiver:** _______________

**Edge Function Timing (from Supabase logs):**
- `auth_end` duration: _____ ms
- `match_select_end` duration: _____ ms
- `match_update_end` duration: _____ ms
- **`player_upsert_end` duration: _____ ms** ← KEY METRIC
- `total_duration_ms`: _____ ms
- Errors in any step: YES / NO
  - If yes, details: _______________

**Client Timing (from Xcode console):**
- `ENTER_LOBBY_TIMING durationMs`: _____ ms
- `ttlAutoClearDuringRequest`: true / false
- `success`: true / false

**User Experience:**
- Receiver tap to lobby arrival: ~_____ seconds
- Spinning wheel duration: ~_____ seconds
- Challenger saw "ready" at: _______________
- Receiver reached lobby at: _______________

**Notes:**
_______________

---

### Test Run #2

**Date/Time:** _______________  
**Match ID:** _______________  
**Challenger:** _______________  
**Receiver:** _______________

**Edge Function Timing (from Supabase logs):**
- `auth_end` duration: _____ ms
- `match_select_end` duration: _____ ms
- `match_update_end` duration: _____ ms
- **`player_upsert_end` duration: _____ ms** ← KEY METRIC
- `total_duration_ms`: _____ ms
- Errors in any step: YES / NO
  - If yes, details: _______________

**Client Timing (from Xcode console):**
- `ENTER_LOBBY_TIMING durationMs`: _____ ms
- `ttlAutoClearDuringRequest`: true / false
- `success`: true / false

**User Experience:**
- Receiver tap to lobby arrival: ~_____ seconds
- Spinning wheel duration: ~_____ seconds
- Challenger saw "ready" at: _______________
- Receiver reached lobby at: _______________

**Notes:**
_______________

---

### Test Run #3

**Date/Time:** _______________  
**Match ID:** _______________  
**Challenger:** _______________  
**Receiver:** _______________

**Edge Function Timing (from Supabase logs):**
- `auth_end` duration: _____ ms
- `match_select_end` duration: _____ ms
- `match_update_end` duration: _____ ms
- **`player_upsert_end` duration: _____ ms** ← KEY METRIC
- `total_duration_ms`: _____ ms
- Errors in any step: YES / NO
  - If yes, details: _______________

**Client Timing (from Xcode console):**
- `ENTER_LOBBY_TIMING durationMs`: _____ ms
- `ttlAutoClearDuringRequest`: true / false
- `success`: true / false

**User Experience:**
- Receiver tap to lobby arrival: ~_____ seconds
- Spinning wheel duration: ~_____ seconds
- Challenger saw "ready" at: _______________
- Receiver reached lobby at: _______________

**Notes:**
_______________

---

### Test Run #4

**Date/Time:** _______________  
**Match ID:** _______________  
**Challenger:** _______________  
**Receiver:** _______________

**Edge Function Timing (from Supabase logs):**
- `auth_end` duration: _____ ms
- `match_select_end` duration: _____ ms
- `match_update_end` duration: _____ ms
- **`player_upsert_end` duration: _____ ms** ← KEY METRIC
- `total_duration_ms`: _____ ms
- Errors in any step: YES / NO
  - If yes, details: _______________

**Client Timing (from Xcode console):**
- `ENTER_LOBBY_TIMING durationMs`: _____ ms
- `ttlAutoClearDuringRequest`: true / false
- `success`: true / false

**User Experience:**
- Receiver tap to lobby arrival: ~_____ seconds
- Spinning wheel duration: ~_____ seconds
- Challenger saw "ready" at: _______________
- Receiver reached lobby at: _______________

**Notes:**
_______________

---

### Test Run #5

**Date/Time:** _______________  
**Match ID:** _______________  
**Challenger:** _______________  
**Receiver:** _______________

**Edge Function Timing (from Supabase logs):**
- `auth_end` duration: _____ ms
- `match_select_end` duration: _____ ms
- `match_update_end` duration: _____ ms
- **`player_upsert_end` duration: _____ ms** ← KEY METRIC
- `total_duration_ms`: _____ ms
- Errors in any step: YES / NO
  - If yes, details: _______________

**Client Timing (from Xcode console):**
- `ENTER_LOBBY_TIMING durationMs`: _____ ms
- `ttlAutoClearDuringRequest`: true / false
- `success`: true / false

**User Experience:**
- Receiver tap to lobby arrival: ~_____ seconds
- Spinning wheel duration: ~_____ seconds
- Challenger saw "ready" at: _______________
- Receiver reached lobby at: _______________

**Notes:**
_______________

---

## Analysis Summary

### Average Timings (across all runs)

- **`player_upsert_end` average:** _____ ms
- **`total_duration_ms` average:** _____ ms
- **Client `durationMs` average:** _____ ms
- **Receiver tap-to-lobby average:** _____ seconds

### Consistency Check

- All runs fast (<2s)? YES / NO
- Any runs still slow (>5s)? YES / NO
- Variable timing observed? YES / NO

### Error Analysis

- Any database errors? YES / NO
- Any constraint errors? YES / NO
- Any timeout errors? YES / NO

### Hypothesis Validation

**✅ VALIDATED** - Constraint was the root cause IF:
- [ ] `player_upsert_end` dropped from ~8-10s to <100ms
- [ ] Total duration consistently <2s
- [ ] No errors in upsert step
- [ ] Receiver reaches lobby in ~3-5s total

**⚠️ PARTIALLY VALIDATED** - Constraint helped but not enough IF:
- [ ] `player_upsert_end` improved but still slow (500-1000ms)
- [ ] OR different step is now the bottleneck
- [ ] Total duration improved but still variable

**❌ REJECTED** - Constraint made no difference IF:
- [ ] `player_upsert_end` still ~8-10s
- [ ] Total duration still variable
- [ ] Same or different errors observed

---

## Next Steps (Based on Results)

### If Validated ✅
1. Remove 1-second delay workaround in `RemoteGamesTab.swift`
2. Re-test without delay
3. Verify no regression
4. Mark Phase 1 complete

### If Partially Validated ⚠️
1. Identify new bottleneck step from timing logs
2. Investigate that specific operation
3. Apply targeted optimization
4. Re-measure

### If Rejected ❌
1. Re-analyze all timing logs
2. Look for actual bottleneck (row locking, RLS, network, cold start)
3. Form new hypothesis
4. Design new validation experiment

---

## Raw Log Samples

Paste raw log output here for reference:

### Supabase Logs (enter-lobby function)
```
[Paste logs here]
```

### Xcode Console (client timing)
```
[Paste logs here]
```
