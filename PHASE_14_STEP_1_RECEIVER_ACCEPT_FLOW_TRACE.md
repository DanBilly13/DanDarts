# Phase 14 Step 1: Receiver Accept Flow Trace

## Complete Receiver Accept Path Analysis

This document traces the exact sequence of operations from receiver accept tap through lobby entry, identifying where the authoritative revalidation gate should be placed.

---

## Flow Sequence

### 1. Accept Button Tap
**Location:** `RemoteGamesTab.swift:649` - `acceptChallenge(matchId:)`

**Actions:**
- Log accept tap with current flow state
- Dump state snapshot (reason: "acceptTap")
- **Guard:** Check `processingMatchId == nil` (prevent double-accept)
- **Guard:** Verify match exists in `pendingChallenges`
- Capture opponent data from match (CRITICAL: before state changes)

**State Changes:**
- `remoteMatchService.beginAcceptPresentationFreeze(matchId)` - UI freeze starts
- `freezeListSnapshot(reason: "acceptTap")` - Freeze list before network calls
- `remoteMatchService.beginEnterFlow(matchId)` - Sets:
  - `processingMatchId = matchId`
  - `isEnteringFlow = true` (latch)
  - `navInFlightMatchId = matchId`
  - Increments `navToken`

---

### 2. Accept Challenge Edge Call
**Location:** `RemoteGamesTab.swift:689` - `remoteMatchService.acceptChallenge(matchId)`

**Actions:**
- Log "acceptChallenge EDGE START"
- Call `refreshPendingEnterFlow(matchId)` (watchdog refresh)
- **Edge Function Call:** `accept-challenge` (pending → ready)
- Log "acceptChallenge EDGE OK"
- Refresh enter flow watchdog
- Dump state snapshot (reason: "acceptSuccess")

**Server State Change:**
- Match status: `pending` → `ready`

---

### 3. Lock Contention Delay
**Location:** `RemoteGamesTab.swift:698-700`

**Actions:**
- Log "DELAY 1s before enterLobby to avoid lock contention"
- `Task.sleep(1_000_000_000)` (1 second)
- Log "DELAY complete"

**Purpose:** Avoid database lock contention between accept and enter-lobby

**⚠️ CRITICAL TIMING WINDOW:**
This is where slow runs can expose the race condition. If the match expires during this delay or during the subsequent `enterLobby` call, the client may not detect it before continuing.

---

### 4. Enter Lobby Edge Call
**Location:** `RemoteGamesTab.swift:715` - `remoteMatchService.enterLobby(matchId)`

**Actions:**
- **Guard:** Check if match was cancelled (`cancelledMatchIds.contains(matchId)`)
- If cancelled: call `endEnterFlow(matchId)` and return
- Log "enterLobby EDGE START"
- Call `refreshPendingEnterFlow(matchId)` (watchdog refresh)
- **Edge Function Call:** `enter-lobby` (receiver joins, ready → lobby)
- Log "enterLobby EDGE OK"
- Refresh enter flow watchdog
- Dump state snapshot (reason: "enterLobbySuccess")

**Server State Change:**
- Match status: `ready` → `lobby`
- `receiver_in_lobby = true`
- `join_window_expires_at` set (if not already set)

**⚠️ CRITICAL TIMING WINDOW:**
This is the slowest operation in the flow. In pathological runs, this can take abnormally long, allowing the match to expire while the call is in flight.

---

### 5. Fetch Updated Match
**Location:** `RemoteGamesTab.swift:727` - `remoteMatchService.fetchMatch(matchId)`

**Actions:**
- Log "fetchMatch START"
- Call `refreshPendingEnterFlow(matchId)` (watchdog refresh)
- **Database Query:** Fetch authoritative match state
- **Guard:** Verify match exists (throw if nil)
- Log "fetchMatch OK status=\(status) cp=\(currentPlayerId)"
- Refresh enter flow watchdog

**Data Retrieved:**
- `updatedMatch` with current server state
- Includes `status`, `currentPlayerId`, `joinWindowExpiresAt`

**⚠️ CURRENT GAP - NO VALIDATION:**
The fetched match status is NOT validated before continuing to navigation. If the match is `expired`, `cancelled`, or `completed`, the flow continues anyway.

---

