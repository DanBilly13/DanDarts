# Remote Flow Diagnostic Logging Implementation

**Date:** 2026-03-15  
**Purpose:** Diagnose remote flow state machine fragility around ready/lobby transition and navigation handoff

## Problem Statement

Both challenger and receiver phones are experiencing issues where:
- Backend match state progresses correctly (pending → ready → lobby)
- Card state updates correctly
- **BUT** local UI does not reliably continue into the remote flow / lobby route
- No crashes detected - just missing navigation continuation

**Suspected Root Cause:**
- Realtime/list refresh/card-state churn is racing with enter-flow/navigation gating
- Voice integration may have made timing more brittle
- Server state is fine; local handoff into the flow is not

## Logging Implementation

### 1. RemoteLobbyView.swift - Status Change Observer

**Location:** `.onChange(of: matchStatus)` (lines 333-407)

**Logs Added:**
```
🔔 [Lobby] ========== STATUS CHANGE OBSERVER ENTRY ==========
🔔 [Lobby] OLD STATUS: <status>
🔔 [Lobby] NEW STATUS: <status>
🔔 [Lobby] ROLE: CHALLENGER | RECEIVER
🔔 [Lobby] Current user: <userId>
🔔 [Lobby] Challenger: <challengerId>
🔔 [Lobby] Receiver: <receiverId>
🔔 [Lobby] Flow latch state: pendingEnterFlow=<bool>
🔔 [Lobby] Navigation state: navInFlightMatchId=<matchId|nil>
🔔 [Lobby] Processing state: processingMatchId=<matchId|nil>
🔔 [Lobby] Cancelled set contains match: <bool>
🔔 [Lobby] isViewActive: <bool>
🔔 [Lobby] =================================================
```

**Decision Branches:**
- **NOT IN_PROGRESS:** Logs why auto-enter flow is skipped
- **IN_PROGRESS:** Logs decision to attempt start, latch acquisition, navigation allowed/blocked

### 2. RemoteGamesTab.swift - Receiver Flow (acceptChallenge)

**Location:** Lines 675-808

**Logs Added:**

**Navigation Decision Point:**
```
🔵 [RECEIVER] ========== NAVIGATION DECISION POINT ==========
🔵 [RECEIVER] ROLE: RECEIVER (accepted challenge)
🔵 [RECEIVER] Match ID: <matchId>
🔵 [RECEIVER] Match status: <status>
🔵 [RECEIVER] Current player: <playerId>
🔵 [RECEIVER] Flow latch BEFORE nav: pendingEnterFlow=<bool>
🔵 [RECEIVER] Navigation state: navInFlightMatchId=<matchId|nil>
🔵 [RECEIVER] Processing state: processingMatchId=<matchId|nil>
🔵 [RECEIVER] Cancelled set contains: <bool>
🔵 [RECEIVER] DECISION: Navigation ALLOWED | BLOCKED
```

**Scheduled Navigation Execution:**
```
🔵 [RECEIVER] ========== SCHEDULED NAV EXECUTION ==========
🔵 [RECEIVER] Executing scheduled navigation after yield
🔵 [RECEIVER] Flow latch state: pendingEnterFlow=<bool>
🔵 [RECEIVER] navInFlightMatchId: <matchId|nil>
🔵 [RECEIVER] Expected matchId: <matchId>
🔵 [RECEIVER] Token check: current=<token> service=<token>
✅ [RECEIVER] NAV GUARDS PASSED - PUSHING TO ROUTER
✅ [RECEIVER] BEFORE router.push(.remoteLobby)
✅ [RECEIVER] AFTER router.push(.remoteLobby)
✅ [RECEIVER] Flow latch AFTER push: pendingEnterFlow=<bool>
✅ [RECEIVER] Navigation should now be in progress
✅ [RECEIVER] =================================================
```

### 3. RemoteGamesTab.swift - Challenger Flow (joinMatch)

**Location:** Lines 961-1102

**Logs Added:**

**Join Match Called:**
```
🟢 [CHALLENGER] ========== JOIN MATCH CALLED ==========
🟢 [CHALLENGER] ROLE: CHALLENGER (joining ready match)
🟢 [CHALLENGER] Match ID: <matchId>
🟢 [CHALLENGER] Cancelled set contains: <bool>
🟢 [CHALLENGER] DECISION: Join ALLOWED | BLOCKED
🟢 [CHALLENGER] Flow latch BEFORE beginEnterFlow: pendingEnterFlow=<bool>
🟢 [CHALLENGER] Flow latch AFTER beginEnterFlow: pendingEnterFlow=<bool>
🟢 [CHALLENGER] Navigation state: navInFlightMatchId=<matchId|nil>
🟢 [CHALLENGER] Processing state: processingMatchId=<matchId|nil>
🟢 [CHALLENGER] =================================================
```

