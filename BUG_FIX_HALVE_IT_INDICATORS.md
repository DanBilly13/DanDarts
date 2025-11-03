# Bug Fix: Halve It Dart Hit Indicators Not Showing

## Problem

After changing the match storage system to delete local matches once uploaded to Supabase, the Halve It game's dart hit indicators stopped showing correctly in the match detail view. The indicators (3 dots showing which darts hit/missed the target) were not displaying what actually happened during the game.

## Root Cause

There were TWO issues:

### Issue 1: Turn data not being loaded from Supabase

The `loadMatches()` method in `MatchesService.swift` was only loading basic match info from the `matches` table, which includes a JSONB `players` column with minimal player data (id, displayName, nickname, isGuest) but **NO turn data**. The turn data exists in the `match_throws` table but wasn't being loaded.

### Issue 2: Saving ALL darts instead of just hits (MAIN ISSUE)

When saving Halve-It matches locally and to Supabase, the code was saving ALL darts thrown with their actual values, not just whether they hit the target:

**Example:**
- Target for round: 7
- Player throws: 20 (miss), 7 (HIT!), 15 (miss)
- What was saved: `[MatchDart(20), MatchDart(7), MatchDart(15)]` with values `[20, 7, 15]`
- Hit detection logic: `value > 0` → `[true, true, true]` ❌ WRONG!
- What should show: Only middle dart hit → `[false, true, false]`

The problem: **ALL darts have a value > 0**, so they all appeared as hits!

## Solution

Two fixes were required:

### Fix 1: Load turn data from match_throws table (MatchesService.swift)

1. **Added `loadTurnsForMatch()` method** (lines 211-299):
   - Queries the `match_throws` table for turn data
   - Groups throws by player_order
   - Reconstructs `MatchTurn` objects with:
     - Dart scores converted to `MatchDart` objects
     - Score before/after
     - Target display (from game_metadata)
   - Returns players with complete turn history

2. **Updated `loadMatches()` method** (lines 110-209):
   - Now calls `loadTurnsForMatch()` for each match
   - Loads metadata field (for Halve-It difficulty)
   - Creates `MatchResult` with complete player turn data

### Fix 2: Save only target hits, not all darts (HalveItViewModel.swift)

**Updated `saveMatchResult()` method** (lines 226-234):

Changed from saving all darts:
```swift
let darts = turn.darts.map { dart in
    MatchDart(
        baseValue: dart.baseValue,
        multiplier: dart.scoreType.multiplier
    )
}
```

To saving only hits (misses get value 0):
```swift
let darts = turn.darts.map { dart in
    let hitTarget = turn.target.isHit(by: dart)
    return MatchDart(
        baseValue: hitTarget ? dart.baseValue : 0,
        multiplier: hitTarget ? dart.scoreType.multiplier : 1
    )
}
```

**How it works:**
- If dart hit target: Save actual value (e.g., `MatchDart(7, 1)` → value = 7)
- If dart missed target: Save zero (e.g., `MatchDart(0, 1)` → value = 0)
- Hit detection: `value > 0` now correctly identifies only hits!

### How It Works:

```swift
// For each match loaded:
1. Load basic match info from matches table
2. Load basic player info from players JSONB column
3. Query match_throws table for turn data (NEW)
4. Reconstruct MatchTurn objects with darts (NEW)
5. Create MatchPlayer objects with complete turn history (NEW)
6. Create MatchResult with full data
```

### Dart Hit Detection:

The dart hit indicators work by checking if `dart.value > 0`:

```swift
// In HalveItMatchDetailView.swift (line 192)
let hitSequence: [Bool] = turn?.darts.map { $0.value > 0 } ?? []
```

When loading from Supabase:
- We only have total dart scores (e.g., `[20, 40, 0]`)
- We create `MatchDart(baseValue: score, multiplier: 1)`
- This gives `value = score * 1 = score`
- So `value > 0` correctly identifies hits vs misses

### Limitations:

- We lose the double/triple distinction when loading from Supabase (we only store total values in `match_throws.throws`)
- For Halve-It, this doesn't matter because we only care if the dart hit the target (value > 0)
- For 301/501 games, this is also acceptable since we display the total score

## Testing

After this fix:
1. Play a Halve-It game
2. Match is saved to Supabase and deleted locally
3. View match history (loads from Supabase)
4. Open match detail view
5. Dart hit indicators should now correctly show which darts hit/missed

## Files Modified

- `/DanDart/Services/MatchesService.swift`
  - Added `loadTurnsForMatch()` method
  - Updated `loadMatches()` to load turn data
  - Added metadata parsing

- `/DanDart/ViewModels/Games/HalveItViewModel.swift`
  - Updated `saveMatchResult()` to save only target hits (lines 226-234)
  - Darts that miss the target now save as value 0

- `/DanDart/Views/History/HalveItMatchDetailView.swift`
  - Fixed score display to show cumulative score (line 199)
  - Changed from `scoreAfter - scoreBefore` to just `scoreAfter`

## Related Issues

This bug appeared after implementing the change to delete local matches once uploaded to Supabase (to avoid duplication and save storage space). The fix ensures that all match data, including turn-by-turn details, is properly reconstructed when loading from the cloud.

### Additional Fix #1: Score Display

After fixing the dart indicators, a second issue was discovered: the round-by-round breakdown was showing points scored **in that round** instead of the **cumulative score**. 

For example:
- Round 1: Hit 7 → Should show 7 (cumulative)
- Round 2: Miss all → Should show 4 (halved from 7)
- Round 3: Hit 10 → Should show 14 (4 + 10)

The fix was simple: use `scoreAfter` directly instead of calculating `scoreAfter - scoreBefore`.

### Additional Fix #2: Missing finalScore and startingScore

A third issue was discovered: the `players` JSONB column in the `matches` table only stores minimal player data (id, displayName, nickname, isGuest) and does NOT include `finalScore` or `startingScore`. This caused incorrect score displays when loading matches from Supabase.

**The fix** (MatchesService.swift, lines 282-285):
Calculate these values from the turn data instead of using the (missing) values from the JSONB:

```swift
// Calculate final score and starting score from turn data
let startingScore = turns.first?.scoreBefore ?? 0
let finalScore = turns.last?.scoreAfter ?? 0
```

This ensures the scores are always correct, derived directly from the actual game data stored in `match_throws`.
