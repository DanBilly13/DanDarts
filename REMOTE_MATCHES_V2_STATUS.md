# Remote Matches V2 - Current Status & Bug Investigation

**Last Updated:** March 2, 2026  
**Status:** In Development - Debugging Pre-Turn Reveal Feature

---

## Overview

Remote Matches V2 is a real-time multiplayer darts system built on Supabase with live gameplay synchronization. Players can challenge friends, play 301/501 games remotely, and see opponent moves in real-time.

---

## Architecture

### Core Components

1. **Database (Supabase PostgreSQL)**
   - `matches` table: Stores match state, scores, turn tracking
   - `last_visit_payload` JSONB column: Contains opponent's last 3 darts
   - Real-time subscriptions via Supabase Realtime

2. **Edge Functions**
   - `save-visit`: Processes dart throws, updates scores, flips turns
   - Returns updated match state with `last_visit_payload`

3. **iOS Client (Swift/SwiftUI)**
   - `RemoteMatchService`: Manages match state, realtime subscriptions
   - `RemoteGameplayView`: Gameplay UI with scoring input
   - `GameViewModel`: Local game logic and state management

### Data Flow

```
Player A saves visit
    ↓
Edge Function (save-visit)
    ↓
Database UPDATE (includes last_visit_payload)
    ↓
Realtime broadcast to Player B
    ↓
RemoteMatchService.fetchMatch()
    ↓
flowMatch updated
    ↓
RemoteGameplayView observes change
    ↓
Pre-Turn Reveal triggers (SHOULD HAPPEN - CURRENTLY BROKEN)
```

---

## Current Bug: Pre-Turn Reveal Not Showing

### Feature Intent

**Pre-Turn Reveal** should show Player B the opponent's just-saved darts (e.g., "16 16 10") in the `CurrentThrowDisplay` for 1.5 seconds, even if the server has already flipped the turn to Player B. During this reveal:
- All input (scoring grid, save button, dart selection) is disabled
- After 1.5s, the reveal clears and normal input resumes

### Expected Behavior

When Player A saves their visit:
1. Edge function updates database with `last_visit_payload: {darts: [16,16,10], timestamp: "2026-03-02T18:13:00.123Z", ...}`
2. Realtime UPDATE event fires on Player B's device
3. `RemoteMatchService.fetchMatch()` decodes the payload
4. `flowMatch.lastVisitPayload` is populated
5. `RemoteGameplayView` observes `serverLastVisitTimestamp` change
6. `.onChange` handler triggers, activates `preTurnRevealIsActive = true`
7. `CurrentThrowDisplay` shows opponent's darts for 1.5s
8. Input is disabled during reveal
9. After 1.5s, reveal clears and input re-enables

### Actual Behavior

**Pre-Turn Reveal never shows. No logs appear.**

---

## Investigation Timeline

### Phase 1: Initial Implementation
- ✅ Added `lastVisitPayload` to `RemoteMatch` model
- ✅ Added `LastVisitPayload` struct with proper CodingKeys
- ✅ Implemented Pre-Turn Reveal logic in `RemoteGameplayView`
- ✅ Added state variables: `preTurnRevealThrow`, `preTurnRevealIsActive`
- ✅ Added computed properties: `isMyTurn`, `isInputEnabled`, `renderThrowForCurrentThrowDisplay`
- ✅ Wired `CurrentThrowDisplay` with input gating
- ✅ Added `.onChange(of: serverLastVisitTimestamp)` handler

### Phase 2: Debugging Attempts

**Attempt 1: Observe flowMatch directly**
- Changed `serverLastVisitTimestamp` to observe `remoteMatchService.flowMatch`
- Result: No change, onChange still not firing

**Attempt 2: Use renderMatch instead**
- Changed back to observe `renderMatch?.lastVisitPayload?.timestamp`
- Result: No change, onChange still not firing

**Attempt 3: Add comprehensive debug instrumentation**
- Added `dbg()` and `dbgMatchSnapshot()` helper functions
- Added `debugRenderProbe` to track view re-renders
- Added multiple `.onChange` handlers to track all state changes
- Result: **No logs appear at all** - suggests onChange is not firing

**Attempt 4: Add service-level logging**
- Added logs in `RemoteMatchService.fetchMatch()` after `flowMatch` update
- Result: Logs show `flowMatch.lvp = nil` even though realtime payload contains data

### Phase 3: Root Cause Identified

**Discovery:** The `MatchResponse` struct in `RemoteMatchService.fetchMatch()` is **missing the `last_visit_payload` field**.

**Evidence:**
```swift
// RemoteMatchService.swift line 289
struct MatchResponse: Decodable {
    let id: UUID
    let match_mode: String
    // ... other fields ...
    let debug_counter: Int?
    // ❌ MISSING: let last_visit_payload: LastVisitPayload?
}
```

**Impact:**
- When `fetchMatch()` decodes the database response, `last_visit_payload` is dropped
- `RemoteMatch` is constructed with `lastVisitPayload: nil` (hardcoded, line 363)
- `flowMatch.lastVisitPayload` is always nil
- `serverLastVisitTimestamp` is always nil
- `.onChange` never fires because the value never changes from nil

---

## The Fix (Pending Implementation)

### Step 1: Add Field to MatchResponse
**File:** `RemoteMatchService.swift` line ~306

Add to `MatchResponse` struct:
```swift
let last_visit_payload: LastVisitPayload?
```

### Step 2: Pass Decoded Value to RemoteMatch
**File:** `RemoteMatchService.swift` line ~363

Change:
```swift
lastVisitPayload: nil,
```

