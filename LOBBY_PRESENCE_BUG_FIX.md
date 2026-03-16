# Lobby Presence Bug Fix - Both Players Stuck in "Waiting for Opponent"

## Problem Summary

Both players successfully entered the lobby and the server correctly populated all lobby presence fields, but both clients remained stuck showing "Waiting for [opponent] to join..." instead of displaying the countdown.

## Root Cause Analysis

The issue had **three interconnected problems**:

### 1. Missing Fields in Decoder
**File**: `RemoteMatchService.swift` - `MatchResponse` struct
- The decoder was missing the 4 new lobby presence fields
- When fetching match data, these fields were silently ignored
- Result: `RemoteMatch` objects always had `nil` for lobby fields

### 2. Missing Fields in Equatable
**File**: `RemoteMatch.swift` - `Equatable` implementation
- The `==` operator didn't compare lobby presence fields
- When server updated lobby timestamps, client thought nothing changed
- Result: `flowMatch` update was skipped with "flowMatch unchanged, skipping update"

### 3. Missing Fields in Initializer
**File**: `RemoteMatchService.swift` - `RemoteMatch` initializer
- Even if decoded, fields weren't passed to `RemoteMatch` constructor
- Result: Lobby fields were always `nil` in the final object

## Fixes Applied

### Fix 1: Add Fields to MatchResponse Decoder
**File**: `DanDart/Services/RemoteMatchService.swift` (lines 499-502)

```swift
struct MatchResponse: Decodable {
    // ... existing fields ...
    let challenger_lobby_joined_at: String?  // 🆕 Lobby presence tracking
    let receiver_lobby_joined_at: String?  // 🆕 Lobby presence tracking
    let lobby_countdown_started_at: String?  // 🆕 Lobby countdown tracking
    let lobby_countdown_seconds: Int?  // 🆕 Lobby countdown duration
    // ... rest of fields ...
}
```

### Fix 2: Add Fields to Equatable Comparison
**File**: `DanDart/Models/RemoteMatch.swift` (lines 109-112)

```swift
static func == (lhs: RemoteMatch, rhs: RemoteMatch) -> Bool {
    lhs.id == rhs.id &&
    lhs.status == rhs.status &&
    // ... existing comparisons ...
    lhs.challengerLobbyJoinedAt == rhs.challengerLobbyJoinedAt &&
    lhs.receiverLobbyJoinedAt == rhs.receiverLobbyJoinedAt &&
    lhs.lobbyCountdownStartedAt == rhs.lobbyCountdownStartedAt &&
    lhs.lobbyCountdownSeconds == rhs.lobbyCountdownSeconds
}
```

### Fix 3: Add Fields to RemoteMatch Initializer
**File**: `DanDart/Services/RemoteMatchService.swift` (lines 578-581)

```swift
let match = RemoteMatch(
    // ... existing fields ...
    challengerLobbyJoinedAt: matchData.challenger_lobby_joined_at.flatMap { formatter.date(from: $0) },
    receiverLobbyJoinedAt: matchData.receiver_lobby_joined_at.flatMap { formatter.date(from: $0) },
    lobbyCountdownStartedAt: matchData.lobby_countdown_started_at.flatMap { formatter.date(from: $0) },
    lobbyCountdownSeconds: matchData.lobby_countdown_seconds,
    // ... rest of fields ...
)
```

### Fix 4: Add Debug Logging
**File**: `DanDart/Services/RemoteMatchService.swift` (lines 552-555)

```swift
print("🧪 [fetchMatch DECODED] challenger_lobby_joined_at=\(matchData.challenger_lobby_joined_at ?? "nil")")
print("🧪 [fetchMatch DECODED] receiver_lobby_joined_at=\(matchData.receiver_lobby_joined_at ?? "nil")")
print("🧪 [fetchMatch DECODED] lobby_countdown_started_at=\(matchData.lobby_countdown_started_at ?? "nil")")
print("🧪 [fetchMatch DECODED] lobby_countdown_seconds=\(matchData.lobby_countdown_seconds?.description ?? "nil")")
```

### Fix 5: Enhanced flowMatch Comparison Logging
**File**: `DanDart/Services/RemoteMatchService.swift` (lines 600-611)

