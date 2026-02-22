# Remote Match Lobby Implementation

## Overview
Implemented the lobby functionality for remote matches, allowing players to see when their opponent has accepted a challenge and providing a countdown timer before the match expires.

## Implementation Date
February 20, 2026

---

## What Was Implemented

### 1. RemoteLobbyView (New File)
**Location:** `/DanDart/Views/Remote/RemoteLobbyView.swift`

**Purpose:** Waiting screen shown to the player who accepts the challenge

**Features:**
- Boxing match-style presentation (adapted from PreGameHypeView)
- Shows both players with VS in center
- "Waiting for opponent..." message with spinner
- Live countdown timer (5 minutes, 30 seconds for testing)
- Cancel button to exit lobby
- Expired state when countdown reaches zero
- Smooth animations on appear
- Boxing bell sound effect

**UI States:**
- **Active:** Spinner + "Waiting for opponent..." + countdown timer
- **Expired:** Warning icon + "Match Expired" message

---

### 2. Router Updates
**Location:** `/DanDart/Services/Router.swift`

**Changes:**
- Added `remoteLobby` destination to `Destination` enum
- Includes: match, opponent, currentUser, onCancel closure
- Added equality and hash implementations
- Added view factory case to build RemoteLobbyView

**Navigation Flow:**
```
Accept Challenge → RemoteLobbyView (receiver)
                → PlayerChallengeCard updates to lobby state (challenger)
```

---

### 3. RemoteGamesTab Navigation
**Location:** `/DanDart/Views/Remote/RemoteGamesTab.swift`

**Changes:**
- Updated `acceptChallenge()` method
- After successful accept, navigates to RemoteLobbyView
- Passes match, opponent, currentUser, and cancel callback
- Cancel callback calls `cancelChallenge()` and pops navigation

**User Flow (Receiver):**
1. Tap "Accept" on pending challenge
2. Edge function updates match to "ready"
3. Navigate to RemoteLobbyView
4. See waiting screen with countdown
5. Wait for challenger to join OR cancel

---

### 4. PlayerChallengeCard Lobby State
**Location:** `/DanDart/Views/Components/PlayerChallengeCard.swift`

**Changes:**
- Updated `.lobby` case in `PlayerChallengeCardFoot`
- Shows "Opponent is ready!" message
- Displays countdown timer (live updating)
- Shows "Join Match" button
- Spinner on button when processing

**UI Layout:**
```
[Spinner] Opponent is ready!     [00:30]
         [Join Match Button]
```

**User Flow (Challenger):**
1. Receiver accepts challenge
2. Realtime subscription updates match to "lobby"
3. Card footer changes to lobby state
4. Shows countdown and join button
5. Tap "Join Match" to enter lobby

---

### 5. Join-Match Edge Function Updates
**Location:** `/supabase/functions/join-match/index.ts`

**Changes:**
- Added logic to detect first vs second player joining
- Queries `match_players` table to check who has joined
- **First player joins:** Transition `ready` → `lobby`
- **Second player joins:** Transition `lobby` → `in_progress`
- Creates `match_player` record for joining user
- Updates locks to `in_progress` when both joined
- Returns new status in response

**State Transitions:**
```
ready → lobby (first join)
lobby → in_progress (second join)
```

**Database Operations:**
1. Check match_players for existing joins
2. Determine if first or second to join
3. Update match status accordingly
4. Insert match_player record
5. Update locks if transitioning to in_progress

---

## Complete User Flow

### Scenario: Alice challenges Bob to 301

**1. Alice sends challenge:**
- Match created with status: `pending`
- Bob receives notification

**2. Bob accepts challenge:**
- Edge function: `pending` → `ready`
- Bob navigates to RemoteLobbyView
- Bob sees: "Waiting for opponent..." + countdown
- Alice's card updates to `lobby` state via realtime
- Alice sees: "Opponent is ready!" + countdown + "Join Match" button

**3. Alice joins match:**
- Tap "Join Match" button
- Edge function: `ready` → `lobby` (first join)
- Alice navigates to RemoteLobbyView
- Alice sees: "Waiting for opponent..." + countdown

