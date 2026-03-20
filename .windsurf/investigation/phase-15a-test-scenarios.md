# Phase 15-A Test Scenarios Guide

**Purpose:** Run these scenarios to collect evidence about voice startup reliability issues.

---

## Pre-Test Setup

1. **Enable Console Logging in Xcode:**
   - Open Xcode
   - Run the app on simulator or device
   - Open Console (Cmd+Shift+C)
   - Filter by process name: "DanDart"

2. **Prepare Log Capture:**
   - Have text editor ready to paste logs
   - Note timestamps for each scenario
   - Clear console between scenarios for clarity

---

## Scenario A: Clean Build Baseline

**Goal:** Establish healthy baseline behavior after clean build.

### Steps:
1. **Clean Build:**
   ```
   Product → Clean Build Folder (Cmd+Shift+K)
   Product → Build (Cmd+B)
   Product → Run (Cmd+R)
   ```

2. **Start Remote Match:**
   - Sign in as User A
   - Navigate to Remote tab
   - Send challenge to User B
   - (On second device/simulator) Sign in as User B
   - Accept challenge
   - Both users enter lobby

3. **Observe Voice Startup:**
   - Watch console for voice session logs
   - Note if voice connects successfully
   - Check for any warnings or errors

4. **Capture Logs:**
   - Copy all console output from app launch to voice connected
   - Save to: `.windsurf/investigation/phase-15a-logs-clean-build.txt`

5. **Complete Match:**
   - Play through match or cancel
   - Exit to main screen

### What to Look For:
- ✅ Single instance IDs for all services
- ✅ Clean subscription attachment
- ✅ Voice session starts successfully
- ✅ No stale state warnings
- ✅ All state verification shows `nil ✅`

---

## Scenario B: Repeated Run (No Clean Build)

**Goal:** Detect state contamination from previous run.

### Steps:
1. **DO NOT Clean Build** - Use existing app session from Scenario A

2. **Start Another Remote Match:**
   - (Same users as Scenario A)
   - Send new challenge
   - Accept challenge
   - Both users enter lobby

3. **Observe Voice Startup:**
   - Watch console for voice session logs
   - Compare behavior to Scenario A
   - Note any differences or failures

4. **Capture Logs:**
   - Copy all console output from match start to voice startup attempt
   - Save to: `.windsurf/investigation/phase-15a-logs-repeated-run.txt`

5. **Complete Match:**
   - Play through match or cancel
   - Exit to main screen

### What to Look For:
- ⚠️ Duplicate instance IDs (multiple inits without deinits)
- ⚠️ Stale session warnings
- ⚠️ Old subscriptions still active
- ⚠️ State verification failures (`NOT NIL ⚠️`)
- ⚠️ Voice messages from previous match
- ⚠️ Multiple `enterRemoteFlow()` without matching exits

### Key Questions:
- Does voice fail to connect?
- Are there more instance IDs than expected?
- Do cleanup verification logs show incomplete cleanup?
- Are old session/match IDs appearing in new match?

---

## Scenario C: Force-Quit Relaunch

**Goal:** Test if app relaunch alone restores reliability.

### Steps:
1. **Force-Quit App:**
   - Stop app in Xcode (Cmd+.)
   - OR: Swipe up to kill app on device/simulator

2. **Relaunch App:**
   - Product → Run (Cmd+R)
   - OR: Tap app icon

3. **Start Remote Match:**
   - Sign in (if needed)
   - Send challenge
   - Accept challenge
   - Both users enter lobby

4. **Observe Voice Startup:**
   - Watch console for voice session logs
   - Compare to Scenario A and B

5. **Capture Logs:**
   - Copy all console output from app launch to voice startup
   - Save to: `.windsurf/investigation/phase-15a-logs-force-quit.txt`

### What to Look For:
- Does behavior match Scenario A (clean) or Scenario B (contaminated)?
- Are instance IDs fresh (new UUIDs)?
- Is cleanup complete from previous session?

### Key Question:
**Does force-quit restore reliability?**
- If YES → Problem is in-memory state, not persisted
- If NO → Problem may be deeper or protocol-related

---

## Scenario D: Multiple Match Attempts

**Goal:** Detect accumulating state or subscription leaks.

### Steps:
1. **DO NOT Clean Build** - Continue from previous scenarios

2. **Run 3 Consecutive Matches:**
   - Match 1: Start → Play/Cancel → Exit
   - Match 2: Start → Play/Cancel → Exit
   - Match 3: Start → Observe voice startup

3. **Capture Logs:**
   - Copy all console output for all 3 matches
   - Save to: `.windsurf/investigation/phase-15a-logs-multiple-attempts.txt`

### What to Look For:
- Increasing number of instance IDs
- Accumulating subscriptions
- Growing cleanup verification failures
- Memory/performance degradation

### Key Questions:
- Does each match create new instances without cleaning old ones?
- Do subscription counts increase?
- Does voice reliability degrade further with each attempt?

---

## Log Analysis Workflow

After capturing logs for all scenarios:

### 1. Instance ID Tracking

Search logs for instance IDs:
```
🔵 [Lifecycle] VoiceChatService.init() - instanceId: ABC-123
🔵 [Lifecycle] RemoteMatchService.init() - instanceId: DEF-456
🔵 [Lifecycle] RemoteLobbyView.onAppear() - viewInstanceId: GHI-789
🔵 [Lifecycle] RemoteGameplayView.init() - viewInstanceId: JKL-012
```

