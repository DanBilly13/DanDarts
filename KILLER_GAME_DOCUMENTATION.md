# Killer Game - Complete Documentation

## Game Overview

Killer is a multiplayer dart game where players compete to eliminate each other by hitting their assigned numbers. The last player standing wins.

## Game Rules

### Setup
- **Players**: 2-6 players (connected users or guests)
- **Starting Lives**: Configurable (default: 3, options: 1-10)
- **Player Numbers**: Each player is randomly assigned a unique number (1-20)

### Gameplay Phases

#### Phase 1: Becoming a Killer
- Players must hit the **double** of their assigned number to become a "Killer"
- Until a player becomes a Killer, they cannot affect other players
- Hitting singles or triples of your number does nothing in this phase

#### Phase 2: Killer Mode
Once a player becomes a Killer, they can:

**Attacking Opponents:**
- Hit an opponent's number to remove lives based on multiplier:
  - **Single**: Remove 1 life
  - **Double**: Remove 2 lives
  - **Triple**: Remove 3 lives
- Multiple hits in one turn stack (e.g., T20 + D20 + 20 = 6 lives removed from player with number 20)

**Self-Damage:**
- Hitting your own number removes lives based on multiplier:
  - **Single**: Lose 1 life
  - **Double**: Lose 2 lives
  - **Triple**: Lose 3 lives

**Elimination:**
- When a player reaches 0 lives, they are eliminated
- Eliminated players no longer take turns

### Winning
- Last player with lives remaining wins
- Game ends immediately when only one player has lives

## Technical Implementation

### Data Models

#### Player State
```swift
- playerNumbers: [UUID: Int]           // Player ID to assigned number
- isKiller: [UUID: Bool]               // Whether player is in Killer mode
- displayPlayerLives: [UUID: Int]      // Current lives for each player
- eliminatedPlayers: Set<UUID>         // Players with 0 lives
```

#### Match Metadata
Stored in `match.metadata` dictionary:
```swift
- "starting_lives": String             // e.g., "5"
- "player_{uuid}": String              // e.g., "player_5DB0EC59-...: "18"
```

#### Dart Metadata
Each dart throw includes metadata:
```swift
enum KillerDartOutcome {
    case becameKiller                  // Hit own double to activate
    case hitOpponent                   // Hit opponent's number
    case hitOwnNumber                  // Hit own number as Killer
    case miss                          // Didn't hit any relevant number
}

struct KillerDartMetadata {
    outcome: KillerDartOutcome
    affectedPlayerIds: [UUID]          // Players who lost lives
}
```

### Player ID Consistency

**Critical Implementation Detail:**
- Guest players use `player.id` as their identifier
- Connected users use `player.userId` as their identifier
- The `matchPlayerId(for: Player)` function returns the correct ID:
  ```swift
  func matchPlayerId(for player: Player) -> UUID {
      return player.userId ?? player.id
  }
  ```
- This ID is used consistently for:
  - `MatchPlayer.id`
  - `match.winnerId`
  - Metadata keys (`player_{uuid}`)

### Life Loss Logic

**processThrow() Function:**

1. **Check for Killer Activation:**
   - If `thrownNumber == playerNumber && multiplier == 2 && !isKiller`
   - Activate Killer mode
   - Return `.becameKiller` metadata

2. **If Player is Killer:**
   
   a. **Check Own Number:**
   - If `thrownNumber == playerNumber`
   - Remove `multiplier` lives from self
   - Return `.hitOwnNumber` with affected IDs
   
   b. **Check Opponent Numbers:**
   - Loop through all opponents
   - If `thrownNumber == opponentNumber`
   - Remove `multiplier` lives from opponent
   - Return `.hitOpponent` with affected IDs

3. **Otherwise:**
   - Return `.miss` metadata

**loseLife() Function:**
- Decrements `displayPlayerLives[playerID]` by 1
- Triggers haptic feedback
- Animates life loss
- Adds to `eliminatedPlayers` when lives reach 0

## Match History Display

### Player Rankings Section
Players are sorted by final placement:
1. Winner (most lives remaining)
2. 2nd place (eliminated later)
3. 3rd place (eliminated earlier)
etc.

Each player card shows:
- Avatar with colored border (player color)
- Display name and nickname
- Placement badge (WINNER, 2nd, 3rd, etc.)

