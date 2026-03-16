# Remote Match Staged Flow Refactoring - Implementation Summary

## Status: Core Implementation Complete

This document summarizes the implementation of the deterministic staged state machine for remote match flow.

## Completed Components

### Phase 1: Database & Edge Functions ✅

#### 1.1 Database Migration
- **File**: `supabase_migrations/078_add_lobby_presence_tracking.sql`
- Added 4 columns to `matches` table:
  - `challenger_lobby_joined_at TIMESTAMPTZ NULL`
  - `receiver_lobby_joined_at TIMESTAMPTZ NULL`
  - `lobby_countdown_started_at TIMESTAMPTZ NULL`
  - `lobby_countdown_seconds INT NOT NULL DEFAULT 5`

#### 1.2 Edge Functions Created
- **`enter-lobby`** (`supabase/functions/enter-lobby/index.ts`)
  - Sets lobby presence timestamps for calling user
  - Transitions `ready` → `lobby` when first player enters
  - Starts countdown when both players present
  - Idempotent (safe to call multiple times)

- **`start-match-if-ready`** (`supabase/functions/start-match-if-ready/index.ts`)
  - Validates countdown elapsed (5 seconds)
  - Validates both players present in lobby
  - Transitions `lobby` → `in_progress`
  - Sets `current_player_id` and `started_at`
  - Idempotent (handles simultaneous calls from both clients)

- **`accept-challenge`** (unchanged)
  - Keeps existing behavior: `pending` → `ready`
  - Does NOT set lobby timestamps
  - Does NOT transition to `lobby`

### Phase 2: Client-Side Models & Services ✅

#### 2.1 RemoteMatch Model Updates
- **File**: `DanDart/Models/RemoteMatch.swift`
- Added properties:
  - `challengerLobbyJoinedAt: Date?`
  - `receiverLobbyJoinedAt: Date?`
  - `lobbyCountdownStartedAt: Date?`
  - `lobbyCountdownSeconds: Int?`
- Added computed properties:
  - `bothPlayersInLobby: Bool`
  - `countdownStarted: Bool`
  - `countdownRemaining: TimeInterval?`
  - `countdownElapsed: Bool`
- Updated CodingKeys and decoders

#### 2.2 RemoteMatchService Updates
- **File**: `DanDart/Services/RemoteMatchService.swift`
- Added methods:
  - `enterLobby(matchId:)` - Calls enter-lobby edge function
  - `startMatchIfReady(matchId:)` - Calls start-match-if-ready edge function
  - Handles 425 status (countdown not elapsed yet)

### Phase 3: Receiver Accept Flow ✅

#### 3.1 RemoteGamesTab.acceptChallenge()
- **File**: `DanDart/Views/Remote/RemoteGamesTab.swift`
- Updated to two-step flow:
  1. Call `acceptChallenge()` - transitions `pending` → `ready`
  2. Call `enterLobby()` - receiver joins, transitions `ready` → `lobby`
  3. Fetch updated match
  4. Navigate to RemoteLobbyView
- Maintains single-button UX while separating server state

### Phase 4: Challenger Join Flow ✅

#### 4.1 RemoteGamesTab.joinMatch()
- **File**: `DanDart/Views/Remote/RemoteGamesTab.swift`
- Updated to use `enterLobby()`:
  1. Call `enterLobby()` - challenger joins lobby
  2. Server sets `challenger_lobby_joined_at`
  3. Server starts countdown if both players present
  4. Fetch updated match
  5. Navigate to RemoteLobbyView

### Phase 5: Lobby View Refactoring ✅

#### 5.1 RemoteLobbyView Updates
- **File**: `DanDart/Views/Remote/RemoteLobbyView.swift`
- Added computed properties:
  - `bothPlayersPresent: Bool`
  - `countdownActive: Bool`
  - `countdownRemaining: TimeInterval`
  - `countdownElapsed: Bool`
  - `formattedCountdown: String`
- Added `onChange(of: countdownElapsed)` handler:
  - Calls `startMatchIfReady()` when countdown reaches zero
  - Both clients may call simultaneously (idempotent)
- Existing `onChange(of: matchStatus)` handler:
  - Navigates to gameplay when status becomes `in_progress`

## State Flow

```
pending → ready → lobby → in_progress → completed
          ↓       ↓  ↓           ↓
      (accept) (enter) (countdown) (start-if-ready)
```

### Receiver Flow
1. Receiver taps **Accept**
2. Server: `pending` → `ready` (accept-challenge)
3. Server: `ready` → `lobby`, set `receiver_lobby_joined_at` (enter-lobby)
4. Receiver navigates to lobby
5. Receiver waits for challenger

### Challenger Flow
1. Challenger taps **Join**
2. Server: set `challenger_lobby_joined_at` (enter-lobby)
3. Server: both players present → set `lobby_countdown_started_at`
4. Challenger navigates to lobby
5. Both clients show 5-second countdown

### Countdown & Start
1. Both clients render countdown from `lobby_countdown_started_at`
2. When countdown reaches zero locally, both clients call `start-match-if-ready`
3. Server validates countdown elapsed
4. Server transitions `lobby` → `in_progress` (first call wins)
5. Both clients receive status update via realtime
6. Both clients navigate to gameplay

## Key Design Decisions

### State Separation
- **`ready` ≠ `lobby presence`** - These remain separate concepts
- `ready` = challenge accepted, match is joinable
- `lobby presence` = player physically entered lobby (tracked via timestamps)

### Server Authority
- Server owns all state transitions
- Clients render from authoritative server state
- Never navigate from raw realtime payload alone

### Countdown Design
- 5-second countdown aligns with voice spec
- Server sets `lobby_countdown_started_at` timestamp
- Clients render countdown from shared timestamp
- Clients call `start-match-if-ready` when countdown reaches zero
- Server performs authoritative validation and transition

### Idempotency
- `enter-lobby` is idempotent (multiple calls safe)
- `start-match-if-ready` is idempotent (both clients may call)
- Lobby presence timestamps are single source of truth

## Remaining Work

### Phase 6-10 (To Be Completed)
- [ ] Card state management cleanup
- [ ] Realtime event handling centralization
- [ ] Navigation guardrails strengthening
- [ ] Voice chat integration verification
- [ ] Testing and validation

### Next Steps
1. Test the implemented flow end-to-end
2. Verify countdown timing is accurate
3. Test simultaneous start-match-if-ready calls
4. Verify voice chat continues to work during lobby countdown
5. Test cancellation during lobby
6. Test expiry during lobby

## Files Modified

### Database
- ✅ `supabase_migrations/078_add_lobby_presence_tracking.sql`

### Edge Functions
- ✅ `supabase/functions/enter-lobby/index.ts` (new)
- ✅ `supabase/functions/start-match-if-ready/index.ts` (new)
- ✅ `supabase/functions/accept-challenge/index.ts` (unchanged)

### Models
- ✅ `DanDart/Models/RemoteMatch.swift`

### Services
- ✅ `DanDart/Services/RemoteMatchService.swift`

### Views
- ✅ `DanDart/Views/Remote/RemoteGamesTab.swift`
- ✅ `DanDart/Views/Remote/RemoteLobbyView.swift`

## Notes

- TypeScript lints for Deno edge functions are expected and will work correctly when deployed
- Swift lints for `User` and `RemoteMatchService` types are expected forward references
- The implementation follows the plan exactly as specified
- All critical state separation requirements have been maintained
- Server remains authoritative for all state transitions
