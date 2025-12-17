# Knockout Match History UI Fixes

## Issues Fixed

### 1. Missing Boxing Gloves (Life Loss Indicators)

**Problem:** Boxing glove icons were not showing in synced Knockout match history because the `is_bust` flag was not being saved to or loaded from the database.

**Root Cause:** 
- The `match_throws` table was missing the `is_bust` column
- When loading matches from Supabase, `isBust` was hardcoded to `false`
- When saving matches to Supabase, `is_bust` was not included in the data

**Solution:**
1. **Database Migration (032_add_is_bust_column.sql):**
   - Added `is_bust BOOLEAN NOT NULL DEFAULT false` column to `match_throws` table
   - Created index for querying busts

2. **Loading Fix (MatchesService.swift):**
   - Added `is_bust` to SELECT query (line 262)
   - Read `is_bust` from database response (line 309)
   - Pass `isBust` to MatchTurn constructor (line 325)

3. **Saving Fix (MatchService.swift):**
   - Added `is_bust: Bool` field to `MatchThrowRecord` struct (line 47)
   - Added `is_bust` to CodingKeys enum (line 57)
   - Save `turn.isBust` when creating throw records (line 202)

**Files Modified:**
- `supabase_migrations/032_add_is_bust_column.sql` (created)
- `Services/MatchesService.swift` (lines 262, 309, 325)
- `Services/MatchService.swift` (lines 47, 57, 112-146, 155-167, 202, 211, 258, 353-377)

---

### 2. Missing Profile Pictures (Avatar URLs)

**Problem:** Player avatars showed as generic gray person icons in synced match history because Apple Intelligence avatars were stored as local file paths that don't exist when loading from Supabase.

**Root Cause:**
- Apple Intelligence avatars are saved to temporary local files (e.g., `/var/mobile/.../tmp/avatar.png`)
- These file paths were saved to Supabase but don't exist on other devices or after app restart
- The `avatarURL` field in the players JSONB was missing, so even valid URLs weren't being saved

**Solution:**
1. **Upload Local Avatars (MatchService.swift lines 112-146):**
   - Before syncing a match, check each player's `avatarURL`
   - If it's a local file path, upload the image to Supabase storage
   - Replace the local path with the Supabase URL
   - Use the updated URLs when saving the match

2. **Include avatarURL in Players JSONB (MatchService.swift lines 155-167):**
   - Added `avatarURL` field to the legacy players JSONB data
   - This ensures avatar URLs are saved and loaded correctly

3. **Avatar Upload Helper (MatchService.swift lines 353-377):**
   - New `uploadPlayerAvatar()` function uploads images to Supabase storage
   - Generates unique filenames using player ID and timestamp
   - Returns public URL for the uploaded avatar

---

## Testing Instructions

1. **Run Database Migration:**
   ```sql
   -- Run in Supabase SQL Editor
   -- File: supabase_migrations/032_add_is_bust_column.sql
   ```

2. **Play a New Knockout Match:**
   - Use players with Apple Intelligence avatars or uploaded photos
   - Complete a match where players lose lives
   - Match will sync to Supabase with:
     - `is_bust` flags for life losses
     - Uploaded avatar URLs (not local file paths)

3. **Verify Both Fixes:**
   - Navigate to History tab
   - View the Knockout match
   - **Boxing gloves** should appear next to scores where players lost lives
   - **Profile pictures** should display correctly (not gray person icons)
   - Check console logs for avatar upload confirmations:
     - `📤 Uploading local avatar for [Name]`
     - `✅ Avatar uploaded: https://...supabase.co/storage/...`

4. **For Existing Matches:**
   - Old matches will have `is_bust = false` for all turns (no boxing gloves)
   - Old matches may still have broken avatar URLs (local file paths)
   - Play new matches to see both fixes in action

---

## Technical Details

### Boxing Glove Display Logic (KnockoutMatchDetailView.swift)

Lines 203-229 show boxing gloves based on `livesLostUpToThisRound`:
- Counts turns where `isBust = true`
- Shows one boxing glove per life lost
- For winners: replaces last glove with crown icon

### Data Flow

**Saving:**
1. KnockoutViewModel records turns with `isBust` flag
2. MatchService converts to MatchThrowRecord with `is_bust`
3. Supabase stores in `match_throws.is_bust` column

**Loading:**
1. MatchesService queries `match_throws` including `is_bust`
2. Parses response and creates MatchTurn with `isBust`
3. KnockoutMatchDetailView counts busts and displays boxing gloves

---

---

### 3. Sudden Death Match History Display

**Problem:** Eliminated players were appearing in rounds after they were knocked out, showing as black bars with 0 scores or skulls.

**Root Cause:**
- The `isPlayerAliveInRound()` function was checking if a player had lives remaining **before** the round started
- This caused eliminated players to appear in the round where they were eliminated, even though they didn't play
- The logic didn't account for the fact that eliminated players have no turns recorded for subsequent rounds

**Solution (SuddenDeathMatchDetailView.swift lines 260-265):**
- Changed logic to check if player has a turn recorded for that round
- Now only shows players who actually played in each round
- Eliminated players correctly disappear from subsequent rounds

**Before:**
```swift
private func isPlayerAliveInRound(player: MatchPlayer, roundNumber: Int) -> Bool {
    let livesLostBeforeThisRound = countLivesLost(player: player, upToRound: roundNumber - 1)
    return livesLostBeforeThisRound < startingLives
}
```

**After:**
```swift
private func isPlayerAliveInRound(player: MatchPlayer, roundNumber: Int) -> Bool {
    // Player is alive in a round if they have a turn recorded for that round
    let turnIndex = roundNumber - 1
    return turnIndex < player.turns.count
}
```

---

## Status

✅ Boxing gloves issue - FIXED
✅ Avatar images issue - FIXED
✅ Sudden Death display issue - FIXED