### Color Key Section
Shows all players with their assigned colors:
- Army: Red (player 1)
- Christina Billingham: Green (player 2)
- Daniel Andersson: Yellow (player 3)
etc.

**Color Assignment:**
Colors are assigned based on the player's **original position** in `match.players` array (not sorted position):
```swift
func playerColor(for index: Int) -> Color {
    switch index {
    case 0: return AppColor.player1  // Red
    case 1: return AppColor.player2  // Green
    case 2: return AppColor.player3  // Yellow
    case 3: return AppColor.player4  // Purple
    case 4: return AppColor.player5  // Orange
    case 5: return AppColor.player6  // Pink
    default: return AppColor.player1
    }
}
```

### Stats Section

#### Kills
Shows total lives removed from opponents (not including self-damage).

**Calculation:**
```swift
func calculateKills(for player: MatchPlayer) -> Int {
    var kills = 0
    for turn in player.turns {
        for dart in turn.darts {
            if let metadata = dart.gameMetadata,
               metadata["outcome"] == "hitOpponent",
               let affectedCount = metadata["affected_player_ids"]?.components(separatedBy: ",").count {
                kills += affectedCount
            }
        }
    }
    return kills
}
```

**Display:**
- Players sorted by most kills (descending)
- Bar width proportional to kill count
- Bar color matches player's original color
- Number shown on right

#### Most Suicidal
Shows total self-inflicted life losses.

**Calculation:**
```swift
func calculateSelfHits(for player: MatchPlayer) -> Int {
    var selfHits = 0
    for turn in player.turns {
        for dart in turn.darts {
            if let metadata = dart.gameMetadata,
               metadata["outcome"] == "hitOwnNumber",
               let affectedCount = metadata["affected_player_ids"]?.components(separatedBy: ",").count {
                selfHits += affectedCount
            }
        }
    }
    return selfHits
}
```

**Display:**
- Only shows players with self-hits > 0
- Players sorted by most self-hits (descending)
- Bar width proportional to self-hit count
- Bar color matches player's original color
- Number shown on right

**Critical Fix (Dec 22, 2025):**
The `StatCategorySection` component was updated to use `getOriginalIndex` parameter to ensure bar colors match the player's original position in the match, not their sorted position in the stats list.

### Round-by-Round Breakdown

Shows a grid for each round with:
- Player avatars (colored borders)
- Dart icons (gun for became killer, hit icons for hits)
- Hearts showing lives remaining

**Round Structure:**
Each round shows only players who were **alive at the start of that round**.

**Determining Alive Players:**
```swift
func isPlayerAliveInRound(_ player: MatchPlayer, roundIndex: Int) -> Bool {
    let livesLostBeforeRound = countLivesLost(player: player, upToRound: roundIndex)
    return livesLostBeforeRound < startingLives
}
```

**Lives Calculation:**
```swift
func countLivesLost(player: MatchPlayer, upToRound: Int) -> Int {
    var livesLost = 0
    for (turnIndex, turn) in player.turns.enumerated() {
        guard turnIndex < upToRound else { break }
        for dart in turn.darts {
            if let metadata = dart.gameMetadata,
               let affectedIds = metadata["affected_player_ids"]?.components(separatedBy: ",") {
                // Count how many times this player appears in affected IDs
                livesLost += affectedIds.filter { $0 == player.id.uuidString }.count
            }
        }
    }
    return livesLost
}
```

**Dart Icons:**
- 🔫 Gun icon: Became Killer (hit own double)
- 🎯 Hit icon: Hit opponent or self
- ❌ X icon: Miss or eliminated player

**Hearts Display:**
- White hearts: Lives remaining
- Black hearts: Lives lost
- Shows actual lives at end of round

**Text Summary:**
Below each round's grid, a text summary shows:
```
Army: 'Killer mode' (D12). Hit 13 - Christina lost 1 life. Hit 6 - Daniel lost 1 life
Christina: Miss. 'Killer mode' (D13). Hit own number (13) - Lost 1 life
Daniel: Miss. Miss. 'Killer mode' (D6)

End of Round 1:
• Army: 5 lives left
• Christina: 3 lives left
• Daniel: 4 lives left
```

### Winner Section

Shows the final winner with:
- Avatar (colored border)
- Three X marks (no darts thrown)
- Full white hearts showing remaining lives

