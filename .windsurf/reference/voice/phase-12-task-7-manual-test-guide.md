# Phase 12 Task 7: Manual Testing Guide
## Two-Device Signalling Verification

## Overview

This guide walks through manual testing of the Supabase Realtime signalling implementation using two physical devices or simulator instances.

---

## Prerequisites

### Hardware/Software Setup

**Option A: Two Physical Devices**
- iPhone/iPad 1 with DanDarts installed
- iPhone/iPad 2 with DanDarts installed
- Both connected to internet
- Xcode console access for logs (optional but recommended)

**Option B: Two Simulators**
- Xcode with two simulator instances
- Simulator 1: iPhone 15 Pro (or similar)
- Simulator 2: iPhone 15 Pro (or similar)
- Both running simultaneously

**Option C: One Device + One Simulator**
- Physical device with DanDarts
- Simulator with DanDarts
- Both connected to internet

### User Accounts

**Required:**
- User A account (for Device 1)
- User B account (for Device 2)
- Both users must be friends in the app

**Setup:**
1. Create/login as User A on Device 1
2. Create/login as User B on Device 2
3. Add each other as friends (if not already)

---

## Test Execution Steps

### Step 1: Prepare Devices

**Device 1 (Challenger):**
1. Launch DanDarts
2. Sign in as User A
3. Navigate to Friends tab
4. Locate User B in friends list

**Device 2 (Receiver):**
1. Launch DanDarts
2. Sign in as User B
3. Stay on any tab (will receive challenge notification)

### Step 2: Enable Console Logging

**If using Xcode:**
1. Run app on Device 1 from Xcode
2. Open Console (Cmd+Shift+C)
3. Filter for "VoiceService" or "Signalling"
4. Repeat for Device 2 in separate Xcode window

**If using physical devices:**
1. Connect Device 1 to Mac
2. Open Console.app
3. Select Device 1
4. Filter for "DanDart"
5. Repeat for Device 2

### Step 3: Create Remote Match Challenge

**Device 1:**
1. Tap User B in friends list
2. Tap "Challenge to Remote Match"
3. Select game type (301 or 501)
4. Tap "Send Challenge"
5. Wait for challenge to be sent

**Expected Logs (Device 1):**
```
📤 [RemoteMatch] Sending challenge to User B...
✅ [RemoteMatch] Challenge sent successfully
```

### Step 4: Accept Challenge

**Device 2:**
1. Notification appears: "User A challenged you!"
2. Tap notification (or navigate to Friends → Challenges)
3. Tap "Accept" on challenge card
4. Wait for accept to process

**Expected Logs (Device 2):**
```
📥 [RemoteMatch] Accepting challenge from User A...
✅ [RemoteMatch] Challenge accepted
🎤 [VoiceService] Starting session for match {matchId}...
✅ [VoiceService] Session created - token: {token}...
🔊 [Signalling] Subscribing to channel: voice:match:{matchId}
✅ [Signalling] Subscribed to channel: voice:match:{matchId}
🎤 [VoiceService] State: connecting
```

### Step 5: Verify Voice Session on Device 1

**Device 1:**
- Automatically navigates to RemoteLobbyView
- Voice session should start automatically

**Expected Logs (Device 1):**
```
🎤 [VoiceService] Starting session for match {matchId}...
✅ [VoiceService] Session created - token: {token}...
🔊 [Signalling] Subscribing to channel: voice:match:{matchId}
✅ [Signalling] Subscribed to channel: voice:match:{matchId}
🎤 [VoiceService] State: connecting
```

### Step 6: Verify Channel Names Match

**Compare Logs:**
- Device 1 channel: `voice:match:{matchId}`
- Device 2 channel: `voice:match:{matchId}`
- **Both should have identical matchId**

**✅ PASS:** Channel names match  
**❌ FAIL:** Channel names differ (different matches)

### Step 7: Verify Both in Lobby