**Navigation Decision Point:**
```
🟢 [CHALLENGER] ========== NAVIGATION DECISION POINT ==========
🟢 [CHALLENGER] Join edge function succeeded
🟢 [CHALLENGER] Flow latch state: pendingEnterFlow=<bool>
🟢 [CHALLENGER] Navigation state: navInFlightMatchId=<matchId|nil>
🟢 [CHALLENGER] Processing state: processingMatchId=<matchId|nil>
🟢 [CHALLENGER] Cancelled set contains: <bool>
🟢 [CHALLENGER] DECISION: Navigation ALLOWED | BLOCKED
🟢 [CHALLENGER] Match status: <status>
🟢 [CHALLENGER] Current player: <playerId>
🟢 [CHALLENGER] BEFORE router.push(.remoteLobby)
✅ [CHALLENGER] AFTER router.push(.remoteLobby)
✅ [CHALLENGER] Flow latch AFTER push: pendingEnterFlow=<bool>
✅ [CHALLENGER] Navigation should now be in progress
✅ [CHALLENGER] =================================================
```

### 4. RemoteLobbyView.swift - OnAppear

**Location:** Lines 253-285

**Logs Added:**
```
🧩 [Lobby] ========== LOBBY VIEW ON_APPEAR ==========
🧩 [Lobby] instance=<instanceId> match=<matchId>
🧩 [Lobby] ROLE: CHALLENGER | RECEIVER
🧩 [Lobby] Flow latch BEFORE enterRemoteFlow: pendingEnterFlow=<bool>
🧩 [Lobby] Navigation state: navInFlightMatchId=<matchId|nil>
🧩 [Lobby] Processing state: processingMatchId=<matchId|nil>
🧩 [Lobby] Flow latch AFTER enterRemoteFlow: pendingEnterFlow=<bool>
🧩 [Lobby] Flow latch AFTER endEnterFlow: pendingEnterFlow=<bool>
🧩 [Lobby] Navigation state AFTER clear: navInFlightMatchId=<matchId|nil>
🧩 [Lobby] Processing state AFTER clear: processingMatchId=<matchId|nil>
🧩 [Lobby] =================================================
```

### 5. Voice Session Start Timing

**Location:** RemoteLobbyView.swift, lines 287-321

**Logs Added:**
```
🎤 [VOICE] ========== VOICE SESSION START ATTEMPT ==========
🎤 [VOICE] Match ID: <matchId>
🎤 [VOICE] Timing: Called from RemoteLobbyView.onAppear
🎤 [VOICE] BEFORE navigation handoff (navigation may be scheduled)
🎤 [VOICE] Role: RECEIVER | CHALLENGER
🎤 [VOICE] Current user: <userId>
🎤 [VOICE] Other player: <userId>
🎤 [VOICE] Starting voice session...
✅ [VOICE] Voice session started successfully
✅ [VOICE] Connection state: <state>
✅ [VOICE] =================================================
```

## Expected Log Patterns

### Successful Receiver Flow

1. **Accept Challenge:**
   ```
   🔵 [RECEIVER] ========== NAVIGATION DECISION POINT ==========
   🔵 [RECEIVER] DECISION: Navigation ALLOWED
   ```

2. **Scheduled Navigation:**
   ```
   🔵 [RECEIVER] ========== SCHEDULED NAV EXECUTION ==========
   ✅ [RECEIVER] NAV GUARDS PASSED - PUSHING TO ROUTER
   ✅ [RECEIVER] BEFORE router.push(.remoteLobby)
   ✅ [RECEIVER] AFTER router.push(.remoteLobby)
   ```

3. **Lobby Appears:**
   ```
   🧩 [Lobby] ========== LOBBY VIEW ON_APPEAR ==========
   🧩 [Lobby] ROLE: RECEIVER
   ```

4. **Voice Starts:**
   ```
   🎤 [VOICE] ========== VOICE SESSION START ATTEMPT ==========
   ✅ [VOICE] Voice session started successfully
   ```

5. **Status Change to In Progress:**
   ```
   🔔 [Lobby] ========== STATUS CHANGE OBSERVER ENTRY ==========
   🔔 [Lobby] NEW STATUS: inProgress
   🔔 [Lobby] ROLE: RECEIVER
   ✅ [Lobby] ========== IN_PROGRESS - ATTEMPTING START ==========
   ```

### Successful Challenger Flow

1. **Join Match:**
   ```
   🟢 [CHALLENGER] ========== JOIN MATCH CALLED ==========
   🟢 [CHALLENGER] DECISION: Join ALLOWED
   🟢 [CHALLENGER] Flow latch AFTER beginEnterFlow: pendingEnterFlow=true
   ```