**Critical Fix (Dec 22, 2025):**
The `winnerId` must use `matchPlayerId(for: winner)` instead of `winner.id` to ensure consistency with `MatchPlayer` IDs.

## Debug Output

The game produces detailed debug logs:

### Game Summary
```
🎯 ========================================
🎯 KILLER GAME - 5 LIVES
🎯 ========================================

📋 Metadata keys: ["player_4580F768-...", "player_5DB0EC59-...", ...]
   Army - Number: 12 (key: player_5DB0EC59-..., stored: 12)
   Christina - Number: 13 (key: player_86F1E089-..., stored: 13)
```

### Dart Processing
```
🎯 recordThrow called: value=18, multiplier=2
   Created ScoredThrow: base=18, type=double, total=36

💀 Hit own number 18 with multiplier 2 - removing 2 lives from Army
   Life loss 1/2: Army before=5
   Life loss 1/2: Army after=4
   Life loss 2/2: Army before=4
   Life loss 2/2: Army after=3

💥 Hit opponent's number 14 with multiplier 3 - removing 3 lives from Daniel
   Life loss 1/3: Daniel before=4
   Life loss 1/3: Daniel after=3
   Life loss 2/3: Daniel before=3
   Life loss 2/3: Daniel after=2
   Life loss 3/3: Daniel before=2
   Life loss 3/3: Daniel after=1
```

### Player Movement
```
🔄 moveToNextPlayer called. Current: Army (index 0)
   Player lives: Army=1, Christina=3, Daniel=0
   Skipping Daniel (lives: 0)
   ➡️ Next player: Christina (index 1, lives: 3)
```

## Known Issues & Fixes

### Bug Fix History

#### 1. Metadata Not Saving (Dec 22, 2025)
**Problem:** Player numbers weren't being saved to Supabase.
**Solution:** 
- Added `gameMetadata` parameter to `MatchService.saveMatch()`
- Updated `MatchMetadata` struct with `game_metadata` field
- Fixed metadata loading to extract nested `game_metadata` dictionary

#### 2. Player ID Mismatch (Dec 22, 2025)
**Problem:** Connected users' metadata wasn't loading correctly.
**Solution:** Use `matchPlayerId(for: player)` when creating metadata keys to ensure consistency between guest and connected players.

#### 3. Winner Section Missing (Dec 22, 2025)
**Problem:** Winner card not displaying in match history.
**Solution:** Use `matchPlayerId(for: winner)` for `winnerId` instead of `winner.id`.

#### 4. Multiplier Not Applied to Self-Damage (Dec 22, 2025)
**Problem:** Hitting own number as Killer only removed 1 life regardless of multiplier.
**Solution:** Updated `processThrow()` to loop `multiplier` times when hitting own number, matching opponent hit logic.

#### 5. Stat Bar Color Mismatch (Dec 22, 2025)
**Problem:** Stat bars showed wrong colors because players were sorted by kills.
**Solution:** Added `getOriginalIndex` parameter to `StatCategorySection` to use original player position for colors instead of sorted position.

## Files Modified

### Core Game Logic
- `KillerViewModel.swift` - Game state management, turn processing, life tracking
- `KillerGameplayView.swift` - Main gameplay UI

### Match Saving
- `MatchService.swift` - Metadata saving with `gameMetadata` parameter
- `MatchesService.swift` - Metadata loading from nested structure

### Match History
- `KillerMatchDetailView.swift` - Match history display with stats and rounds
- `MatchDetailView.swift` - `StatCategorySection` component with color fix

### Models
- `ScoredThrow.swift` - Dart data model with base value and multiplier
- `MatchResult.swift` - Match data model with metadata

## Testing Checklist

When testing Killer game functionality:

- [ ] Player numbers assigned correctly (1-20, unique)
- [ ] Becoming Killer requires hitting own double
- [ ] Single/double/triple multipliers work for opponents
- [ ] Single/double/triple multipliers work for self-damage
- [ ] Lives decrement correctly
- [ ] Eliminated players skip turns
- [ ] Winner determined correctly
- [ ] Match saves to Supabase
- [ ] Metadata includes all player numbers
- [ ] Match history loads correctly
- [ ] Player colors match in all sections
- [ ] Stats show correct kill counts
- [ ] Round-by-round shows correct players per round
- [ ] Winner section displays correctly
- [ ] Debug output shows correct life changes
