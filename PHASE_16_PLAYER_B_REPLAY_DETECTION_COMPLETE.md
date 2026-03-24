# Phase 16: Player B Replay Overlay Detection - Implementation Complete

**Date:** March 23, 2026  
**Status:** ✅ Implementation Complete

## Problem Fixed

Player B didn't see the replay overlay when Player A sent a replay request because `EndGameViewRemote` only tracked replays initiated by the current user and didn't scan for incoming replay requests.

## Solution Implemented

Added two dedicated replay columns to the matches table, updated the authoritative edge function to accept replay parameters, and added both initial scan + onChange monitoring in `EndGameViewRemote` to detect incoming replay requests.

## Changes Made

### 1. Database Migration (083_add_replay_columns.sql)

**File:** `supabase_migrations/083_add_replay_columns.sql`

Added two columns to the `matches` table:
- `is_replay BOOLEAN NOT NULL DEFAULT false` - Marks if this is a replay/rematch request
- `replay_source_match_id UUID` - References the completed match being replayed
- Foreign key constraint with `ON DELETE SET NULL`
- Index on `replay_source_match_id` for efficient queries

### 2. Edge Function Update (create-challenge)

**File:** `supabase/functions/create-challenge/index.ts`

Updated request parsing to accept optional replay parameters:
```typescript
const { 
    receiver_id, 
    game_type, 
    match_format,
    is_replay,              // NEW - optional
    replay_source_match_id  // NEW - optional
} = await req.json()
```

Updated matchData object to include replay fields:
```typescript
const matchData = {
    // ... existing fields ...
    is_replay: is_replay ?? false,
    replay_source_match_id: replay_source_match_id,
}
```

### 3. RemoteMatchService Update

**File:** `DanDart/Services/RemoteMatchService.swift`

Added replay parameters to `createChallenge()` method:
```swift
func createChallenge(
    receiverId: UUID,
    gameType: String,
    matchFormat: Int,
    currentUserId: UUID,
    isReplay: Bool = false,
    replaySourceMatchId: UUID? = nil
) async throws -> UUID
```

Updated `CreateChallengeRequest` struct:
```swift
struct CreateChallengeRequest: Encodable {
    let receiver_id: String
    let game_type: String
    let match_format: Int
    let is_replay: Bool?
    let replay_source_match_id: String?
}
```

### 4. RemoteMatch Model Update

**File:** `DanDart/Models/RemoteMatch.swift`

Added optional replay fields for safe migration:
```swift
// Replay fields (optional for safe migration)
let isReplay: Bool?
let replaySourceMatchId: UUID?
```

Updated CodingKeys:
```swift
case isReplay = "is_replay"
case replaySourceMatchId = "replay_source_match_id"
```

### 5. EndGameViewRemote - Player A Update

**File:** `DanDart/Views/Games/Remote/EndGameViewRemote.swift`

Updated `createReplayRequest()` to pass replay parameters:
```swift
let matchId = try await remoteMatchService.createChallenge(
    receiverId: opponent.id,
    gameType: game.title,
    matchFormat: matchFormat ?? 1,
    currentUserId: currentUserId,
    isReplay: true,
    replaySourceMatchId: self.matchId
)
```

### 6. EndGameViewRemote - Player B Detection

**File:** `DanDart/Views/Games/Remote/EndGameViewRemote.swift`

Added dual detection mechanism:

**Initial scan on onAppear:**
```swift
.onAppear {
    // ... existing code ...
    
    // Scan for incoming replay requests (Player B detection)
    scanForIncomingReplayRequest()
}
```

**onChange listener for new requests:**
```swift
.onChange(of: remoteMatchService.pendingChallenges) { _, _ in
    scanForIncomingReplayRequest()
}
```

**Idempotent detection helper:**
```swift
private func scanForIncomingReplayRequest() {
    guard let opponent = opponent else { return }
    guard let currentMatchId = matchId else { return }
    
    // Search the FULL pendingChallenges array (not just delta)
    for challengeWithPlayers in remoteMatchService.pendingChallenges {
        let match = challengeWithPlayers.match
        
        // Check 1: Is it from the opponent we just played?
        guard match.challengerId == opponent.id else { continue }
        
        // Check 2: Is it marked as a replay?
        guard match.isReplay == true else { continue }
        
        // Check 3: Does it reference this match?
        guard match.replaySourceMatchId == currentMatchId else { continue }
        
        // Found incoming replay request!
        handleIncomingReplayRequest(matchId: match.id, match: match)
        return
    }
}
```