**Count instances per match:**
- VoiceChatService: Should be 1 (singleton)
- RemoteMatchService: Should be 1 per environment
- RemoteLobbyView: Should be 1 per match
- RemoteGameplayView: Should be 1 per match

### 2. Cleanup Verification

Search for cleanup verification:
```
🔴 [Cleanup] State verification:
   - currentSession: nil ✅
   - signallingChannel: nil ✅
   - peerConnection: nil ✅
```

**Check for failures:**
- Any `NOT NIL ⚠️` indicates incomplete cleanup
- Missing verification logs indicate cleanup not called

### 3. Flow Depth Tracking

Search for flow enter/exit:
```
⚪️ [Flow] enterRemoteFlow() START
⚪️ [Flow] exitRemoteFlow() START
```

**Verify balanced depth:**
- Each enter should have matching exit
- Depth should return to 0 after flow exit
- `isInRemoteFlow` should be false after exit

### 4. Subscription Tracking

Search for subscription operations:
```
🟢 [Subscribe] ========== CHANNEL SETUP START ==========
🔴 [Cleanup] teardownSignallingChannel() START
```

**Check for leaks:**
- Each setup should have matching teardown
- Look for "EXISTS ⚠️" warnings on new setup
- Verify subscription is nil after teardown

### 5. Message Flow Analysis

Search for incoming messages:
```
🟣 [Signal] ========== INCOMING MESSAGE ==========
🟣 [Signal] instanceId: ABC-123
```

**Check for anomalies:**
- Messages arriving for old matches
- Messages arriving after cleanup
- Duplicate message processing
- Out-of-order message sequences

---

## Decision Tree

Based on log analysis, follow this decision tree:

### Question 1: Are there duplicate instances?

**YES** → Proceed to Question 2  
**NO** → Skip to Question 4

### Question 2: Are instances from previous matches?

**YES** → **FINDING: Incomplete cleanup / Stale instances**  
- Route A: Lifecycle/Cleanup Problem  
- Focus: Ensure deinit is called, cleanup is complete

**NO** → **FINDING: Duplicate initialization in same match**  
- Route C: Mixed Problem  
- Focus: Prevent duplicate view/service creation

### Question 3: Is cleanup verification failing?

**YES** → **FINDING: Incomplete cleanup**  
- Route A: Lifecycle/Cleanup Problem  
- Focus: Fix cleanup methods, ensure all state cleared

**NO** → Proceed to Question 4

### Question 4: Are old session/match IDs appearing?

**YES** → **FINDING: State contamination**  
- Route A: Lifecycle/Cleanup Problem  
- Focus: Reset all state on flow exit

**NO** → Proceed to Question 5

### Question 5: Are subscriptions duplicated?

**YES** → **FINDING: Subscription leak**  
- Route A: Lifecycle/Cleanup Problem  
- Focus: Ensure unsubscribe is called, tokens released

**NO** → Proceed to Question 6

### Question 6: Does voice fail even with clean state?

**YES** → **FINDING: Bootstrap protocol issue**  
- Route B: Bootstrap Protocol Problem  
- Focus: Fix signalling handshake, message ordering

**NO** → **SUCCESS: No issues detected**  
- May need more test scenarios or deeper investigation

---

## Expected Outcomes

### Scenario A (Clean Build):
- ✅ All single instances
- ✅ Clean startup
- ✅ Voice connects
- ✅ Complete cleanup

### Scenario B (Repeated Run):
If **Route A** (Lifecycle Problem):
- ⚠️ Duplicate instances OR
- ⚠️ Stale state OR
- ⚠️ Incomplete cleanup

If **Route B** (Protocol Problem):
- ✅ Clean instances
- ✅ Complete cleanup
- ⚠️ Voice fails to connect

### Scenario C (Force-Quit):
- Should match Scenario A if problem is in-memory state
- Should match Scenario B if problem persists across launches

### Scenario D (Multiple Attempts):
- Should show accumulation if cleanup is incomplete
- Should remain stable if cleanup is working

---

## Next Steps After Analysis

1. **Document Findings:**
   - Create `.windsurf/investigation/phase-15a-analysis.md`
   - List all issues found with log evidence
   - Answer all checklist questions

2. **Make Decision:**
   - Create `.windsurf/investigation/phase-15a-decision.md`
   - Choose Route A, B, or C based on evidence
   - Justify decision with specific log examples

3. **Plan Phase 15-B:**
   - Define specific fixes based on route chosen
   - Prioritize issues by severity
   - Create implementation plan

---

## Tips for Log Analysis

1. **Use grep/search effectively:**
   ```bash
   grep "instanceId:" logs.txt
   grep "⚠️" logs.txt
   grep "NOT NIL" logs.txt
   ```

2. **Track timestamps:**
   - Note when issues first appear
   - Correlate with user actions
   - Identify timing patterns

3. **Compare scenarios:**
   - Diff Scenario A vs B logs
   - Look for what changed
   - Identify what clean build resets

4. **Focus on first failure:**
   - Find earliest warning/error
   - Trace backwards to root cause
   - Don't get distracted by downstream effects

5. **Verify assumptions:**
   - Don't assume singleton means one instance
   - Check actual instance IDs in logs
   - Prove rather than assume
