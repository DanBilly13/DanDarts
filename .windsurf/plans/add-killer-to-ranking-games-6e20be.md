# Add Killer to Ranking-Based Games

**Fix Killer game to use isRankingBasedGame check and properly display placement instead of scores.**

## Current Issues

### Issue 1: Killer Not in Ranking Check
**MatchCard.swift** line 185-190: `isRankingBasedGame` doesn't include "killer":
```swift
return gameType == "knockout" ||
       gameType == "sudden death" || gameType == "sudden_death" ||
       gameType == "halve it" || gameType == "halve_it"
```

### Issue 2: Killer Ranking Logic Missing  
**MatchCard.swift** line 198-214: `rankedPlayers` doesn't handle "killer":
```swift
if gameType == "knockout" {
    // higher lives = better placement
} else if gameType == "sudden death" {
    // higher lives = better placement  
} else if gameType == "halve it" {
    // higher score = better placement
} else {
    // keep original order - Killer falls through here!
}
```

### Issue 3: Killer Uses Wrong Score Field
**KillerViewModel.swift** line 335: All players get `finalScore: 0`:
```swift
finalScore: 0,  // Should be remaining lives for ranking
```

## Root Cause Analysis

**Killer game mechanics:**
- Players have lives (starting lives, lose lives when hit)
- Winner = last player with lives > 0
- Ranking should be by remaining lives (higher = better)
- Currently stores `finalScore: 0` for everyone, so no ranking possible

## Solution Strategy

### Step 1: Add Killer to Ranking Check
Add "killer" to `isRankingBasedGame`:
```swift
return gameType == "knockout" ||
       gameType == "sudden death" || gameType == "sudden_death" ||
       gameType == "halve it" || gameType == "halve_it" ||
       gameType == "killer"
```

### Step 2: Add Killer Ranking Logic
Add killer case to `rankedPlayers`:
```swift
else if gameType == "killer" {
    // For Killer: higher lives = better placement
    return summary.players.sorted { $0.finalScore > $1.finalScore }
}
```

### Step 3: Fix Killer Score Storage
**KillerViewModel.swift** line 335: Store remaining lives instead of 0:
```swift
finalScore: playerLives[player.id] ?? 0,  // Store remaining lives
```

## Files to Modify

1. **MatchCard.swift**
   - Add "killer" to `isRankingBasedGame`
   - Add killer ranking logic to `rankedPlayers`

2. **KillerViewModel.swift**  
   - Store remaining lives in `finalScore` instead of 0

## Expected Outcome

- **Killer games**: Show placement (1st, 2nd, 3rd) instead of meaningless scores
- **Winner**: Crown + "1st" 
- **Others**: "2nd", "3rd", etc. based on remaining lives
- **Consistent**: Same display pattern as other ranking games

## Benefits

- **Proper ranking**: Killer games show meaningful placement
- **Consistent UI**: Same as Knockout, Halve-It, Sudden Death
- **Logical**: Higher remaining lives = better placement
- **Complete**: All elimination-style games use ranking display