### 6. Success Haptic
**Location:** `RemoteGamesTab.swift:736-739`

**Actions:**
- Generate success haptic feedback
- Occurs BEFORE navigation decision

**⚠️ PREMATURE SUCCESS SIGNAL:**
Haptic fires even if the match is already expired, giving false positive feedback.

---

### 7. Navigation Decision
**Location:** `RemoteGamesTab.swift:742-835`

**Actions:**
- Switch to MainActor
- **Guard:** Check if match was cancelled (again)
- If cancelled: call `endEnterFlow(matchId)` and return
- Log "ROUTER: REQUEST push remoteLobby"
- Capture `navToken` for guard
- **Guard:** Verify `navInFlightMatchId == matchId` (still active nav request)
- **Guard:** Verify `navToken` unchanged (no concurrent nav)
- Log "ROUTER: PUSH remoteLobby"
- **Push to RemoteLobbyView** with `updatedMatch` (potentially expired!)

**State Passed to Lobby:**
- `match: updatedMatch` (NOT validated for terminal status)
- `opponent: User`
- `currentUser: User`
- `cancelledMatchIds: Binding`
- `onCancel: closure`
- `onUnfreeze: closure`

**⚠️ CRITICAL BUG:**
No validation of `updatedMatch.status` before pushing. If status is `expired`, `cancelled`, or `completed`, the lobby is still pushed.

---

### 8. Background Reload
**Location:** `RemoteGamesTab.swift:839-843`

**Actions:**
- Start background task
- Call `remoteMatchService.loadMatches(userId)`
- Log "Background reload complete after receiver navigation"

**Purpose:** Update UI state after navigation

---

### 9. RemoteLobbyView.onAppear
**Location:** `RemoteLobbyView.swift:327-404`

**Actions:**
- Log "onAppear" with instance ID and match ID
- Determine role (challenger vs receiver)
- Log "LOBBY: onAppear role=\(role)"
- **Clear accept UI freeze:** `clearAcceptPresentationFreeze(matchId)`
- **Skip side effects if preview mode**
- `enterRemoteFlow(matchId, initialMatch)` - Set flow match
- **Clear enter-flow state:** `endEnterFlow(matchId)` - Clears:
  - `processingMatchId = nil`
  - `isEnteringFlow = false` (latch cleared)
  - `navInFlightMatchId = nil`
- `onUnfreeze()` - Unfreeze list snapshot in RemoteGamesTab
- Set `isViewActive = true`

**⚠️ CRITICAL BUG - NO TERMINAL STATE GUARD:**
Lobby does NOT check if match is expired/cancelled/completed before running side effects.

---

### 10. Confirm Lobby View Entered
**Location:** `RemoteLobbyView.swift:359-383` (Task inside onAppear)

**Actions:**
- Log "confirmLobbyViewEntered START"
- **Edge Function Call:** `confirm-lobby-view-entered`
- Log "confirmLobbyViewEntered OK"
- Log "requestRefresh START reason=post-confirm"
- Call `requestRefresh(reason: "post-confirm")` - Fetches fresh match
- Log "requestRefresh OK"
- Log countdown state
- Dump state snapshot (reason: "lobbyOnAppear_afterConfirm")

**⚠️ SIDE EFFECT ON EXPIRED MATCH:**
If match is expired, this edge call may fail or succeed depending on backend validation. Either way, it's wasted work.

---

### 11. Start Voice Session
**Location:** `RemoteLobbyView.swift:391-404` (Task inside onAppear)

**Actions:**
- Call `voiceChatService.startSession(matchId, localUserId, challengerId, receiverId)`
- Log "Voice session started" or "Failed to start voice session"
- Non-blocking: voice failure doesn't prevent match

**⚠️ SIDE EFFECT ON EXPIRED MATCH:**
Voice session starts even if match is expired, wasting resources and potentially confusing users.

---

### 12. Lobby Refresh Logic
**Location:** `RemoteLobbyView.swift:428-448` (Timer.publish every 1s)

**Actions:**
- Check if match still exists in service
- Check if match is being started
- If match doesn't exist and not starting: `router.popToRoot()`

**Purpose:** Exit lobby if match is removed/cancelled/expired