2. **Navigation Decision:**
   ```
   🟢 [CHALLENGER] ========== NAVIGATION DECISION POINT ==========
   🟢 [CHALLENGER] DECISION: Navigation ALLOWED
   🟢 [CHALLENGER] BEFORE router.push(.remoteLobby)
   ✅ [CHALLENGER] AFTER router.push(.remoteLobby)
   ```

3. **Lobby Appears:**
   ```
   🧩 [Lobby] ========== LOBBY VIEW ON_APPEAR ==========
   🧩 [Lobby] ROLE: CHALLENGER
   ```

4. **Voice Starts:**
   ```
   🎤 [VOICE] ========== VOICE SESSION START ATTEMPT ==========
   ✅ [VOICE] Voice session started successfully
   ```

5. **Status Change to In Progress:**
   ```
   🔔 [Lobby] ========== STATUS CHANGE OBSERVER ENTRY ==========
   🔔 [Lobby] NEW STATUS: inProgress
   🔔 [Lobby] ROLE: CHALLENGER
   ✅ [Lobby] ========== IN_PROGRESS - ATTEMPTING START ==========
   ```

## Failure Patterns to Look For

### 1. Navigation Never Scheduled
**Symptom:** No `BEFORE router.push(.remoteLobby)` log
**Possible Causes:**
- Navigation guards failing (cancelled match, token mismatch)
- Match not found in service arrays
- User not authenticated

### 2. Navigation Scheduled But Never Executed
**Symptom:** See `SCHEDULED NAV EXECUTION` but no `BEFORE router.push`
**Possible Causes:**
- navInFlightMatchId changed between schedule and execution
- Token changed between schedule and execution
- Task cancelled

### 3. Navigation Executed But Lobby Never Appears
**Symptom:** See `AFTER router.push(.remoteLobby)` but no `LOBBY VIEW ON_APPEAR`
**Possible Causes:**
- Router navigation failed silently
- View hierarchy issue
- Navigation stack corruption

### 4. Lobby Appears But Status Change Never Fires
**Symptom:** See `LOBBY VIEW ON_APPEAR` but no `STATUS CHANGE OBSERVER ENTRY`
**Possible Causes:**
- Match status not changing to inProgress
- Realtime updates not arriving
- flowMatch not being updated

### 5. Voice Session Blocking Navigation
**Symptom:** Voice logs appear before navigation completion
**Possible Causes:**
- Voice session start is blocking main thread
- Voice errors interfering with navigation
- Timing race between voice and navigation

## Key Diagnostic Questions

When reviewing logs, answer these questions:

1. **Status Change Observer Entry:**
   - Does it fire for both roles?
   - What is the old/new status transition?
   - What is the flow latch state?
   - Is navigation allowed or blocked?

2. **Navigation Decision Point:**
   - Is navigation allowed?
   - What are the flow latch, navInFlight, and processing states?
   - Is the match in the cancelled set?

3. **Scheduled Navigation Execution:**
   - Do the guards pass?
   - Is router.push called?
   - What is the flow latch state after push?

4. **Lobby OnAppear:**
   - Does it fire?
   - What role is the user?
   - What are the flow states before/after clear?

5. **Voice Session Start:**
   - When does it start relative to navigation?
   - Does it succeed or fail?
   - Is it blocking anything?

6. **Before Router Push:**
   - Is this log present?
   - What is the exact timing relative to other events?

7. **After Router Push:**
   - Is this log present?
   - Does Lobby.onAppear follow immediately?

## Files Modified

1. **RemoteLobbyView.swift**
   - Lines 333-407: Status change observer
   - Lines 253-285: OnAppear logging
   - Lines 287-321: Voice session start logging

2. **RemoteGamesTab.swift**
   - Lines 675-808: Receiver flow (acceptChallenge)
   - Lines 961-1102: Challenger flow (joinMatch)

## Next Steps

1. **Reproduce the issue** with this logging in place
2. **Collect logs** from both phones (challenger and receiver)
3. **Compare logs** against expected patterns above
4. **Identify the exact point** where the flow diverges from expected
5. **Focus investigation** on the specific failure pattern identified

## Log Filtering

To filter logs for a specific match:
```bash
# Receiver flow
grep "🔵 \[RECEIVER\]" console.log

# Challenger flow
grep "🟢 \[CHALLENGER\]" console.log

# Lobby status changes
grep "🔔 \[Lobby\]" console.log

# Lobby lifecycle
grep "🧩 \[Lobby\]" console.log

# Voice session
grep "🎤 \[VOICE\]" console.log

# All navigation decisions
grep -E "(NAVIGATION DECISION POINT|NAV GUARDS|router.push)" console.log
```

## Success Criteria

The logging is successful if it allows us to answer:
1. Which exact step in the flow is failing?
2. Is it a challenger-specific or receiver-specific issue?
3. Is the failure before or after router.push?
4. What is the state of flow latches at the failure point?
5. Is voice integration interfering with navigation timing?
