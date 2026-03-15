# Receiver Accept Flow Crash Diagnostic Logging

**Date:** 2026-03-15  
**Issue:** App crashes immediately after tapping Accept button on receiver phone

## Problem Statement

**Receiver Phone:** Crashes right after tapping Accept button  
**Challenger Phone:** Appears to hang / fail to hand off cleanly into remote flow

This is a **receiver-side crash**, not a general ready/lobby handoff issue.

## Comprehensive Step-by-Step Logging Added

Every step in the receiver accept flow now has explicit logging with numbered steps and clear success/failure markers.

### Accept Flow Steps (16 Total)

#### Step 1-2: Initial Guards & Setup
```
🔵🔵🔵 [ACCEPT] ========== ACCEPT TAP ==========
🔵 [ACCEPT] Match ID: <matchId>
🔵 [ACCEPT] Thread: MAIN | BACKGROUND
🔵 [ACCEPT] Step 1: Guard checks starting...
✅ [ACCEPT] Guard 1 passed: Not already processing
✅ [ACCEPT] Guard 2 passed: Match found in pendingChallenges
🔵 [ACCEPT] Opponent captured: <name> (<id>)
🔵 [ACCEPT] Step 2: Freezing list snapshot...
✅ [ACCEPT] List snapshot frozen
```

**Early Returns:**
- `❌ [ACCEPT] EARLY RETURN: Already processing <matchId>`
- `❌ [ACCEPT] EARLY RETURN: Match not found in pendingChallenges`

#### Step 3-4: Enter Flow & Task Start
```
🔵 [ACCEPT] Step 3: Beginning enter flow...
✅ [ACCEPT] Enter flow begun - latch set
🔵 [ACCEPT] Flow state: pendingEnterFlow=<bool>
🔵 [ACCEPT] Nav state: navInFlightMatchId=<matchId|nil>
🔵 [ACCEPT] Processing state: processingMatchId=<matchId|nil>
🔵 [ACCEPT] Step 4: Starting async Task...
🔵 [ACCEPT] Task started - Thread: MAIN | BACKGROUND
```

#### Step 5-6: User Check & Accept Challenge
```
🔵 [ACCEPT] Step 5: Checking current user...
✅ [ACCEPT] Current user: <name> (<id>)
🔵🔵🔵 [ACCEPT] ========== acceptChallenge START ==========
🔵 [ACCEPT] Step 6: Calling acceptChallenge edge function...
✅✅✅ [ACCEPT] ========== acceptChallenge OK ==========
```

**Early Returns:**
- `❌ [ACCEPT] THROW: Not authenticated`

#### Step 7-8: Cancel Check & Join Match
```
🔵 [ACCEPT] Step 7: Checking if match was cancelled...
✅ [ACCEPT] Match not cancelled, proceeding to auto-join
🔵🔵🔵 [ACCEPT] ========== joinMatch START ==========
🔵 [ACCEPT] Step 8: Calling joinMatch edge function...
✅✅✅ [ACCEPT] ========== joinMatch OK ==========
```

**Early Returns:**
- `❌ [ACCEPT] EARLY RETURN: Match was cancelled`

#### Step 9-10: Fetch Match & Haptic
```
🔵🔵🔵 [ACCEPT] ========== fetchMatch BEFORE ==========
🔵 [ACCEPT] Step 9: Fetching updated match data...
✅✅✅ [ACCEPT] ========== fetchMatch AFTER ==========
🔵 [ACCEPT] Match status: <status>
🔵 [ACCEPT] Current player: <playerId>
🔵 [ACCEPT] Step 10: Triggering success haptic...
✅ [ACCEPT] Haptic triggered
```

**Early Returns:**
- `❌ [ACCEPT] THROW: Failed to fetch updated match`

#### Step 11-13: Navigation Setup
```
🔵🔵🔵 [ACCEPT] ========== NAV REQUEST remoteLobby ==========
🔵 [ACCEPT] Step 11: Entering MainActor.run for navigation...
🔵 [ACCEPT] Inside MainActor.run - Thread: MAIN | BACKGROUND
🔵 [ACCEPT] Step 12: Checking cancellation guard...
✅ [ACCEPT] Cancellation guard passed
🔵 [ACCEPT] Step 13: Capturing navigation token...
✅ [ACCEPT] Token captured: <token>
```

**Early Returns:**
- `❌ [ACCEPT] EARLY RETURN: Match in cancelled set`