**⚠️ REACTIVE CLEANUP:**
This is reactive cleanup that happens AFTER side effects have already run. Better to prevent side effects from running in the first place.

---

### 13. Countdown Logic
**Location:** `RemoteLobbyView.swift:450-474` (onChange countdownElapsed)

**Actions:**
- Guard: countdown elapsed, status == lobby, both players present
- Guard: not already requested start
- Set `hasRequestedMatchStart = true`
- Call `remoteMatchService.startMatchIfReady(matchId)`

**⚠️ SIDE EFFECT ON EXPIRED MATCH:**
If match is expired but countdown logic still runs, this will fail on backend but still attempts the call.

---

## Critical Gaps Identified

### Gap 1: No Authoritative Revalidation After enterLobby
**Location:** Between line 721 and 742 in RemoteGamesTab.swift

**Problem:**
After `enterLobby` succeeds and `fetchMatch` retrieves the updated match, there is NO validation of the match status before deciding to push to lobby.

**Current Code:**
```swift
guard let updatedMatch = try await remoteMatchService.fetchMatch(matchId: matchId) else {
    throw RemoteMatchError.databaseError("Failed to fetch updated match")
}
// ... logs ...
// Success haptic
// Navigate to lobby WITHOUT checking updatedMatch.status
```

**What's Missing:**
```swift
// MISSING: Validate match status before continuing
guard let status = updatedMatch.status else {
    throw RemoteMatchError.invalidMatchState("Match has no status")
}

// MISSING: Block terminal states
guard status == .lobby || status == .inProgress else {
    // Match is expired/cancelled/completed - abort flow
    await MainActor.run {
        remoteMatchService.endEnterFlow(matchId: matchId)
        remoteMatchService.clearAcceptPresentationFreeze(matchId: matchId)
        unfreezeListSnapshotAfterTransition()
    }
    return
}
```

**Impact:**
This is the PRIMARY bug. Without this gate, expired matches continue into lobby flow.

---

### Gap 2: No Terminal State Guard in RemoteLobbyView.onAppear
**Location:** RemoteLobbyView.swift:327-404

**Problem:**
Lobby onAppear runs ALL side effects without checking if the match is already terminal.

**Current Code:**
```swift
.onAppear {
    // ... role determination ...
    // Clear accept freeze
    // Enter remote flow
    // Clear enter-flow state
    // Unfreeze list
    // Start confirm task (runs confirmLobbyViewEntered)
    // Start voice session
}
```

**What's Missing:**
```swift
.onAppear {
    // MISSING: Guard against terminal states FIRST
    guard let status = match.status else {
        print("⚠️ [Lobby] Match has no status - dismissing")
        router.popToRoot()
        return
    }
    
    guard status == .lobby || status == .inProgress else {
        print("⚠️ [Lobby] Match is terminal (status=\(status.rawValue)) - dismissing")
        remoteMatchService.clearAcceptPresentationFreeze(matchId: match.id)
        router.popToRoot()
        return
    }
    
    // NOW safe to run side effects
    // ... existing code ...
}
```

**Impact:**
Even if Gap 1 is fixed, this provides defense-in-depth. If an expired match somehow reaches lobby, it should immediately exit rather than running side effects.

---

### Gap 3: No Centralized Abort Helper
**Problem:**
When entry needs to abort, multiple pieces of state must be cleared:
- `processingMatchId`
- `isEnteringFlow` (latch)
- `navInFlightMatchId`
- Accept UI freeze
- List snapshot freeze

**Current Approach:**
Each error path manually calls:
- `endEnterFlow(matchId)`
- `clearAcceptPresentationFreeze(matchId)`
- `unfreezeListSnapshotAfterTransition()`

**Risk:**
Easy to forget one piece, leaving stale state.

**What's Missing:**
A centralized helper in RemoteMatchService:
```swift
func abortReceiverEntry(matchId: UUID, reason: String) {
    FlowDebug.log("ABORT_ENTRY: reason=\(reason)", matchId: matchId)
    endEnterFlow(matchId: matchId)
    clearAcceptPresentationFreeze(matchId: matchId)
    // Note: unfreezeListSnapshot is in RemoteGamesTab, so caller must handle
}
```

---

## Recommended Fix Location

