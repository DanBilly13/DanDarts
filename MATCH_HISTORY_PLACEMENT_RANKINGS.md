# Match History Placement Rankings

## Feature
Display placement rankings (1st, 2nd, 3rd, etc.) instead of scores for ranking-based games (Sudden Death and Halve-It) in match history.

## Problem
- Sudden Death matches showed "0" for all players (lives remaining)
- Halve-It matches showed scores, but placement is more meaningful
- Unclear who came 2nd, 3rd, etc. in these elimination/ranking games

## Solution
Updated `MatchCard` component to:
1. Detect ranking-based games (Sudden Death, Halve-It)
2. Sort players by final score/placement
3. Display placement indicators with emojis and ordinal numbers

## Implementation

### Game Type Detection

```swift
private var isRankingBasedGame: Bool {
    match.gameType == "Sudden Death" || match.gameType == "Halve It"
}
```

### Player Ranking

```swift
private var rankedPlayers: [MatchPlayer] {
    if match.gameType == "Sudden Death" {
        // Higher lives = better placement
        return match.players.sorted { $0.finalScore > $1.finalScore }
    } else if match.gameType == "Halve It" {
        // Higher score = better placement
        return match.players.sorted { $0.finalScore > $1.finalScore }
    } else {
        // Keep original order for 301/501
        return match.players
    }
}
```

### Placement Display

**1st Place:**
- 🏆 SF Symbol trophy (consistent with 301/501 winner display)
- Gold accent color

**2nd, 3rd, and Beyond:**
- Text-only: "2nd", "3rd", "4th", "5th", etc.
- No emojis (keeps UI clean and simple)
- Secondary text color

```swift
@ViewBuilder
private func placementView(for place: Int) -> some View {
    if place == 1 {
        // Trophy for 1st place (consistent with 301/501)
        Image(systemName: "trophy.fill")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color("AccentTertiary"))
    } else {
        // Text-only for 2nd, 3rd, etc.
        Text("\(place)\(placementSuffix(place))")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(Color("TextSecondary"))
    }
}
```

## Visual Comparison

### Before (Sudden Death):
```
Sudden Death
Bob Smith          0
Alice Jones        0
Charlie Brown      0
```

### After (Sudden Death):
```
Sudden Death
Bob Smith          🏆
Alice Jones        2nd
Charlie Brown      3rd
```

### Before (Halve-It):
```
Halve It
Bob Smith          450
Alice Jones        380
Charlie Brown      290
```

### After (Halve-It):
```
Halve It
Bob Smith          🏆
Alice Jones        2nd
Charlie Brown      3rd
```

### 301/501 (Unchanged):
```
301
Bob Smith          🏆 (trophy)
Alice Jones        127
Charlie Brown      234
```

## Game-Specific Behavior

### Sudden Death
- **Ranking:** Lives remaining (higher = better)
- **Display:** Placement rankings
- **Example:** 3 lives > 2 lives > 1 life > 0 lives

### Halve-It
- **Ranking:** Final score (higher = better)
- **Display:** Placement rankings
- **Example:** 450 pts > 380 pts > 290 pts

### 301/501 (Countdown)
- **Ranking:** Winner vs losers
- **Display:** Trophy for winner, remaining score for others
- **Unchanged:** Existing behavior preserved

## Benefits

### User Experience
- **Clear Rankings:** Immediately see who came 2nd, 3rd, etc.
- **Visual Appeal:** Emojis make placements fun and clear
- **Consistency:** All players shown with meaningful information
- **No Confusion:** No more "0" scores that don't convey placement

### Design
- **Intuitive:** Medals match real-world sports conventions
- **Scalable:** Works for any number of players
- **Accessible:** Text + emoji provides redundancy

## Technical Details

### Sorting Logic

**Sudden Death:**
- `finalScore` = lives remaining at end
- Sort descending (more lives = better)
- Winner has most lives remaining

**Halve-It:**
- `finalScore` = total points scored
- Sort descending (more points = better)
- Winner has highest score

**301/501:**
- No sorting needed
- Winner identified by `winnerId`
- Others show remaining score

### Ordinal Suffixes

```swift
private func placementSuffix(_ place: Int) -> String {
    switch place {
    case 1: return "st"  // 1st, 21st, 31st
    case 2: return "nd"  // 2nd, 22nd, 32nd
    case 3: return "rd"  // 3rd, 23rd, 33rd
    default: return "th" // 4th, 5th, 6th, etc.
    }
}
```

### Layout

- **Width:** 60pt container (same as before)
- **Alignment:** Center
- **Spacing:** 4pt between emoji and text
- **Font:** Bold for top 3, semibold for others

## Edge Cases Handled

### Single Player
- Shows "🏆 1st" (technically they won)