**Device 1:**
- Shows RemoteLobbyView
- Displays "Waiting for opponent..."
- Shows countdown timer

**Device 2:**
- Shows RemoteLobbyView
- Displays "Waiting for opponent..."
- Shows countdown timer

**Both devices should show:**
- Same match information
- Same opponent name
- Countdown timer (synchronized)

### Step 8: Cancel Match

**Device 1:**
1. Tap "Cancel" button in lobby
2. Confirm cancellation

**Expected Logs (Device 1):**
```
🎤 [VoiceService] Ending session - token: {token}...
🔊 [Signalling] Unsubscribing from channel
✅ [Signalling] Unsubscribed from channel
✅ [VoiceService] Session ended
```

**Expected Logs (Device 2):**
```
📥 [RemoteMatch] Match cancelled by opponent
🎤 [VoiceService] Ending session - token: {token}...
🔊 [Signalling] Unsubscribing from channel
✅ [Signalling] Unsubscribed from channel
✅ [VoiceService] Session ended
```

### Step 9: Verify Cleanup

**Both Devices:**
- Return to previous screen (Friends tab)
- No active voice session
- No active channel subscription

**Check Logs:**
- No ongoing signalling activity
- Channel unsubscribed
- Session ended

---

## Verification Checklist

### ✅ Voice Session Lifecycle

**Device 1 (Challenger):**
- [ ] Voice session starts when entering lobby
- [ ] Session token generated (unique UUID)
- [ ] Match ID matches remote match
- [ ] State transitions: idle → preparing → connecting
- [ ] Channel subscription successful
- [ ] Channel name format: `voice:match:{matchId}`
- [ ] Session ends when match cancelled
- [ ] Channel unsubscription successful
- [ ] State transitions: connecting → ended

**Device 2 (Receiver):**
- [ ] Voice session starts when accepting challenge
- [ ] Session token generated (unique UUID)
- [ ] Match ID matches remote match
- [ ] State transitions: idle → preparing → connecting
- [ ] Channel subscription successful
- [ ] Channel name format: `voice:match:{matchId}`
- [ ] Session ends when match cancelled
- [ ] Channel unsubscription successful
- [ ] State transitions: connecting → ended

### ✅ Channel Synchronization

- [ ] Both devices subscribe to same channel name
- [ ] Channel name contains same matchId
- [ ] Both devices show "Subscribed to channel" log
- [ ] Subscription happens within 1-2 seconds of lobby entry

### ✅ Logging

**Device 1 Logs:**
- [ ] "Starting session for match..." appears
- [ ] "Session created - token:..." appears
- [ ] "Subscribing to channel:..." appears
- [ ] "Subscribed to channel:..." appears
- [ ] "State: connecting" appears
- [ ] "Ending session - token:..." appears (on cancel)
- [ ] "Unsubscribing from channel" appears (on cancel)
- [ ] "Unsubscribed from channel" appears (on cancel)
- [ ] "Session ended" appears (on cancel)

**Device 2 Logs:**
- [ ] Same logs as Device 1
- [ ] Logs appear in same sequence
- [ ] No error messages

### ✅ Error Handling

- [ ] No crashes on either device
- [ ] No "Failed to subscribe" errors
- [ ] No "Failed to unsubscribe" errors
- [ ] No "Invalid session token" warnings (during normal flow)
- [ ] No "Invalid match ID" warnings (during normal flow)

---

## Common Issues and Solutions

### Issue: Channel subscription fails

**Symptoms:**
- Log shows "❌ [Signalling] Failed to subscribe"
- State stays at `.preparing`
- No channel subscription log

**Solutions:**
1. Check internet connection on both devices
2. Verify Supabase Realtime is enabled in project
3. Check Supabase project status (not paused)
4. Restart app and try again

### Issue: Different channel names

**Symptoms:**
- Device 1: `voice:match:abc123...`
- Device 2: `voice:match:def456...`
- Different matchIds