### Primary Fix: Add Authoritative Revalidation Gate
**File:** `RemoteGamesTab.swift`
**Location:** After line 733 (after fetchMatch logs)
**Before:** Line 735 (success haptic)

**Implementation:**
```swift
// Step 2.6: VALIDATE match status before continuing
let status = updatedMatch.status
let statusStr = status?.rawValue ?? "nil"
FlowDebug.log("ACCEPT: VALIDATE status=\(statusStr)", matchId: matchId)

// Guard: Only continue for valid lobby states
guard status == .lobby || status == .inProgress else {
    let reason = "invalidStatus_\(statusStr)"
    FlowDebug.log("ACCEPT: ABORT reason=\(reason)", matchId: matchId)
    
    await MainActor.run {
        remoteMatchService.endEnterFlow(matchId: matchId)
        remoteMatchService.clearAcceptPresentationFreeze(matchId: matchId)
        unfreezeListSnapshotAfterTransition()
        
        // Show user-friendly message
        if status == .expired {
            errorMessage = "This challenge has expired"
        } else if status == .cancelled {
            errorMessage = "This challenge was cancelled"
        } else if status == .completed {
            errorMessage = "This match has already been completed"
        } else {
            errorMessage = "This challenge is no longer available"
        }
        showError = true
    }
    
    return // STOP - do not continue to navigation
}

FlowDebug.log("ACCEPT: VALIDATE OK - continuing to navigation", matchId: matchId)
```

---

### Secondary Fix: Add Terminal State Guard in Lobby
**File:** `RemoteLobbyView.swift`
**Location:** Top of onAppear block (after line 333)
**Before:** Line 335 (clearAcceptPresentationFreeze)

**Implementation:**
```swift
// GUARD: Exit immediately if match is terminal
let status = match.status
let statusStr = status?.rawValue ?? "nil"
FlowDebug.log("LOBBY: GUARD status=\(statusStr)", matchId: match.id)

guard status == .lobby || status == .inProgress else {
    FlowDebug.log("LOBBY: ABORT reason=terminalStatus_\(statusStr)", matchId: match.id)
    remoteMatchService.clearAcceptPresentationFreeze(matchId: match.id)
    remoteMatchService.endEnterFlow(matchId: match.id)
    onUnfreeze()
    router.popToRoot()
    return
}

FlowDebug.log("LOBBY: GUARD OK - continuing with side effects", matchId: match.id)
```

---

## Timing Analysis

### Healthy Run Timing
1. Accept tap → acceptChallenge: ~200-500ms
2. 1s delay: 1000ms
3. enterLobby: ~200-500ms
4. fetchMatch: ~100-200ms
5. Navigation: ~50ms
6. **Total: ~1.5-2.3 seconds**

### Pathological Run Timing (from logs)
1. Accept tap → acceptChallenge: ~200-500ms
2. 1s delay: 1000ms
3. enterLobby: **~3-5+ seconds** (abnormally slow)
4. fetchMatch: ~100-200ms
5. Navigation: ~50ms
6. **Total: ~4.5-6.8+ seconds**

**Expiry Window:** Matches typically have 30-60 second join windows. If a receiver accepts near the end of the window, and enterLobby is slow, the match can expire before the flow completes.

---

## Summary

### Last Safe Stop Point
**Location:** After `fetchMatch` completes (line 733)
**Reason:** This is the last point where we have authoritative server state BEFORE committing to navigation.

### Critical Decision Point
**Question:** Is `updatedMatch.status` valid for continued lobby flow?
**Valid States:** `.lobby`, `.inProgress`
**Invalid States:** `.expired`, `.cancelled`, `.completed`, `nil`

### Action Required
If invalid: **Abort entry flow cleanly** without pushing to lobby.
If valid: **Continue to navigation** as currently implemented.

---

## Next Steps (Phase 14 Step 2)

1. Implement authoritative revalidation gate in RemoteGamesTab.swift
2. Implement terminal state guard in RemoteLobbyView.swift
3. Create centralized abort helper in RemoteMatchService.swift
4. Test with scenarios:
   - Accept near expiry boundary
   - Simulate slow enterLobby
   - Force expired state before navigation
   - Verify no stale lobby side effects

---

**Document Status:** Complete
**Date:** 2026-03-18
**Phase:** 14 Step 1