#### Step 14-15: Navigation Task Scheduling
```
🔵 [ACCEPT] Step 14: Scheduling navigation Task...
🔵 [ACCEPT] Navigation Task started - Thread: MAIN | BACKGROUND
🔵 [ACCEPT] Step 15: Yielding to finish current frame...
✅ [ACCEPT] Yield complete
```

#### Step 16: Router Push
```
🔵🔵🔵 [ACCEPT] ========== BEFORE router.push(.remoteLobby) ==========
🔵 [ACCEPT] Step 16: About to call router.push...
🔵 [ACCEPT] Match: <matchId>
🔵 [ACCEPT] Opponent: <name>
🔵 [ACCEPT] Current user: <name>
✅✅✅ [ACCEPT] ========== AFTER router.push(.remoteLobby) ==========
✅ [ACCEPT] router.push completed successfully
```

**Early Returns:**
- `🚫 [RECEIVER] NAV BLOCKED: navInFlight changed`
- `🚫 [RECEIVER] NAV BLOCKED: token changed`

### Error Handling
```
❌❌❌ [ACCEPT] ========== CATCH ERROR ==========
❌ [ACCEPT] Error type: <type>
❌ [ACCEPT] Error: <error>
❌ [ACCEPT] Localized: <message>
❌ [ACCEPT] RemoteMatchError: <specific error>
❌ [ACCEPT] Stack trace: <20 frames>
🔵 [ACCEPT] Cleaning up after error...
✅ [ACCEPT] Error cleanup complete
❌ [ACCEPT] =================================================
```

## Identifying the Crash Point

The last log before the crash will tell you exactly where it's failing:

### If crash is BEFORE any logs:
- Issue in button tap handler setup
- Issue in RemoteGamesTab initialization
- Check PlayerChallengeCard onAccept closure

### If crash is between Step 1-3:
- Issue in guard checks
- Issue in freezeListSnapshot()
- Issue in beginEnterFlow()

### If crash is between Step 4-6:
- Issue in Task creation
- Issue in authService.currentUser
- Issue in acceptChallenge edge function call

### If crash is between Step 7-8:
- Issue in cancelled check
- Issue in joinMatch edge function call

### If crash is between Step 9-10:
- Issue in fetchMatch call
- Issue in haptic feedback generation

### If crash is between Step 11-13:
- Issue in MainActor.run
- Issue in cancellation guard
- Issue in token capture

### If crash is between Step 14-16:
- Issue in Task scheduling
- Issue in Task.yield()
- Issue in router.push() call

### If crash is AFTER Step 16:
- Issue in RemoteLobbyView initialization
- Issue in voice session start
- Issue in lobby onAppear

## Voice Integration Timing

Voice session start happens in RemoteLobbyView.onAppear, which is AFTER router.push completes.

If the crash is happening before "AFTER router.push(.remoteLobby)" log, then voice is NOT the cause.

If the crash is happening after that log, check RemoteLobbyView.onAppear logs:
```
🧩 [Lobby] ========== LOBBY VIEW ON_APPEAR ==========
🎤 [VOICE] ========== VOICE SESSION START ATTEMPT ==========
```

## Log Filtering

To see only the accept flow:
```bash
grep "\[ACCEPT\]" console.log
```

To see the exact crash point:
```bash
grep -E "(ACCEPT|CRASH|EXCEPTION|FATAL)" console.log
```

To see the last successful step:
```bash
grep "✅.*\[ACCEPT\]" console.log | tail -1
```

## Expected Successful Flow

Complete successful accept flow should show:
1. ✅ Guard 1 passed
2. ✅ Guard 2 passed
3. ✅ List snapshot frozen
4. ✅ Enter flow begun
5. ✅ Current user found
6. ✅✅✅ acceptChallenge OK
7. ✅ Match not cancelled
8. ✅✅✅ joinMatch OK
9. ✅✅✅ fetchMatch AFTER
10. ✅ Haptic triggered
11. ✅ Cancellation guard passed
12. ✅ Token captured
13. ✅ Yield complete
14. ✅✅✅ AFTER router.push(.remoteLobby)

If any of these are missing, that's where the crash occurred.

## Next Steps

1. **Tap Accept button** on receiver phone
2. **Immediately check console** for logs
3. **Find the last ✅ log** - that's the last successful step
4. **Find the next 🔵 log** - that's where it crashed
5. **Check for ❌ CATCH ERROR** - if present, read the error details
6. **Report back** with the exact step number and any error message

## Files Modified

- RemoteGamesTab.swift (acceptChallenge method, lines 599-897)
  - Added 16 numbered steps with explicit logging
  - Added early return logging for all guards
  - Added error catch with full stack trace
  - Added thread identification at key points
