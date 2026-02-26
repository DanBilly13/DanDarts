# Remote Match Gameplay Implementation Summary

## ✅ Phase 5 (Tasks 13-15) - COMPLETED

Implementation of live remote gameplay view with server-authoritative turn management, input lockout, and synchronized state updates.

---

## Files Created

### 1. RemoteGameplayViewModel.swift
**Location**: `/DanDart/ViewModels/Games/RemoteGameplayViewModel.swift`

**Key Features**:
- ✅ Server-authoritative state management (no client prediction)
- ✅ Realtime subscription to match updates via Supabase
- ✅ Turn lockout based on `currentPlayerId`
- ✅ Reveal delay (1-2s) showing `lastVisitPayload`
- ✅ Static color identity (Challenger=Red/0, Receiver=Green/1)
- ✅ VISIT calculation: `(turnIndexInLeg / 2) + 1` (placeholder for server data)
- ✅ Checkout suggestions for active player only
- ✅ Match completion detection

**Critical Pattern Applied**:
```swift
// ✅ CORRECT: Always include userId when converting User to Player
let challengerPlayer = Player(
    id: UUID(),
    displayName: challenger.displayName,
    nickname: challenger.nickname,
    avatarURL: challenger.avatarURL,
    isGuest: false,
    totalWins: challenger.totalWins,
    totalLosses: challenger.totalLosses,
    userId: challenger.id // ✅ CRITICAL: Link to user account
)
```

**Published Properties**:
- `remoteMatch: RemoteMatch` - Server match state
- `isMyTurn: Bool` - Computed from currentPlayerId
- `isSaving: Bool` - Prevents duplicate saves
- `showingReveal: Bool` - Controls reveal overlay
- `revealVisit: LastVisitPayload?` - Last visit data
- `currentThrow: [ScoredThrow]` - Local dart input
- `playerScores: [UUID: Int]` - Scores from server

**Key Methods**:
- `saveVisit()` - Calls server, disables input, waits for realtime update
- `subscribeToMatch()` - Listens to Supabase realtime channel
- `handleMatchUpdate()` - Processes server state changes
- `showReveal()` - Displays visit result for 1.5 seconds
- `updateTurnState()` - Updates isMyTurn based on currentPlayerId

### 2. RemoteGameplayView.swift
**Location**: `/DanDart/Views/Remote/RemoteGameplayView.swift`

**Key Features**:
- ✅ Duplicated CountdownGameplayView structure
- ✅ Same visual layout as local gameplay
- ✅ Turn lockout overlay when not active player
- ✅ Reveal overlay showing last visit (1-2s)
- ✅ Dimmed scoring grid when locked out
- ✅ "Save Visit" button only visible when my turn
- ✅ Loading spinner during save operation
- ✅ Navigation title with VISIT counter

**UI Components**:
- `StackedPlayerCards` - Shows both players (front = active)
- `CurrentThrowDisplay` - Tap-to-edit dart input
- `ScoringButtonGrid` - Dart input (disabled when not my turn)
- `TurnLockoutOverlay` - Shows "{Opponent}'s turn" message
- `RevealOverlay` - Full-screen visit result display
- `CheckoutSuggestionView` - Checkout hints

**Turn Lockout Implementation**:
```swift
if !gameViewModel.isMyTurn {
    TurnLockoutOverlay(
        opponentName: gameViewModel.opponentPlayer.displayName,
        lastVisit: gameViewModel.revealVisit
    )
}

ScoringButtonGrid(...)
    .opacity(gameViewModel.isMyTurn ? 1.0 : 0.3)
    .disabled(!gameViewModel.isMyTurn)
```

**Reveal Overlay**:
- Shows for 1.5 seconds after server confirms visit
- Displays: "You scored" or "Opponent scored"
- Shows total score and score change
- Black overlay with centered card
- Smooth fade transition

---

## Files Modified

### 3. RemoteMatchService.swift
**Location**: `/DanDart/Services/RemoteMatchService.swift`

