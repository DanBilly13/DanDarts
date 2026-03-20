# Phase 15-A Instrumentation Summary

**Date:** March 20, 2026  
**Status:** ✅ COMPLETE - Ready for Testing

## Overview

Comprehensive lifecycle and ownership instrumentation has been added to the remote matches voice chat system to investigate why voice startup works reliably after clean builds but fails on repeated runs.

## Investigation Goal

Determine the root cause of voice startup reliability issues by tracking:
1. **Stale state** - What survives between runs that shouldn't?
2. **Duplicate ownership** - Are multiple instances handling the same match?
3. **Incomplete cleanup** - Is state being properly reset on flow exit?
4. **Bootstrap timing** - Are there protocol races (only after ruling out above)?

---

## Files Instrumented

### 1. VoiceChatService.swift ✅

**Added:**
- Instance ID tracking: `private let instanceId = UUID()`
- `init()` logging with instance ID
- `deinit` logging with instance ID

**Enhanced Methods:**

#### `startSession()`
- Logs entry with matchId, instanceId, and all parameters
- Logs stale session detection
- Logs session creation with sessionId
- Tracks existing session checks

#### `endSession()`
- Comprehensive cleanup logging
- Logs each cleanup step (disconnect signal, channel teardown, WebRTC cleanup, audio deactivation)
- State verification after cleanup:
  - `currentSession` nil check
  - `signallingChannel` nil check
  - `peerConnection` nil check
  - `isPeerReady` / `isLocalReady` values

#### `setupSignallingChannel()`
- Logs channel setup start with instanceId
- Logs existing channel/subscription warnings
- Tracks channel name and event name
- Logs subscription attachment

#### `teardownSignallingChannel()`
- Logs teardown start with instanceId
- Logs existing state before teardown
- Resets readiness flags (`isPeerReady`, `isLocalReady`)
- Comprehensive state verification after teardown

**Log Categories Used:**
- 🔵 `[Lifecycle]` - init/deinit
- 🟡 `[Voice]` - session state changes
- 🟢 `[Subscribe]` - channel subscription operations
- 🔴 `[Cleanup]` - cleanup operations and verification

---

### 2. RemoteMatchService.swift ✅

**Added:**
- Instance ID tracking: `private let instanceId = UUID()`
- `init()` logging with instance ID
- `deinit` logging with instance ID

**Enhanced Methods:**

#### `enterRemoteFlow()`
- Logs entry with matchId and instanceId
- Logs current depth, flowMatchId, isInRemoteFlow state
- Logs whether initialMatch was provided
- Tracks depth increment and state changes

#### `exitRemoteFlow()`
- Logs exit start with instanceId
- Logs current depth and flow state
- Comprehensive cleanup logging when depth reaches 0
- State verification:
  - `isInRemoteFlow` false check
  - `flowMatchId` nil check
  - `flowMatch` nil check
- Logs voice session cleanup trigger

**Log Categories Used:**
- 🔵 `[Lifecycle]` - init/deinit
- ⚪️ `[Flow]` - remote flow enter/exit
- 🔴 `[Cleanup]` - cleanup operations and verification

---

### 3. RemoteLobbyView.swift ✅

**Already had:** `@State private var instanceId = UUID()`

**Enhanced Methods:**

#### `onAppear()`
- Logs view appearance with viewInstanceId
- Logs matchId and match status
- Logs isViewActive state
- Logs user role (challenger/receiver)

#### `onDisappear()`
- Logs view disappearance with viewInstanceId
- Logs matchId and isViewActive state
- Logs exitRemoteFlow() call
- Logs completion

**Log Categories Used:**
- 🔵 `[Lifecycle]` - onAppear
- 🔴 `[Lifecycle]` - onDisappear

---

### 4. RemoteGameplayView.swift ✅

**Added:**
- Instance ID tracking: `@State private var viewInstanceId = UUID()`
- Enhanced `init()` to create and log instance ID

**Enhanced Methods:**

#### `init()`
- Logs view initialization with viewInstanceId
- Logs matchId

#### `setupGameplayView()` (called from onAppear)
- Logs onAppear with viewInstanceId
- Logs matchId

#### `cleanupGameplayView()` (called from onDisappear)
- Logs onDisappear with viewInstanceId
- Logs matchId and isNavigatingToGameEnd state
- Logs whether exitRemoteFlow() is being called or skipped
- Logs completion

**Log Categories Used:**
- 🔵 `[Lifecycle]` - init, onAppear
- 🔴 `[Lifecycle]` - onDisappear

---

## Log Format Reference

### Emoji Prefixes
- 🔵 `[Lifecycle]` - Object/view creation and destruction
- 🟢 `[Subscribe]` - Subscription attach/detach operations
- 🔴 `[Cleanup]` - Cleanup operations and state verification
- ⚪️ `[Flow]` - Remote flow enter/exit
- 🟡 `[Voice]` - Voice session state changes
- 🟣 `[Signal]` - Signalling messages (existing)

### Standard Format
```
🔵 [Lifecycle] ClassName.method() - instanceId: ABC-123
🔵 [Lifecycle]   - property: value
```

### State Verification Format
```
🔴 [Cleanup] State verification:
   - property: nil ✅
   - property: NOT NIL ⚠️
```

---

## Next Steps

### 1. Run Test Scenarios

