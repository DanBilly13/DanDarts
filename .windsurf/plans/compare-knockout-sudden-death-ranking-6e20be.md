# Compare Knockout vs Sudden Death Ranking Approach

**Analyze how different lives-based games handle ranking to understand Killer requirements.**

## Current Implementation Comparison

### Knockout
**Data Storage** (line 367):
```swift
finalScore: playerLives[player.id] ?? 0,  // Stores remaining lives
```

**Ranking Logic** (line 202-204):
```swift
if gameType == "knockout" {
    // For Knockout: higher lives = better placement
    return summary.players.sorted { $0.finalScore > $1.finalScore }
}
```

**Result**: ✅ Works correctly - higher remaining lives = better ranking

### Sudden Death  
**Data Storage** (line 462):
```swift
finalScore: finalScore,  // where finalScore = turns.last?.scoreAfter ?? 0
```

**Ranking Logic** (line 205-207):
```swift
else if gameType == "sudden death" || gameType == "sudden_death" {
    // For Sudden Death: higher lives = better placement
    return summary.players.sorted { $0.finalScore > $1.finalScore }
}
```

**Problem**: ❌ Comment says "higher lives" but stores accumulated score!

## Analysis of Sudden Death Issue

### What Sudden Death Actually Does
- Stores **accumulated round scores** in `finalScore`
- Ranking logic sorts by **accumulated score** (not lives)
- Comment is misleading - it's not sorting by lives

### Why This "Works" for Sudden Death
- Sudden Death eliminates players with **lowest scores each round**
- Higher accumulated score = survived more rounds = better placement
- So accumulated score correlates with elimination order

## Killer Application

### Option 1: Follow Knockout Pattern
Store remaining lives in `finalScore`:
```swift
finalScore: playerLives[player.id] ?? 0,
```

**Problem**: Multiple eliminated players all have 0 lives, no distinction

### Option 2: Follow Sudden Death Pattern  
Store something that correlates with elimination order:
```swift
finalScore: eliminationOrderBonus,  // Higher = eliminated later
```

**Challenge**: Need to track elimination order during gameplay

## Key Insight

**Knockout works because**: Remaining lives directly indicate ranking
**Sudden Death works because**: Accumulated score correlates with survival time  
**Killer challenge**: No direct correlation between final state and elimination order

## Conclusion

**Current approach won't work for Killer** because:
- Knockout method: All eliminated players have 0 lives (tie)
- Sudden Death method: No natural scoring correlation with elimination order

**Killer needs explicit elimination order tracking** to achieve meaningful ranking, similar to how Sudden Death uses accumulated score as a proxy for elimination time.

## Recommendation

**Don't add Killer to ranking games until**:
1. Explicit elimination order is tracked during gameplay, OR  
2. A proxy metric (like Sudden Death's accumulated score) is implemented that correlates with elimination order
