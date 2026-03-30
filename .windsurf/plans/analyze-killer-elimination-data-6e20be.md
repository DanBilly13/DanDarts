# Analyze Killer Elimination Order Data

**Investigate whether current saved Killer match data can determine true elimination order for ranking.**

## Current Data Structure Analysis

### What IS Stored
**MatchResult.turns** contains chronological turn data:
- Each turn has `turnNumber`, `darts`, timestamps
- Each dart has `KillerDartMetadata` with:
  - `outcome`: becameKiller, hitOwnNumber, hitOpponent, miss
  - `affectedPlayerIds`: victim IDs for hits

### What is NOT Stored
- Direct elimination order/timestamps
- Elimination sequence beyond turn chronology
- Final lives for eliminated players (all end at 0)

## Elimination Order Reconstruction

### Possible Approach: Turn-Based Analysis
**Algorithm**: Parse turn data chronologically to track elimination events:

1. **Initialize player lives** from `metadata["starting_lives"]`
2. **Process turns in sequence** (by `turnNumber` and player order)
3. **Track life changes** from `KillerDartMetadata.outcome`:
   - `hitOwnNumber`: Remove life from thrower
   - `hitOpponent`: Remove life(s) from `affectedPlayerIds`
4. **Record elimination order** when player lives reach 0
5. **Rank players**: Winner (1st) + elimination order for others

### Data Availability Check
**✅ Available:**
- Turn sequence (`turnNumber`)
- Life loss events (`hitOwnNumber`, `hitOpponent`)
- Victim identification (`affectedPlayerIds`)
- Starting lives (`metadata["starting_lives"]`)

**❌ Missing:**
- Direct elimination timestamps
- Final lives for non-winner (all stored as 0)

## Implementation Complexity

### High Complexity Approach
**Full elimination reconstruction:**
- Parse all turn data for each Killer match
- Simulate life tracking chronologically  
- Record elimination order
- Cache results for performance

**Pros:** Accurate elimination order
**Cons:** Complex, performance impact, requires turn data loading

### Low Complexity Approach  
**Use existing data with limitations:**
- Winner: Crown (already correct)
- Others: No meaningful ranking possible
- Fall back to original order or alphabetical

**Pros:** Simple, performant
**Cons:** No meaningful placement for eliminated players

## Recommendation

**Current Assessment:** The data CAN theoretically reconstruct elimination order, but it requires complex turn-by-turn analysis that may not be suitable for summary cards.

**Suggested Approach:** 
1. **Short-term**: Keep Killer out of ranking-based display until elimination order is properly tracked
2. **Long-term**: Add explicit elimination order tracking to game data

## Conclusion

**Current saved data has elimination information** but it's embedded in turn data and requires complex reconstruction. For reliable ranking display, Killer should either:

1. **Store elimination order directly** in match metadata, OR
2. **Remain excluded** from ranking-based display until proper tracking is implemented

The current approach of using `finalScore` (all 0s) for ranking would be incorrect and misleading.
