# Fix: Receiver Card Showing inProgress Before Navigation

## Issue
When the receiver clicked Accept, their card was changing to "inProgress" state (showing Resume button) instead of navigating directly to the lobby.

## Root Cause
The card showing "inProgress" was coming from the **Active Match section** in RemoteGamesTab, not from the challenge lists.

**What was happening:**
1. Receiver clicks Accept
2. `acceptChallenge()` executes (pending → ready)
3. `joinMatch()` executes (ready → in_progress)
4. **Realtime UPDATE callback fires**
5. `loadMatches()` runs → match classified as `activeMatch`
6. **Active Match section renders** with state `.inProgress` (Resume button)
7. Navigation to lobby happens (too late - user already saw the card)

The filters we previously added (`$0.id != remoteMatchService.activeMatch?.id`) only filtered the challenge lists (pending/sent/ready), NOT the Active Match section itself.

## Solution Implemented

**One-line fix:** Added `processingMatchId == nil` check to the Active Match section condition.

**File Modified:** `RemoteGamesTab.swift` (line 243-244)

**Before:**
```swift
// Active match (in progress, dimmed when match ready)
if let activeMatch = remoteMatchService.activeMatch {
    VStack(alignment: .leading, spacing: 12) {
        sectionHeader("Active Match", systemImage: "play.circle.fill", color: .blue)
        PlayerChallengeCard(...)
    }
}
```

**After:**
```swift
// Active match (in progress, dimmed when match ready)
if let activeMatch = remoteMatchService.activeMatch,
   processingMatchId == nil {
    VStack(alignment: .leading, spacing: 12) {
        sectionHeader("Active Match", systemImage: "play.circle.fill", color: .blue)
        PlayerChallengeCard(...)
    }
}
```

## How It Works

**Receiver Flow:**
1. Receiver clicks Accept
2. `processingMatchId = matchId` (line 346)
3. Card disappears from pending challenges (already filtered by activeMatch)
4. `joinMatch()` executes → match becomes `in_progress`
5. Realtime fires → `loadMatches()` → match becomes `activeMatch`
6. **Active Match section doesn't render** (because `processingMatchId != nil`)
7. Navigation to lobby completes
8. `processingMatchId = nil` (line 375, but user is already in lobby)

**Result:** Receiver never sees the Active Match card with Resume button - they navigate directly to lobby.

**Sender Flow (unchanged):**
1. Sender sees "Waiting for response" ✅
2. Receiver accepts → realtime fires
3. Sender's card updates to "Match ready - [Name] accepted" ✅
4. Sender clicks Join → navigates to lobby ✅

## Expected Behavior After Fix

**Receiver:**
1. Sees pending challenge with Accept button ✅
2. Clicks Accept
3. **Card disappears immediately** (no state change visible) ✅
4. **Navigates directly to lobby** ✅
5. Waits for sender to join ✅

**Sender:**
1. Sees sent challenge with "Waiting for response" ✅
2. Card updates to "Match ready - [Name] accepted" ✅
3. Clicks Join → enters lobby ✅
4. Both players in lobby → match starts ✅

## Files Modified

1. **RemoteGamesTab.swift** (line 243-244)
   - Added `processingMatchId == nil` condition to Active Match section

## Testing

1. ✅ Receiver sees pending challenge
2. Receiver clicks Accept
3. **Verify:** Card disappears immediately (no intermediate states)
4. **Verify:** Receiver navigates directly to lobby
5. **Verify:** No "Resume" button shown
6. ✅ Sender's card updates to "Match ready"
7. Sender clicks Join
8. ✅ Both in lobby

## Status
✅ Implementation complete - Ready for testing

## Date
2026-02-22