**Solutions:**
1. Verify both devices are in same match
2. Check match ID in RemoteLobbyView
3. Ensure accept flow completed successfully
4. Check for race conditions in accept logic

### Issue: Session doesn't end on cancel

**Symptoms:**
- Cancel button pressed
- No "Ending session" log
- Channel still subscribed

**Solutions:**
1. Check `endSession()` is called in cancel flow
2. Verify `exitRemoteFlow()` triggers session end
3. Check for exceptions in cleanup code
4. Restart app

### Issue: Logs not appearing

**Symptoms:**
- No voice or signalling logs
- App seems to work but no logging

**Solutions:**
1. Check console filter settings
2. Verify log level allows print statements
3. Try filtering for "🎤" or "🔊" emoji
4. Check device is selected in Console.app

---

## Expected Results Summary

### ✅ Success Criteria

**All of the following must be true:**

1. **Session Creation**
   - Both devices create voice session
   - Unique session tokens generated
   - Match IDs match

2. **Channel Subscription**
   - Both devices subscribe to same channel
   - Channel name format correct
   - Subscription successful within 2 seconds

3. **State Transitions**
   - Both: idle → preparing → connecting
   - No errors during transitions

4. **Logging**
   - All expected logs appear
   - No error messages
   - Sequence correct

5. **Cleanup**
   - Both devices unsubscribe on cancel
   - Sessions end properly
   - No lingering subscriptions

### ❌ Failure Indicators

**Any of the following indicates failure:**

- Crash on either device
- Subscription failure
- Different channel names
- Missing logs
- Error messages in console
- Session doesn't end on cancel
- Channel doesn't unsubscribe

---

## Test Results Template

Copy this template and fill in results:

```
# Task 7 Manual Test Results

**Date:** {date}
**Tester:** {name}
**Devices:** {device1} + {device2}

## Test Execution

### Device 1 (Challenger)
- User: {userA}
- Device: {device}
- iOS Version: {version}

### Device 2 (Receiver)
- User: {userB}
- Device: {device}
- iOS Version: {version}

## Results

### Voice Session Lifecycle
- [ ] PASS / [ ] FAIL - Session starts on both devices
- [ ] PASS / [ ] FAIL - Session tokens generated
- [ ] PASS / [ ] FAIL - State transitions correct
- [ ] PASS / [ ] FAIL - Session ends on cancel

### Channel Synchronization
- [ ] PASS / [ ] FAIL - Same channel name on both
- [ ] PASS / [ ] FAIL - Subscription successful
- [ ] PASS / [ ] FAIL - Unsubscription successful

### Logging
- [ ] PASS / [ ] FAIL - All expected logs present
- [ ] PASS / [ ] FAIL - No error messages
- [ ] PASS / [ ] FAIL - Correct sequence

### Overall Result
- [ ] PASS - All tests passed
- [ ] FAIL - One or more tests failed

## Notes

{any observations, issues, or comments}

## Logs

**Device 1:**
```
{paste relevant logs}
```

**Device 2:**
```
{paste relevant logs}
```
```

---

## Next Steps

### If All Tests Pass ✅

1. Mark Task 7 as complete
2. Commit test results
3. Proceed to Sub-phase C: Voice Engine
   - Task 8: Configure AVAudioSession
   - Task 9: Implement WebRTC peer connection
   - Task 10: Handle ICE negotiation

### If Tests Fail ❌

1. Document failure details
2. Review logs for error messages
3. Fix identified issues
4. Re-run tests
5. Repeat until all tests pass

---

## Summary

This manual test verifies:

- ✅ Voice session lifecycle works
- ✅ Supabase Realtime channel subscription works
- ✅ Both devices synchronize on same channel
- ✅ Session cleanup works correctly
- ✅ Logging is comprehensive and correct

**Ready to test!** Follow the steps above and verify all checkboxes pass.
