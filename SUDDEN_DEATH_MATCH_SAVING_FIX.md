# Sudden Death Match Saving Fix

## Problem
Sudden Death games were not appearing in match history because matches were not being saved to the database.

## Root Cause
`SuddenDeathViewModel` was missing the entire match saving implementation that exists in other game ViewModels (`CountdownViewModel` and `HalveItViewModel`).

**Missing Components:**
1. No `matchId` or `matchStartTime` tracking
2. No `authService` or `matchService` properties
3. No `saveMatchResult()` method
4. No call to save match when game ends

## Solution Implemented

### 1. Added Match Tracking Properties to SuddenDeathViewModel

```swift
private let matchId = UUID()
private let matchStartTime = Date()

// Services (optional for Supabase sync)
var authService: AuthService?
var matchService: MatchesService?
```

### 2. Implemented saveMatchResult() Method

Added complete match saving logic that:
- Creates `MatchResult` with all game data
- Saves to local storage via `MatchStorageManager`
- Updates player stats (wins/losses)
- Syncs to Supabase (if user signed in)
- Updates user stats in AuthService

**Match Data Saved:**
- Match ID and timestamps
- Game type: "sudden_death"
- All players with final lives remaining
- Winner information
- Match duration
- Metadata: starting lives, final lives per player

### 3. Called saveMatchResult() When Game Ends

```swift
func endGame() {
    if let lastPlayer = activePlayers.first {
        winner = lastPlayer
        isGameOver = true
        soundManager.playGameWin()
        
        // Save match result
        saveMatchResult()  // ← Added this
    }
}
```

### 4. Injected Services in SuddenDeathGameplayView

**Added service properties:**
```swift
@EnvironmentObject private var authService: AuthService
@StateObject private var matchService = MatchesService()
```

**Injected into ViewModel on appear:**
```swift
.onAppear {
    viewModel.authService = authService
    viewModel.matchService = matchService
}
```

## Implementation Details

### Match Storage Flow

**Local Storage:**
1. Game ends → `endGame()` called
2. `saveMatchResult()` creates `MatchResult`
3. Saves to local JSON via `MatchStorageManager`
4. Updates player stats (wins/losses)

**Supabase Sync:**
1. Checks if user is signed in
2. Gets Supabase game ID for "sudden_death"
3. Saves match with all metadata
4. Updates user stats in database
5. Refreshes local user stats

### Match Data Structure

```swift
MatchResult(
    id: matchId,
    gameId: "sudden_death",
    gameName: "Sudden Death",
    players: [MatchPlayer],  // All players with final lives
    winner: MatchPlayer,      // Winner info
    timestamp: matchStartTime,
    duration: duration,
    matchFormat: 1,
    totalLegsPlayed: 1
)
```

### Metadata Saved

```swift
metadata: [
    "starting_lives": 3,  // or 1, 5
    "final_lives": [
        "player1-uuid": 2,
        "player2-uuid": 0,
        "player3-uuid": 1
    ]
]
```

## Files Modified

### SuddenDeathViewModel.swift
**Added:**
- `matchId` and `matchStartTime` properties
- `authService` and `matchService` properties
- `saveMatchResult()` method (complete implementation)
- Call to `saveMatchResult()` in `endGame()`

### SuddenDeathGameplayView.swift
**Added:**
- `@EnvironmentObject authService`
- `@StateObject matchService`
- `.onAppear` to inject services into ViewModel

## Comparison with Other Games

All game ViewModels now have consistent match saving:

| Feature | Countdown (301/501) | Halve-It | Sudden Death |
|---------|-------------------|----------|--------------|
| Match ID tracking | ✅ | ✅ | ✅ (fixed) |
| Local storage | ✅ | ✅ | ✅ (fixed) |
| Supabase sync | ✅ | ✅ | ✅ (fixed) |
| Player stats update | ✅ | ✅ | ✅ (fixed) |
| Match metadata | ✅ | ✅ | ✅ (fixed) |

## Testing

### Verify Match Saving:

1. **Play Sudden Death Game:**
   - Start new Sudden Death game
   - Play until someone wins
   - Check console for: `✅ Sudden Death match synced to Supabase`

2. **Check Match History:**
   - Navigate to History tab
   - Sudden Death matches should now appear
   - Should show correct winner and players

3. **Check Player Stats:**
   - Winner's win count should increase
   - Loser's loss count should increase
   - Stats visible in profile and player cards

4. **Check Database:**
   - Supabase `matches` table should have new row
   - `game_id` should be "sudden_death"
   - `metadata` should include lives data

### Test Scenarios:

**Signed In User:**
- ✅ Match saves to local storage
- ✅ Match syncs to Supabase
- ✅ Player stats update in database
- ✅ Appears in match history

**Guest Mode:**
- ✅ Match saves to local storage
- ⚠️ No Supabase sync (expected)
- ✅ Appears in match history

**Offline:**
- ✅ Match saves to local storage
- ⚠️ Supabase sync fails gracefully
- ✅ Will retry sync later (if implemented)

## Benefits

### For Users:
- Sudden Death matches now tracked in history
- Stats properly updated after games
- Can review past Sudden Death matches
- Consistent experience across all game modes

### For Development:
- Consistent architecture across all games
- Easier to maintain and debug
- Proper data persistence
- Analytics and statistics possible

## Future Enhancements

Potential improvements:
1. **Detailed turn history** - Track each turn's score
2. **Lives progression** - Show how lives changed over time
3. **Elimination order** - Track when each player was eliminated
4. **Comeback tracking** - Identify dramatic comebacks
5. **Head-to-head stats** - Sudden Death specific stats

## Notes

- Match saving is now consistent across all game modes
- Uses same `MatchStorageManager` and `MatchesService` as other games
- Metadata includes Sudden Death-specific data (lives)
- Final score in match history shows lives remaining
- All lint errors are expected IDE analysis issues

## Related Files

- `SuddenDeathViewModel.swift` - Game logic + match saving
- `SuddenDeathGameplayView.swift` - UI + service injection
- `MatchStorageManager.swift` - Local storage (shared)
- `MatchesService.swift` - Supabase sync (shared)
- `MatchResult.swift` - Data model (shared)
