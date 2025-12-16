# Bug Fix: Match History Filtering

## Issue
Users were seeing ALL matches in the history tab instead of only matches they participated in.

## Root Causes

### 1. Player ID Mismatch
**Problem:** When saving matches, the `MatchPlayer` model used `player.id` (a random UUID) instead of `player.userId` (the user's account ID).

**Impact:** 
- Match filtering logic checked if user's account ID matched player IDs in the match
- Since player IDs were random UUIDs, no matches were found for any user
- All matches appeared as "local-only" matches

**Fix:** Updated `MatchPlayer.from()` in `MatchResult.swift` to use `player.userId ?? player.id`
```swift
id: player.userId ?? player.id  // Use userId for connected players, player.id for guests
```

### 2. Legacy Players JSONB Column
**Problem:** The `matches` table has a legacy `players` JSONB column that also stored player IDs using `player.id` instead of `player.userId`.

**Impact:** Client-side filtering parsed this JSONB and couldn't match user IDs

**Fix:** Updated `MatchService.swift` to use `player.userId ?? player.id` when creating the legacy players JSONB
```swift
"id": (player.userId ?? player.id).uuidString
```

### 3. RLS Policy Infinite Recursion
**Problem:** Initial RLS policy on `matches` table caused infinite recursion when checking `match_players` table.

**Fix:** Simplified RLS policy to allow all authenticated users to read matches, with client-side filtering handling user-specific matches
```sql
CREATE POLICY "Allow authenticated users to read matches"
ON matches FOR SELECT TO authenticated USING (true);
```

### 4. Double-Saving Matches
**Problem:** `saveMatchResult()` was being called twice, causing duplicate key constraint errors.

**Fix:** Added `hasBeenSaved` flag to `CountdownViewModel` to prevent duplicate saves
```swift
private var hasBeenSaved: Bool = false
guard !hasBeenSaved else { return }
hasBeenSaved = true
```

## Files Modified

### Core Fixes
- `DanDart/Models/MatchResult.swift` - Fixed `MatchPlayer.from()` to use userId
- `DanDart/Services/MatchService.swift` - Fixed legacy players JSONB and added delete-before-insert for duplicates
- `DanDart/ViewModels/Games/CountdownViewModel.swift` - Added double-save guard

### Testing Features (Temporary)
- `DanDart/Views/History/MatchHistoryView.swift` - Added toggle to hide local matches for testing
- `DanDart/Services/MatchesService.swift` - Added detailed logging for debugging

### Database
- `supabase_migrations/999_fix_matches_rls_policy.sql` - Fixed RLS policy

## Testing Results

✅ **Daniel** (user A) sees only his matches  
✅ **BoseBose** (user B) sees only matches he participated in  
✅ **Johan** (user C) sees 0 matches (didn't participate in any)  
✅ **Toggle button** correctly hides local-only matches  
✅ **Matches sync to Supabase** with correct player IDs  

## Migration Notes

**Old matches in the database have incorrect player IDs and will not be filtered correctly.**

To clean up:
```sql
DELETE FROM match_throws;
DELETE FROM match_players;
DELETE FROM matches;
```

All new matches saved after this fix will have correct player IDs and filtering will work properly.

## Technical Details

### Player ID Structure
- **Player.id** - Random UUID generated when Player object created (used for game logic)
- **Player.userId** - User's account ID from Supabase auth (used for match filtering)
- **Player.isGuest** - Boolean indicating if player is a guest (no userId)

### Match Filtering Logic
1. Query all matches from Supabase (RLS allows authenticated users to read)
2. Parse `players` JSONB column from each match
3. Check if current user's ID matches any non-guest player ID
4. Include match if user participated, skip if not
5. Client displays only matches where user participated

### Toggle Button (Temporary Testing Feature)
- **ON** (iPhone icon) - Shows all matches (local + Supabase)
- **OFF** (iPhone slash) - Shows only Supabase matches
- Helps distinguish between local-only and synced matches during testing
- Can be removed after testing phase

## Future Improvements

1. **Remove toggle button** after testing phase complete
2. **Fix turn data loading error** for BoseBose ("cannot extract elements from a scalar")
3. **Consider RLS policy refinement** to filter at database level instead of client-side (requires proper JSONB querying)
4. **Add migration script** to update old matches with correct player IDs (if needed)

## Date
December 16, 2025
