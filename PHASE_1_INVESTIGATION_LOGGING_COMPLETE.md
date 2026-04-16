# Phase 1: Investigation Logging Complete

## Summary
Added comprehensive logging to track voice session timing and health during the delay period when challenger doesn't join immediately after receiver accepts.

## Changes Made

### VoiceChatService.swift
Added timestamped logging for key voice session events:

1. **SESSION_START** - When voice session is created
   - Logs: timestamp, matchId
   - Location: `startSession()` method

2. **READY_SENT** - When local player sends `voice_ready` signal
   - Logs: timestamp, role (challenger/receiver), matchId
   - Location: After `sendReady()` call

3. **READY_RECEIVED** - When peer's `voice_ready` signal is received
   - Logs: timestamp, peerRole, matchId
   - Location: `handleReady()` method

4. **REQUEST_OFFER_TIMEOUT** - When receiver times out waiting for offer (5s)
   - Logs: timestamp, matchId
   - Location: `startOfferRequestTimeout()` method

### RemoteLobbyView.swift
Added logging for lobby-level voice events:

1. **LOBBY_VOICE_START** - When voice session starts in lobby onAppear
   - Logs: timestamp, role (challenger/receiver), matchId
   - Location: `onAppear` Task that starts voice session

2. **WINDOW_START** - When voice connection window officially begins
   - Logs: timestamp, voiceState, sessionAge, matchId
   - Location: After `confirmLobbyViewEntered()` when deadline is set

3. **HEALTH_CHECK** - Periodic monitoring of voice session health (every 2s)
   - Logs: sessionAge, connectionState, hasWindow, matchId
   - Location: New `startVoiceHealthMonitoring()` function
   - Runs from voice session start until voice window begins

## Log Format
All logs use the `[VoiceDelay]` prefix for easy filtering:
```
⏱️ [VoiceDelay] EVENT_NAME timestamp=ISO8601 key=value matchId=shortId
```

## Testing Instructions

### Test Scenario 1: Immediate Join (Baseline - Should Work)
1. Device A (receiver): Accept challenge
2. Device B (challenger): Join immediately (within 1-2 seconds)
3. Expected: Voice connects successfully
4. Capture logs from both devices

### Test Scenario 2: 5-Second Delay
1. Device A (receiver): Accept challenge
2. Wait 5 seconds
3. Device B (challenger): Join
4. Expected: May or may not work - capture logs
5. Look for REQUEST_OFFER_TIMEOUT log

### Test Scenario 3: 10-Second Delay
1. Device A (receiver): Accept challenge
2. Wait 10 seconds
3. Device B (challenger): Join
4. Expected: Likely fails - capture logs
5. Check HEALTH_CHECK logs for session state

### Test Scenario 4: 15-Second Delay
1. Device A (receiver): Accept challenge
2. Wait 15 seconds
3. Device B (challenger): Join
4. Expected: Likely fails - capture logs
5. Check session age when WINDOW_START occurs

### Test Scenario 5: 20+ Second Delay
1. Device A (receiver): Accept challenge
2. Wait 20+ seconds
3. Device B (challenger): Join
4. Expected: Likely fails - capture logs
5. Check if session is still in .connecting state

## What to Look For in Logs

### Receiver Device Logs
1. **LOBBY_VOICE_START** - When receiver enters lobby
2. **SESSION_START** - Voice session created
3. **READY_SENT** - Receiver sends ready signal
4. **HEALTH_CHECK** (every 2s) - Track session state during wait
5. **REQUEST_OFFER_TIMEOUT** - After 5s if no challenger
6. **WINDOW_START** - When challenger finally joins
7. **READY_RECEIVED** - If challenger's ready signal arrives

### Challenger Device Logs
1. **LOBBY_VOICE_START** - When challenger enters lobby (delayed)
2. **SESSION_START** - Voice session created
3. **READY_SENT** - Challenger sends ready signal
4. **READY_RECEIVED** - If receiver's ready signal arrives

### Key Questions to Answer
1. **At what delay duration does voice start failing?**
   - Compare success/failure across 5s, 10s, 15s, 20s delays

2. **What is the receiver's session state when challenger joins?**
   - Check HEALTH_CHECK logs right before WINDOW_START
   - Is it still `.connecting` or has it changed?

3. **Are signalling messages being delivered?**
   - Does READY_SENT on one device match READY_RECEIVED on the other?
   - Check timestamps to see message delivery timing

4. **How old is the receiver's session when the window starts?**
   - Compare SESSION_START timestamp to WINDOW_START timestamp
   - Is there a threshold where sessions become "stale"?

5. **Does the REQUEST_OFFER_TIMEOUT fire before challenger joins?**
   - If yes, does it affect the connection when challenger finally arrives?

## Next Steps

After collecting logs from test scenarios:

1. **Analyze the breaking point**
   - Identify the delay duration where voice consistently fails
   - Determine the session age threshold for staleness

2. **Identify root cause**
   - Session timeout?
   - Signalling race condition?
   - Audio session deactivation?

3. **Choose solution approach**
   - Solution A: Restart stale sessions when window starts
   - Solution B: Delay voice session start until window begins
   - Solution C: Keep-alive mechanism
   - Solution D: Resend ready signals

4. **Implement chosen solution**
   - Based on investigation findings
   - Test with same delay scenarios
   - Verify fix works across all delay durations

## Files Modified
- `DanDart/Services/VoiceChatService.swift` - Added 4 timestamped log points
- `DanDart/Views/Remote/RemoteLobbyView.swift` - Added 3 log points + health monitoring

## Lint Errors (Expected)
- `No such module 'Supabase'` - Build-time error, will resolve on compile
- `Cannot find 'TypingIndicator' in scope` - From previous changes, unrelated to this investigation

## Status
✅ Phase 1 (Investigation & Logging) - COMPLETE
⏳ Phase 2 (Implement Solution) - PENDING (awaiting test results)
⏳ Phase 3 (Verification) - PENDING