To:
```swift
lastVisitPayload: matchData.last_visit_payload,
```

### Step 3: Add Verification Logging
**File:** `RemoteMatchService.swift` line ~380

Add after `flowMatch` assignment:
```swift
print("✅ [RTGD-SVC] flowMatch.last_visit_payload = \(String(describing: self.flowMatch?.lastVisitPayload))")
print("✅ [RTGD-SVC] flowMatch.lvp.ts = \(String(describing: self.flowMatch?.lastVisitPayload?.timestamp))")
print("✅ [RTGD-SVC] flowMatch.lvp.pid = \(String(describing: self.flowMatch?.lastVisitPayload?.playerId))")
print("✅ [RTGD-SVC] flowMatch.lvp.darts = \(String(describing: self.flowMatch?.lastVisitPayload?.darts))")
```

---

## Expected Results After Fix

When Player A saves and Player B receives the update:

```
🚨🚨🚨 [RemoteMatch Realtime] UPDATE CALLBACK FIRED!!!
🔄 [Realtime] fetchMatch(flow) match=abc123
🧪 [fetchMatch DECODED] last_visit_payload=present
🧪 [fetchMatch DECODED] lvp.timestamp=2026-03-02T18:13:00.123Z
🧪 [fetchMatch DECODED] lvp.darts=[16, 16, 10]
✅ [RTGD-SVC] flowMatch.last_visit_payload = Optional(LastVisitPayload(...))
✅ [RTGD-SVC] flowMatch.lvp.ts = Optional("2026-03-02T18:13:00.123Z")
✅ [RTGD-SVC] flowMatch.lvp.pid = Optional(abc123...)
✅ [RTGD-SVC] flowMatch.lvp.darts = Optional([16, 16, 10])
🧪 [RTGD] RENDER match=abc123 cp=abc123 lvp.pid=def456 ts=2026-03-02T18:13:00.123Z darts=[16, 16, 10] isMyTurn=true preReveal=false
🧪 [RTGD] onChange(serverLastVisitTimestamp) old=nil new=2026-03-02T18:13:00.123Z
🧪 [RTGD] TS_CHANGE match=abc123 ...
🎯 [PreTurnReveal] SHOW darts=[16, 16, 10] ts=2026-03-02T18:13:00.123Z isMyTurn=true
🧪 [RTGD] onChange(preTurnRevealIsActive) false -> true
🧪 [RTGD] REVEAL_FLAG_CHANGE ... preReveal=true
[CurrentThrowDisplay shows: 16 16 10 = 42]
[Input disabled for 1.5s]
🎯 [PreTurnReveal] CLEAR ts=2026-03-02T18:13:00.123Z
🧪 [RTGD] onChange(preTurnRevealIsActive) true -> false
[Input re-enabled]
```

---

## Key Files

### Models
- `DanDart/Models/RemoteMatch.swift` - Match and LastVisitPayload models ✅ CORRECT
  - Lines 54-173: `RemoteMatch` struct
  - Lines 177-191: `LastVisitPayload` struct
  - Line 72: `lastVisitPayload` property
  - Line 165: CodingKeys mapping

### Services
- `DanDart/Services/RemoteMatchService.swift` - Match fetching and realtime ❌ NEEDS FIX
  - Lines 287-400: `fetchMatch()` method
  - Lines 289-307: `MatchResponse` struct (MISSING field)
  - Line 363: Hardcoded `lastVisitPayload: nil` (NEEDS UPDATE)
  - Lines 375-383: flowMatch update location (ADD LOGS)

### Views
- `DanDart/Views/Games/Remote/RemoteGameplayView.swift` - Gameplay UI ✅ CORRECT
  - Lines 31-34: Pre-turn reveal state variables
  - Lines 112-120: `isMyTurn`, `isInputEnabled` computed properties
  - Lines 126-130: `renderThrowForCurrentThrowDisplay` computed property
  - Lines 149-154: `serverLastVisitTimestamp` computed property
  - Lines 279-286: `CurrentThrowDisplay` wiring with input gating
  - Lines 318, 338: Input disabling during reveal
  - Lines 635-678: `.onChange` handler with Pre-Turn Reveal logic

### Edge Functions
- `supabase/functions/save-visit/index.ts` - Score processing ✅ WORKING
  - Returns `last_visit_payload` in response
  - Database UPDATE includes the field
  - Realtime broadcast contains the data

---

## Testing Checklist (After Fix)

- [ ] Verify `flowMatch.lastVisitPayload` is not nil after opponent saves
- [ ] Verify `serverLastVisitTimestamp` changes trigger `.onChange`
- [ ] Verify Pre-Turn Reveal shows opponent's darts for 1.5s
- [ ] Verify input is disabled during reveal
- [ ] Verify input re-enables after reveal clears
- [ ] Verify reveal does not show for own saves
- [ ] Verify reveal does not show if opponent hasn't saved yet
- [ ] Test in both directions (Player A → B and B → A)
- [ ] Test with different dart combinations
- [ ] Test rapid consecutive saves

---

## Notes

- The UI logic is **already correct** - the issue is purely in the decode path
- This is a **2-line fix** plus optional logging
- No changes needed to the database schema or edge functions
- No changes needed to the `RemoteMatch` model
- The realtime subscription is working correctly (UPDATE events fire)
- The problem is isolated to `MatchResponse` struct definition

---

## Next Steps

1. Implement the 2-line fix in `RemoteMatchService.swift`
2. Add verification logging
3. Test with two devices
4. Verify logs show populated `lastVisitPayload`
5. Verify Pre-Turn Reveal displays correctly
6. Remove debug instrumentation once confirmed working
7. Document final solution
