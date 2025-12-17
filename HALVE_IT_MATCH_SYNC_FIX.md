# Halve-It Match Sync Bug Fix

## Problem Summary

After a Halve-It match was synced to Supabase and the local copy was deleted, viewing the match details showed:
- 0% target hit rates
- Missing round-by-round breakdown
- Crowns displayed for players who missed all darts (should show halved score)

## Root Causes

### 1. PostgreSQL Query Error (Primary Issue)

**Error:** `PostgrestError(code: "22023", message: "cannot extract elements from a scalar")`

**Cause:** The Supabase Swift client's query with explicit column selection was causing PostgREST to apply PostgreSQL array operators on the JSONB `throws` column, resulting in a type mismatch error.

**Original Query:**
```swift
.select("id, match_id, player_order, turn_index, throws, score_before, score_after, game_metadata")
```

**Fix:** Changed to `SELECT *` to let PostgREST handle JSONB columns correctly:
```swift
.select("*")
```

**Result:** Data now loads successfully from Supabase with all turn data and `targetDisplay` metadata intact.

### 2. Crown Display Bug (Secondary Issue)

**Problem:** The `RoundScoreDisplay` component showed a crown icon when `score == 0`, but in Halve-It:
- Score of 0 means the player **missed all darts and their score was halved** (penalty)
- NOT a round winner

**Cause:** The component was designed for 301/501 games where 0 = winner, but was incorrectly reused for Halve-It.

**Fix:** Added `showCrownForZero` parameter (default `true` for backward compatibility):

```swift
struct RoundScoreDisplay: View {
    let showCrownForZero: Bool
    
    init(score: Int, playerColor: Color, showCrownForZero: Bool = true) {
        // ...
    }
    
    var body: some View {
        if score == 0 && showCrownForZero {
            Image(systemName: "crown.fill") // Only for 301/501
        } else {
            Text("\(score)") // Always show score for Halve-It
        }
    }
}
```

Updated `HalveItRoundCard` to pass `showCrownForZero: false`:
```swift
RoundScoreDisplay(score: playerData[rowIndex].score, 
                  playerColor: playerData[rowIndex].color, 
                  showCrownForZero: false)
```

## Files Modified

1. **MatchesService.swift** (line 238)
   - Changed `SELECT` query from explicit columns to `SELECT *`
   - Removed debug logging

2. **RoundScoreDisplay.swift** (lines 15-21)
   - Added `showCrownForZero` parameter
   - Updated crown display logic

3. **HalveItRoundCard.swift** (lines 74, 77, 80)
   - Pass `showCrownForZero: false` for Halve-It matches

4. **MatchService.swift** (lines 197-217)
   - Removed debug logging

5. **MatchHistoryView.swift** (lines 438-441)
   - Removed debug logging

## Database Notes

- The `match_throws.throws` column is JSONB (migration 020)
- Data saves correctly with `targetDisplay` in `game_metadata`
- PostgREST requires `SELECT *` to properly handle JSONB arrays
- No database schema changes were needed for the fix

## Testing Verification

✅ New Halve-It matches save correctly to Supabase
✅ Match details load after sync with complete turn data
✅ Target hit rates calculate correctly
✅ Round-by-round breakdown displays properly
✅ Scores show correctly (no crowns for halved players)
✅ Old broken matches can be deleted and replaced

## Key Learnings

1. **PostgREST JSONB Handling:** Explicit column selection in queries can cause PostgREST to misinterpret JSONB columns as native PostgreSQL arrays, leading to type errors. Using `SELECT *` avoids this issue.

2. **Component Reusability:** UI components designed for one game type may have assumptions that don't apply to others. Always verify game-specific logic when reusing components.

3. **Debug Logging Strategy:** Comprehensive logging at data flow boundaries (save, load, merge) is essential for diagnosing data persistence issues.

## Date
December 17, 2025