```swift
if self.flowMatch != match {
    print("🎯 [Flow] flowMatch CHANGED - updating")
    print("🔍 [Flow] Old: challengerLobby=\(old), receiverLobby=\(old), countdown=\(old)")
    print("🔍 [Flow] New: challengerLobby=\(new), receiverLobby=\(new), countdown=\(new)")
    self.flowMatch = match
} else {
    print("⏭️ [Flow] flowMatch unchanged, skipping update")
    print("🔍 [Flow] Comparison: challengerLobby=..., receiverLobby=..., countdown=...")
}
```

### Fix 6: Update RemoteLobbyView Logic
**File**: `DanDart/Views/Remote/RemoteLobbyView.swift` (line 60)

```swift
private var isBothPlayersReady: Bool {
    matchStatus == .inProgress || (matchStatus == .lobby && bothPlayersPresent)
}
```

### Fix 7: Add Countdown Display
**File**: `DanDart/Views/Remote/RemoteLobbyView.swift` (lines 183-205)

```swift
// Countdown timer when in lobby
if matchStatus == .lobby && countdownActive {
    TimelineView(.periodic(from: .now, by: 0.5)) { context in
        let remaining = countdownRemaining
        let elapsed = remaining <= 0
        
        Text(formattedCountdown)
            .font(.system(size: 64, weight: .black, design: .monospaced))
            .foregroundColor(AppColor.interactivePrimaryBackground)
            .onChange(of: elapsed) { _, isElapsed in
                if isElapsed && matchStatus == .lobby && bothPlayersPresent {
                    Task {
                        try await remoteMatchService.startMatchIfReady(matchId: match.id)
                    }
                }
            }
    }
}
```

## Expected Behavior After Fix

### Before Fix:
1. Player 1 enters lobby → "Waiting for Player 2 to join..."
2. Player 2 enters lobby → **BOTH** still show "Waiting for [opponent] to join..."
3. Server has correct data but clients don't detect the change
4. Players stuck forever

### After Fix:
1. Player 1 enters lobby → "Waiting for Player 2 to join..."
2. Player 2 enters lobby → **BOTH** show "Players Ready", "MATCH STARTING", countdown: **5**
3. Countdown ticks: **4, 3, 2, 1**
4. At **0**: Both clients call `start-match-if-ready`
5. Server validates and transitions to `in_progress`
6. Both clients navigate to gameplay

## Debug Log Evidence

### Before Fix:
```
🧪 [fetchMatch DECODED] status=lobby
🧪 [fetchMatch DECODED] current_player_id=nil
⏭️ [Flow] flowMatch unchanged, skipping update
```

### After Fix (Expected):
```
🧪 [fetchMatch DECODED] status=lobby
🧪 [fetchMatch DECODED] challenger_lobby_joined_at=2026-03-16T10:49:26.675+00:00
🧪 [fetchMatch DECODED] receiver_lobby_joined_at=2026-03-16T10:49:21.891+00:00
🧪 [fetchMatch DECODED] lobby_countdown_started_at=2026-03-16T10:49:26.675+00:00
🧪 [fetchMatch DECODED] lobby_countdown_seconds=5
🎯 [Flow] flowMatch CHANGED - updating
🔍 [Flow] Old: challengerLobby=false, receiverLobby=false, countdown=false
🔍 [Flow] New: challengerLobby=true, receiverLobby=true, countdown=true
```

## Files Modified

1. `DanDart/Models/RemoteMatch.swift` - Added lobby fields to Equatable
2. `DanDart/Services/RemoteMatchService.swift` - Added fields to decoder, initializer, and debug logs
3. `DanDart/Views/Remote/RemoteLobbyView.swift` - Updated UI logic and added countdown display

## Testing Checklist

- [ ] Both players enter lobby
- [ ] Both see "Players Ready" and countdown
- [ ] Countdown displays: 5, 4, 3, 2, 1
- [ ] At 0, both clients call `start-match-if-ready`
- [ ] Match transitions to `in_progress`
- [ ] Both clients navigate to gameplay
- [ ] Voice chat continues working during countdown
- [ ] Logs show lobby fields being decoded and compared

## Related Issues Fixed

This fix also resolves the underlying issue where any future lobby-related fields would be silently ignored by the client's change detection system.
