# Sent Challenge Client-Side Expiry Fix

## Problem
Sent challenges (challenger's view) were not disappearing immediately when the timer reached zero. Instead, they remained visible with a `00:00` timer for up to 44 seconds until the server UPDATE event arrived to mark them as expired.

### Observed Behavior
From challenger logs:
- Challenge created at `18:21:46`
- Expires at `18:22:16` (30 seconds later)
- Timer shows `00:00` starting at `18:22:15`
- Timer continues ticking at `00:00` for ~45 seconds
- Server UPDATE arrives at `18:23:00` (44 seconds after expiry!)
- Only then does the card transition to expired state and fade out

### Root Cause
Sent challenge cards relied entirely on the server UPDATE event to detect expiry. The `isExpired` computed property only re-evaluated when the underlying match data changed (via server events), not based on real-time client-side time checks.

While the `TimelineView` updated the timer display every second, it didn't trigger expiry detection. The `.onChange(of: isExpired)` handler only fired when the server sent an UPDATE changing the match status.

## Solution
Added **client-side expiry monitoring** for sent challenges using `TimelineView` to actively check expiry every second.

### Implementation

**File: `RemoteGamesTab.swift`**

1. **Wrapped sent challenge cards in TimelineView** (lines 241-274):
   - Periodic timeline updates every 1 second
   - Calls `checkClientSideExpiry()` on each tick
   - Immediately detects when `currentTime > challengeExpiresAt`
   - Triggers `handleExpiration()` without waiting for server

2. **Added `checkClientSideExpiry()` helper** (lines 1404-1420):
   ```swift
   private func checkClientSideExpiry(for match: RemoteMatchWithPlayers, at currentTime: Date) -> Bool {
       guard let expiresAt = match.match.challengeExpiresAt else {
           return false
       }
       
       let isExpired = currentTime > expiresAt
       
       if isExpired && !expiredMatchIds.contains(match.id) {
           print("⏰ [ClientExpiry] Sent challenge expired - matchId=\(match.match.id.uuidString.prefix(8)) expiresAt=\(expiresAt) now=\(currentTime)")
       }
       
       return isExpired
   }
   ```

### How It Works
1. **Every second**, the `TimelineView` provides the current time
2. **Client checks** if `currentTime > challengeExpiresAt`
3. **If expired**, `isExpiredNow` becomes `true`
4. **`.onChange(of: isExpiredNow)`** fires immediately
5. **`handleExpiration()`** triggers the fade-out animation
6. **Card disappears** within 1 second of expiry, regardless of server timing

### Expected Behavior After Fix
- Challenge created at `18:21:46`
- Expires at `18:22:16`
- Timer shows `00:00` at `18:22:15`
- **Client detects expiry at `18:22:16` or `18:22:17` (within 1 second)**
- **Card immediately fades out**
- Server UPDATE may arrive later at `18:23:00`, but card is already gone

## Testing
To verify the fix:
1. Challenger creates a challenge
2. Let it expire without receiver accepting
3. Observe that the card disappears within 1-2 seconds of timer reaching `00:00`
4. Confirm no long delay waiting for server UPDATE

## Related Files
- `DanDart/Views/Remote/RemoteGamesTab.swift` - Main fix location
- `DanDart/Models/RemoteMatch.swift` - Contains `isExpired` computed property (server-based)
- `DanDart/Views/Components/PlayerChallengeCard.swift` - Card component with timer display

## Notes
- This fix only applies to **sent challenges** (challenger's view)
- **Incoming challenges** (receiver's view) already had client-side expiry working correctly
- The server UPDATE event still arrives and updates the database status, but the UI no longer waits for it
- This is a **client-side UX improvement** that doesn't change server behavior