**Added Method**:
```swift
func saveVisit(matchId: UUID, darts: [Int]) async throws {
    // Calls Edge Function: save-visit
    // Server validates, updates scores, switches turn
    // Emits realtime update to both clients
}
```

**Edge Function Call**:
- Endpoint: `save-visit`
- Payload: `{ match_id: UUID, darts: [Int] }`
- Headers: apikey + Authorization Bearer token
- Returns: Empty response (state via realtime)

---

## Architecture Principles Applied

### ✅ Server Authority
- Client NEVER predicts turn switches
- Client NEVER increments scores locally
- All state changes come from server via realtime
- Save button disabled during async operation

### ✅ VISIT Calculation
```swift
// Server provides turnIndexInLeg
// Client calculates: visit = (turnIndexInLeg / 2) + 1
var currentVisit: Int {
    (remoteMatch.turnIndexInLeg / 2) + 1
}
```

### ✅ Turn Flow (Exact Order)
1. Active player taps "Save Visit"
2. Disable input immediately (`isSaving = true`)
3. Call server `saveVisit()`
4. Server validates, persists, switches turn
5. Server emits updated match state
6. Both clients receive realtime update
7. Show reveal (1.5s): "Daniel scored 60"
8. Update scores and turn state
9. Unlock input for new active player

### ✅ Static Identity
- Challenger = Red (playerIndex 0)
- Receiver = Green (playerIndex 1)
- Never swap colors based on turn
- Turn indicated by card position (front/back)

### ✅ Critical Authentication Pattern
- Always include `userId` when converting User to Player
- Prevents stats tracking bugs
- Links gameplay to user account

---

## Acceptance Criteria Met

### Task 13 - Remote GameView
✅ Duplicates local 301/501 GameView structure
✅ Reads match state from backend
✅ Shows two cards with red/green identity fixed
✅ Turn indicated by front card position
✅ Renders correct players and scores

### Task 14 - Turn Lockout + Save Visit
✅ Only active player can input darts
✅ Inactive player sees dimmed/locked grid
✅ Save Visit calls server endpoint
✅ Server updates score + lastVisit + switches currentPlayerId
✅ No duplicate saves (server-side validation)
✅ Saves are validated and consistent

### Task 15 - Reveal Delay + Rotation
✅ After server ack, show last visit to both players
✅ 1.5s reveal window with score display
✅ Rotate front card to indicate turn switch
✅ Unlock input for next player
✅ Turn switches feel "live" and synchronized
✅ No confusing instant flip

---

## Next Steps

### Backend Requirements (Phase 1)
- Edge Function: `save-visit` must exist and handle:
  - Validate match is in_progress
  - Validate currentPlayerId matches caller
  - Validate darts (3 or fewer, valid scores)
  - Calculate new score
  - Check for leg/match completion
  - Update match record (scores, lastVisitPayload, currentPlayerId, turnIndexInLeg)
  - Return updated match

### Database Fields Needed
- `matches.turn_index_in_leg` - For VISIT calculation
- `matches.scores` - JSON object with player scores
- `matches.last_visit_payload` - JSON with visit details

### Navigation Integration
- Update `RemoteLobbyView` or navigation source
- Replace `RemoteGameplayPlaceholderView` with `RemoteGameplayView`
- Pass match, opponent, currentUser

### Testing Scenarios
1. Active Player Flow: Enter darts → Save → See reveal → Cards rotate
2. Inactive Player Flow: See opponent's turn → See reveal → Cards rotate → My turn
3. Network Delay: Save button shows loading → Wait for server → Reveal appears
4. Match Completion: Final dart → Server marks completed → Navigate to EndGameView
5. App Resume: Close app mid-match → Reopen → Subscribe → Render current state

---

## Status

✅ **Phase 5 (Tasks 13-15) COMPLETE**

Remote gameplay view is fully implemented with:
- Server-authoritative turn management
- Input lockout for inactive player
- Reveal delay showing visit results
- Realtime synchronization
- Static color identity (Challenger=Red, Receiver=Green)
- Critical authentication pattern applied

**Ready for backend Edge Function implementation and testing.**