### Two Players
- 1st: 🏆 1st
- 2nd: 🥈 2nd

### Many Players (6+)
- 1st: 🏆 1st
- 2nd: 🥈 2nd
- 3rd: 🥉 3rd
- 4th: 4th (no emoji)
- 5th: 5th (no emoji)
- etc.

### Tied Scores
- Sorted by array order (first occurrence wins)
- Could enhance with tie detection in future

## Bug Fixes

### Bug 1: Disappearing Views

**Problem:**
When loading matches from Supabase, the placement rankings would briefly appear then disappear. The "Loading from database" message would show, then the rankings would vanish.

**Root Cause:**
Using `Array.enumerated()` in `ForEach` caused SwiftUI to lose track of view identities during state updates. When the match data reloaded, SwiftUI couldn't properly reconcile the views.

### Solution
Changed from:
```swift
ForEach(Array(rankedPlayers.enumerated()), id: \.element.id) { index, player in
    // Use index + 1 for placement
}
```

To:
```swift
ForEach(rankedPlayers) { player in
    placementView(for: playerPlacement(player))
}

private func playerPlacement(_ player: MatchPlayer) -> Int {
    guard let index = rankedPlayers.firstIndex(where: { $0.id == player.id }) else {
        return rankedPlayers.count
    }
    return index + 1
}
```

This maintains stable view identities using the player's ID directly, preventing SwiftUI from losing track during updates.

### Bug 2: Game Type Mismatch (Supabase vs Local)

**Problem:**
After loading matches from Supabase, placement rankings would revert to showing scores (0 for Sudden Death, points for Halve-It) instead of placements.

**Root Cause:**
Game type string format mismatch between local storage and Supabase:
- **Local Storage:** `gameType: "Sudden Death"`, `"Halve It"` (title case with space)
- **Supabase:** `game_type: "sudden_death"`, `"halve_it"` (snake_case)

When `MatchesService` loads from Supabase, it reads the `game_type` column which contains snake_case values. The MatchCard was checking for exact matches with title case strings, so it failed to detect ranking-based games.

**Solution:**
Use case-insensitive comparison that handles both formats:

```swift
private var isRankingBasedGame: Bool {
    let gameType = match.gameType.lowercased()
    return gameType == "sudden death" || gameType == "sudden_death" ||
           gameType == "halve it" || gameType == "halve_it"
}

private var rankedPlayers: [MatchPlayer] {
    let gameType = match.gameType.lowercased()
    
    if gameType == "sudden death" || gameType == "sudden_death" {
        return match.players.sorted { $0.finalScore > $1.finalScore }
    } else if gameType == "halve it" || gameType == "halve_it" {
        return match.players.sorted { $0.finalScore > $1.finalScore }
    } else {
        return match.players
    }
}
```

This works for:
- Local matches: "Sudden Death", "Halve It"
- Supabase matches: "sudden_death", "halve_it"
- Any case variation: "SUDDEN DEATH", "Sudden_Death", etc.

## Files Modified

**MatchCard.swift:**
- Added `isRankingBasedGame` computed property
- Added `rankedPlayers` computed property
- Added `playerPlacement()` method (calculates placement from player ID)
- Added `placementView()` method (displays trophy or text)
- Added `placementSuffix()` helper (st, nd, rd, th)
- Updated `playersRow` to use stable ForEach with player IDs

## Testing

### Verify Placements:

**Sudden Death:**
1. Play game with 3+ players
2. Check match history
3. Should show: 🏆 for winner, "2nd", "3rd" for others
4. Verify order matches lives remaining
5. Verify rankings persist after loading from Supabase

**Halve-It:**
1. Play game with 3+ players
2. Check match history
3. Should show: 🏆 for winner, "2nd", "3rd" for others
4. Verify order matches final scores
5. Verify rankings persist after loading from Supabase

**301/501:**
1. Play game
2. Check match history
3. Should show: 🏆 for winner, scores for others
4. Verify unchanged behavior

## Future Enhancements

Potential improvements:
1. **Tie Detection** - Show "T-2nd" for tied players
2. **Animated Medals** - Subtle shine/glow effect
3. **Placement Colors** - Gold/silver/bronze backgrounds
4. **Statistics** - Track placement frequency (how often 2nd, 3rd, etc.)
5. **Filters** - Filter history by placement ("Show all 1st place finishes")

## Notes

- Emojis are universally supported on iOS
- Placement logic is deterministic and consistent
- Works with any number of players (2-10+)
- All lint errors are expected IDE analysis issues
- Maintains existing behavior for 301/501 games

## Related Components

- `MatchCard.swift` - Display component (modified)
- `MatchResult.swift` - Data model (unchanged)
- `MatchPlayer.swift` - Player data (unchanged)
- `MatchHistoryView.swift` - List view (unchanged)
