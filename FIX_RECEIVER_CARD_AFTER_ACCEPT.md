# Fix: Receiver Card Disappearing After Accept

## Issue
When the receiver accepted a challenge and navigated to the lobby, their PlayerChallengeCard was still visible in RemoteGamesTab (showing as a challenge to accept when they'd already accepted and joined).

## Expected Behavior
1. Receiver sees pending challenge with Accept button ✅
2. Receiver clicks Accept
3. Receiver navigates to RemoteLobbyView ✅
4. **Card disappears from RemoteGamesTab** (receiver is now in the match)

## Root Cause
Two issues were causing the card to remain visible:

1. **Background reload after accept** - The `acceptChallenge()` function was triggering a background `loadMatches()` call after navigating to the lobby, which refreshed the RemoteGamesTab UI even though the receiver was no longer viewing it.

2. **No filter for activeMatch** - Even if a match was correctly classified as `activeMatch` in the service, there was no filter preventing it from also appearing in the challenge lists.

## Solution Implemented

### 1. Removed Background Reload (RemoteGamesTab.swift, lines 392-393)
**Before:**
```swift
// Step 4: Reload matches in background to update state
Task {
    do {
        print("🔄 [DEBUG] Reloading matches in background...")
        try await remoteMatchService.loadMatches(userId: currentUser.id)
        print("✅ [DEBUG] Background reload complete")
    } catch {
        print("❌ [DEBUG] Background reload failed: \(error)")
    }
}
```

**After:**
```swift
// Note: No background reload needed - receiver is navigating to lobby
// The realtime subscription will handle any updates if needed
```

**Why:** The receiver is navigating to the lobby and doesn't need to see RemoteGamesTab updates. The realtime subscription will handle any necessary updates for other users.

### 2. Added activeMatch Filters (RemoteGamesTab.swift)

**Pending Challenges (lines 159-162):**
```swift
ForEach(remoteMatchService.pendingChallenges.filter { 
    !expiredMatchIds.contains($0.id) && 
    $0.id != remoteMatchService.activeMatch?.id 
}) { matchWithPlayers in
```

**Sent Challenges (lines 203-206):**
```swift
ForEach(remoteMatchService.sentChallenges.filter { 
    !expiredMatchIds.contains($0.id) && 
    $0.id != remoteMatchService.activeMatch?.id 
}) { matchWithPlayers in
```

**Ready Matches (lines 122-125):**
```swift
ForEach(remoteMatchService.readyMatches.filter { 
    !expiredMatchIds.contains($0.id) && 
    $0.id != remoteMatchService.activeMatch?.id 
}) { matchWithPlayers in
```

**Why:** If a match is the user's `activeMatch` (they're in the lobby or playing), it shouldn't appear in any challenge lists. This provides a safety net to ensure the card never shows when the user is actively in that match.

## How It Works

**Receiver Flow:**
1. Receiver clicks Accept on pending challenge
2. `acceptChallenge()` calls edge function (pending → ready)
3. `joinMatch()` auto-joins (ready → lobby)
4. Receiver navigates to RemoteLobbyView
5. **No background reload** - receiver stays in lobby
6. If receiver somehow navigates back to RemoteGamesTab, **filter excludes the match** because it's their activeMatch

**Sender Flow (unchanged):**
1. Sender sees sent challenge with "Waiting for response"
2. Receiver accepts → realtime UPDATE callback fires ✅
3. Sender's card updates to "Match ready - [Name] accepted" ✅
4. Sender clicks Join → navigates to lobby
5. Both players in lobby → match starts

## Files Modified

1. **RemoteGamesTab.swift**
   - Removed background reload after accept (lines 392-393)
   - Added activeMatch filter to pendingChallenges (lines 159-162)
   - Added activeMatch filter to sentChallenges (lines 203-206)
   - Added activeMatch filter to readyMatches (lines 122-125)

## Testing

1. ✅ Sender creates challenge
2. ✅ Sender sees "Waiting for response" card
3. ✅ Receiver sees pending challenge with Accept button
4. Receiver clicks Accept
5. ✅ Receiver navigates to lobby (showing "Waiting for [Sender] to join...")
6. **Verify:** Receiver's card disappears from RemoteGamesTab
7. ✅ Sender's card updates to "Match ready - [Name] accepted"
8. Sender clicks Join
9. Both enter gameplay

## Status
✅ Implementation complete - Ready for testing

## Date
2026-02-21