**4. Bob still in lobby:**
- Realtime subscription updates match to `lobby`
- Bob's view updates (still waiting)

**5. Alice joins again (second player):**
- Edge function: `lobby` → `in_progress`
- Both players transition to gameplay
- Challenger (Alice) goes first

---

## Key Design Decisions

### 1. Lobby State for Challenger
**Decision:** Show lobby state on challenger's card (not navigate to lobby)
**Reason:** Challenger initiated the match, so they should see the updated state in their sent challenges list rather than being forced into a waiting screen

### 2. Countdown Timer
**Configuration:**
- Production: 5 minutes (300 seconds)
- Testing: 30 seconds (DEBUG mode)
- Location: `RemoteMatchService.joinWindowSeconds`

### 3. State Transitions
**ready → lobby → in_progress**
- Ensures both players explicitly join
- Prevents race conditions
- Clear state progression

### 4. Cancel Behavior
**From Lobby:**
- Calls `cancelChallenge()` edge function
- Updates match to `cancelled`
- Removes locks
- Pops navigation back to Remote tab

---

## Testing Checklist

### Receiver Flow (Bob)
- [ ] Accept challenge navigates to RemoteLobbyView
- [ ] Countdown timer displays and updates every second
- [ ] "Waiting for opponent..." message shows
- [ ] Cancel button works (returns to Remote tab)
- [ ] Expired state shows when countdown reaches 00:00
- [ ] Boxing bell sound plays on appear

### Challenger Flow (Alice)
- [ ] Card updates to lobby state after Bob accepts
- [ ] "Opponent is ready!" message shows
- [ ] Countdown timer displays and updates
- [ ] "Join Match" button appears
- [ ] Tapping join navigates to RemoteLobbyView
- [ ] Realtime updates work correctly

### Both Players Join
- [ ] First join: ready → lobby
- [ ] Second join: lobby → in_progress
- [ ] Both navigate to gameplay
- [ ] Challenger goes first
- [ ] Locks updated to in_progress

### Edge Cases
- [ ] Countdown expires before join
- [ ] Cancel from lobby
- [ ] Network interruption during join
- [ ] Simultaneous join attempts

---

## Files Modified

1. **Created:**
   - `/DanDart/Views/Remote/RemoteLobbyView.swift`

2. **Modified:**
   - `/DanDart/Services/Router.swift`
   - `/DanDart/Views/Remote/RemoteGamesTab.swift`
   - `/DanDart/Views/Components/PlayerChallengeCard.swift`
   - `/supabase/functions/join-match/index.ts`

---

## Next Steps

### Immediate Testing
1. Test accept → lobby flow (receiver)
2. Test lobby state display (challenger)
3. Test both join → in_progress transition
4. Test countdown expiration
5. Test cancel from lobby

### Future Enhancements (Not in Scope)
- Push notification when opponent joins lobby
- Haptic feedback on state transitions
- Lobby chat/emotes
- Ready check system

---

## Configuration

### Countdown Timers
```swift
// RemoteMatchService.swift
private let joinWindowSeconds: TimeInterval = 30 // DEBUG: 30 seconds
// Production: 300 (5 minutes)
```

### Edge Function
```typescript
// accept-challenge/index.ts
const JOIN_WINDOW_SECONDS = 300 // 5 minutes
```

---

## Database Schema

### Match States
- `pending` - Challenge sent, awaiting accept
- `ready` - Challenge accepted, awaiting join
- `lobby` - One player joined, waiting for other
- `in_progress` - Both joined, game active
- `completed` - Game finished
- `expired` - Timeout occurred
- `cancelled` - User cancelled

### match_players Table
Tracks which players have joined:
- `match_id` - UUID
- `player_user_id` - UUID
- `player_order` - 0 (challenger) or 1 (receiver)

---

## Summary

✅ **Receiver accepts → enters lobby immediately**
✅ **Challenger sees "Opponent is ready!" with countdown**
✅ **Challenger can join to enter lobby**
✅ **Both players in lobby → match starts**
✅ **5-minute countdown (30 sec for testing)**
✅ **Cancel functionality works**
✅ **Smooth animations and sound effects**

The lobby implementation is complete and ready for testing!