#### Scenario A: Clean Build Baseline
```bash
# Clean build
# Start remote match
# Observe voice startup
# Capture logs
```

**Expected:** Single instance IDs, clean startup, all ✅ in verification

#### Scenario B: Repeated Run (No Clean Build)
```bash
# Complete/exit match from Scenario A
# Start new remote match (same session)
# Compare logs to baseline
```

**Look for:**
- Duplicate instance IDs
- Stale state warnings (⚠️)
- Old subscriptions still active
- State verification failures (NOT NIL ⚠️)

#### Scenario C: Force-Quit Relaunch
```bash
# Force-quit app
# Relaunch
# Start remote match
# Compare to Scenario A
```

**Look for:** Whether app relaunch alone fixes issues

#### Scenario D: Multiple Match Attempts
```bash
# Start match → exit
# Start match → exit  
# Start match → observe
```

**Look for:** Accumulating state, subscription leaks

### 2. Capture Logs

Save logs to:
- `.windsurf/investigation/phase-15a-logs-clean-build.txt`
- `.windsurf/investigation/phase-15a-logs-repeated-run.txt`
- `.windsurf/investigation/phase-15a-logs-force-quit.txt`
- `.windsurf/investigation/phase-15a-logs-multiple-attempts.txt`

### 3. Analysis Checklist

Use this checklist to analyze captured logs:

#### Ownership Questions
- [ ] How many VoiceChatService instances exist during one match?
- [ ] How many signalling channel subscriptions exist per match?
- [ ] How many RemoteLobbyView instances exist per match?
- [ ] How many RemoteGameplayView instances exist per match?
- [ ] Do instance IDs match between related logs?

#### Cleanup Questions
- [ ] Is `endSession()` called when exiting match?
- [ ] Are all cleanup steps completed in `endSession()`?
- [ ] Is `signallingChannel` nil after cleanup? (✅ or ⚠️)
- [ ] Is `peerConnection` nil after cleanup? (✅ or ⚠️)
- [ ] Is `currentSession` nil after cleanup? (✅ or ⚠️)
- [ ] Are readiness flags reset (`isPeerReady`, `isLocalReady`)?
- [ ] Is `exitRemoteFlow()` called on view disappear?
- [ ] Are flow state variables cleared (`flowMatchId`, `flowMatch`)?

#### State Contamination Questions
- [ ] Do old session IDs appear in new match attempts?
- [ ] Do voice messages arrive for previous matches?
- [ ] Are subscriptions duplicated across runs?
- [ ] Does `isInRemoteFlow` persist incorrectly?
- [ ] Are there multiple `enterRemoteFlow()` calls without matching exits?

#### Bootstrap Questions (only after above is clean)
- [ ] Does message order vary between runs?
- [ ] Are duplicate messages being processed?
- [ ] Is offer creation triggered multiple times?

---

## Decision Matrix

Based on findings, proceed to one of these routes:

### Route A: Lifecycle/Cleanup Problem
**If we find:**
- Duplicate service instances
- Subscriptions not unsubscribed
- State not cleared on exit
- Old session IDs in new runs

**Then:** Phase 15-B focuses on cleanup hardening

### Route B: Bootstrap Protocol Problem
**If we find:**
- Clean ownership (single instances)
- Complete cleanup
- No stale state
- But still unreliable handshake

**Then:** Phase 15-B focuses on signalling protocol

### Route C: Mixed Problem
**If we find:**
- Some cleanup issues AND
- Some protocol timing issues

**Then:** Phase 15-B does cleanup first, then protocol

---

## Success Criteria

Instrumentation is successful when:
- ✅ All key services have instance ID logging
- ✅ All subscriptions have attach/detach logging
- ✅ All cleanup operations have verification logging
- ✅ All flow enter/exit events are logged
- ✅ Logs are structured and filterable
- ✅ Can run test scenarios and capture complete traces

Investigation is complete when:
- ✅ We can explain why clean build improves reliability
- ✅ We know whether issue is stale state, duplicate ownership, or protocol
- ✅ We have evidence-based decision for next phase
- ✅ We stop guessing and start proving

---

## Known Limitations

1. **Supabase Module Lint Error** - Expected false positive in Windsurf, code compiles in Xcode
2. **Singleton Services** - VoiceChatService is a singleton, so only one instance should exist (but we're verifying this)
3. **RemoteMatchService** - Not a singleton, created per environment injection (tracking needed)

---

## Files Modified

1. `/DanDart/Services/VoiceChatService.swift`
2. `/DanDart/Services/RemoteMatchService.swift`
3. `/DanDart/Views/Remote/RemoteLobbyView.swift`
4. `/DanDart/Views/Games/Remote/RemoteGameplayView.swift`

---

## Investigation Artifacts

Create these files as investigation progresses:
- `.windsurf/investigation/phase-15a-logs-clean-build.txt`
- `.windsurf/investigation/phase-15a-logs-repeated-run.txt`
- `.windsurf/investigation/phase-15a-logs-force-quit.txt`
- `.windsurf/investigation/phase-15a-logs-multiple-attempts.txt`
- `.windsurf/investigation/phase-15a-analysis.md`
- `.windsurf/investigation/phase-15a-decision.md`

---

## Status: Ready for Testing

The instrumentation is complete and ready for test scenarios. Run the scenarios, capture logs, and analyze using the checklist above to determine the root cause and decide on the next phase approach.
