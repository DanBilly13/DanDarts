# Head-to-Head Winner ID Fix

**Date:** January 4, 2026  
**Issue:** Pull-to-refresh shows 0-0 stats temporarily before loading correct data

## Root Cause

Local matches stored `winnerId` as `Player.id` (instance ID), while Supabase matches stored `winnerId` as `Player.userId` (account ID). This ID format mismatch caused stats calculation to fail when displaying local matches.

**Example:**
- Local: `winnerId = AEB767B1-4D2E-...` (Player.id)
- Supabase: `winnerId = 22978663-8B4A-...` (Player.userId)
- Stats comparison: `player.id == winnerId` → ❌ Mismatch

## The Problem Flow

1. User pulls to refresh on FriendProfileView
2. `loadHeadToHeadMatchesAsync()` loads local matches first (for instant display)
3. Local matches have wrong `winnerId` format
4. Stats calculation fails → shows 0-0
5. Supabase data loads → shows correct stats (but flash already happened)

## The Solution

Changed all game ViewModels to use consistent ID format for both local and Supabase storage:

```swift
// Before (WRONG)
winnerId: winner.id

// After (CORRECT)
winnerId: winner.userId ?? winner.id
```

This ensures:
- **Connected players:** `winnerId = userId` (account ID)
- **Guest players:** `winnerId = player.id` (instance ID)
- **Both storage types use same format** ✅

## Files Modified

1. **CountdownViewModel.swift** (301/501 games)
   - Line 653: `winnerId: winner.userId ?? winner.id`
   - Line 664: `updatePlayerStats(..., winnerId: winner.userId ?? winner.id)`

2. **HalveItViewModel.swift**
   - Line 269: `winnerId: winner.userId ?? winner.id`

3. **KnockoutViewModel.swift**
   - Line 341: `winnerId: winner.userId ?? winner.id`
   - Line 353: `updatePlayerStats(..., winnerId: winner.userId ?? winner.id)`

4. **SuddenDeathViewModel.swift**
   - Line 398: `winnerId: winner.userId ?? winner.id`
   - Line 407: `updatePlayerStats(..., winnerId: winner.userId ?? winner.id)`

5. **KillerViewModel.swift**
   - Line 295: `updatePlayerStats(..., winnerId: matchPlayerId(for: winner))`
   - (Already used `matchPlayerId()` helper for `winnerId` at line 286)

## Why This Is Safe

1. **`MatchPlayer.id` already uses correct format** via `MatchPlayer.from()`:
   ```swift
   id: player.userId ?? player.id  // Line 189 of MatchResult.swift
   ```

2. **All comparisons work correctly:**
   - `MatchStorageManager.updatePlayerStats`: `player.id == winnerId` ✅
   - `MatchService.updatePlayerStats`: `userId == winnerId` ✅
   - `FriendProfileView` stats: Matches user account IDs ✅
   - UI display: `player.id == winnerId` ✅

3. **Existing local matches:**
   - Will continue to show 0-0 until replaced by Supabase data
   - This is acceptable (temporary, auto-fixed on sync)
   - New matches will be saved correctly going forward

## Expected Behavior After Fix

### Pull-to-Refresh:
1. Loads local matches → **shows correct stats immediately** ✅
2. Loads Supabase matches → merges seamlessly (same format)
3. **No 0-0 flash** ✅

### Navigate Away & Back:
1. Loads from cache → **shows correct stats** ✅
2. No reload needed

### After New Match:
1. Match saved with correct `winnerId` format ✅
2. Cache invalidated
3. Auto-reload shows updated stats ✅

## Testing Checklist

- [ ] Play a match between two registered users
- [ ] Navigate to FriendProfileView
- [ ] Verify stats display correctly (e.g., "1-0")
- [ ] Navigate away and back → stats still correct (cached)
- [ ] Pull-to-refresh → **no 0-0 flash**, stats remain correct
- [ ] Play another match
- [ ] Stats auto-update correctly (e.g., "2-0" or "1-1")

## Status

✅ **Fix implemented across all 5 game ViewModels**  
✅ **Consistent ID format for local and Supabase storage**  
✅ **No breaking changes to existing functionality**  
✅ **Ready for testing**