**Idempotent handler:**
```swift
private func handleIncomingReplayRequest(matchId: UUID, match: RemoteMatch) {
    // Idempotency check 1: Already showing this replay?
    if replayMatchId == matchId && showReplayOverlay {
        return
    }
    
    // Idempotency check 2: Already set to this match?
    if replayMatchId == matchId {
        return
    }
    
    replayMatchId = matchId
    replayMatch = match
    
    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
        showReplayOverlay = true
    }
    
    // Success haptic
    #if canImport(UIKit)
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
    #endif
}
```

## Key Features

✅ **Player B sees replay overlay automatically** when Player A sends request  
✅ **Replay requests distinguished from regular challenges** via dedicated columns  
✅ **Preserves original match context** with `replay_source_match_id` reference  
✅ **Reuses existing PlayerChallengeCard** and overlay UI  
✅ **No breaking changes** to existing challenge flow  
✅ **Follows authoritative edge function path** - no client-side shortcuts  
✅ **Strongly-typed, compile-time safe** - no JSONB parsing needed  
✅ **Efficient queries** with dedicated index on `replay_source_match_id`  
✅ **Clear database schema** - replay is first-class match state  
✅ **Idempotent detection** - safe to call multiple times  
✅ **Catches timing edge cases** - onAppear scan + onChange monitoring  

## Detection Logic

Player B's detection uses three strict checks to avoid false positives:
1. Challenge is from the opponent (not a different user)
2. Challenge has `isReplay == true` (not a regular challenge)
3. Challenge references the current match ID (not a replay of a different match)

## Idempotency Strategy

- `scanForIncomingReplayRequest()` searches full array, safe to call multiple times
- `handleIncomingReplayRequest()` checks if already showing this replay
- Both onAppear and onChange call the same idempotent helper

## Testing Checklist

- [ ] Run migration 083 to add replay columns
- [ ] Deploy updated create-challenge edge function
- [ ] Player A creates replay request → edge function stores `isReplay=true` and `replaySourceMatchId`
- [ ] Database stores replay columns correctly
- [ ] `RemoteMatch` model decodes optional replay fields from database
- [ ] Player B's `RemoteMatchService.pendingChallenges` updates with new replay (via realtime)
- [ ] Player B's `EndGameViewRemote.onAppear` scans for existing replay requests
- [ ] Player B's `EndGameViewRemote.onChange` detects new replay requests
- [ ] Player B sees overlay with `.pending` state card showing opponent
- [ ] Idempotency: Multiple scans don't duplicate overlay
- [ ] Player B can accept the replay request → navigates to lobby
- [ ] Player B can decline the replay request → overlay dismisses
- [ ] Player A sees card update to `.ready` state after Player B accepts
- [ ] Existing non-replay challenges still work normally (no regression)
- [ ] Foreign key constraint works (replay_source_match_id references valid match)

## Files Modified

1. **NEW:** `supabase_migrations/083_add_replay_columns.sql`
2. `supabase/functions/create-challenge/index.ts`
3. `DanDart/Services/RemoteMatchService.swift`
4. `DanDart/Models/RemoteMatch.swift`
5. `DanDart/Views/Games/Remote/EndGameViewRemote.swift`

## Next Steps

1. Run the database migration in Supabase
2. Deploy the updated edge function
3. Test the replay flow with two devices
4. Verify Player B sees the overlay automatically
5. Verify the existing challenge flow still works

## Implementation Notes

**Why dedicated columns over JSONB:**
- Replay is first-class match state, not optional metadata
- Enables efficient indexed queries
- Provides compile-time type safety
- Clearer database schema and semantics
- No need for AnyCodable or JSONB parsing
- Simpler to query and reason about

**Why follow edge function path:**
- Maintains server-authoritative challenge creation
- Replay fields validated and stored by server
- No client-side database writes
- Consistent with existing remote match architecture

**Why two columns (not three):**
- `is_replay` - Fast boolean check for filtering
- `replay_source_match_id` - Links to original match for context
- `replay_initiator_id` is optional and not required for core bug fix
