# Multi-Leg Match Supabase Sync Fix

## Issue
Multi-leg matches (Best of 3, 5, 7) were not syncing properly to Supabase, causing errors when viewing match history.

## Root Cause
The Supabase `matches` table was missing the `match_format` and `total_legs_played` columns that were added to the local `MatchResult` model in Tasks 201-202.

## Solution

### 1. Database Migration (Required)
Run the new migration to add multi-leg fields to Supabase:

**File:** `/supabase_migrations/005_add_multi_leg_fields.sql`

This migration adds:
- `match_format` column (INTEGER, default 1) - Total legs in match (1, 3, 5, or 7)
- `total_legs_played` column (INTEGER, default 1) - Actual number of legs played
- Index on `match_format` for filtering

**How to run:**
1. Open Supabase Dashboard → SQL Editor
2. Copy contents of `005_add_multi_leg_fields.sql`
3. Execute the SQL
4. Verify success message appears

### 2. Code Changes

**SupabaseMatch Model Updated:**
- Added `matchFormat: Int` field
- Added `totalLegsPlayed: Int` field
- Updated `CodingKeys` with snake_case mapping (`match_format`, `total_legs_played`)
- Updated `toMatchResult()` to include these fields

**MatchesService Updated:**
- `syncMatch()` now includes `matchFormat` and `totalLegsPlayed` when creating SupabaseMatch
- `loadMatches()` automatically deserializes these fields from Supabase

### 3. Data Flow

**Saving Multi-Leg Match:**
```
GameViewModel.saveMatchResult()
  ↓
MatchStorageManager.saveMatch()
  ↓
MatchesService.syncMatch()
  ↓
Supabase INSERT with match_format and total_legs_played
```

**Loading Match History:**
```
MatchHistoryView.loadMatches()
  ↓
MatchesService.loadMatches()
  ↓
Supabase SELECT (includes match_format and total_legs_played)
  ↓
SupabaseMatch.toMatchResult()
  ↓
Display with full multi-leg data
```

### 4. What's Included in Players JSONB

Each player in the `players` JSONB array includes:
```json
{
  "id": "uuid",
  "displayName": "string",
  "nickname": "string",
  "avatarURL": "string?",
  "isGuest": bool,
  "finalScore": int,
  "startingScore": int,
  "totalDartsThrown": int,
  "turns": [...],
  "legsWon": int  // ← Already included from Task 201
}
```

## Testing

### Test Single-Leg Match (Best of 1)
1. Play a 301 game with Best of 1 format
2. Complete the game
3. Check match history - should display normally
4. Verify in Supabase: `match_format = 1`, `total_legs_played = 1`

### Test Multi-Leg Match (Best of 3)
1. Play a 301 game with Best of 3 format
2. Win 2 legs (e.g., 2-0 or 2-1)
3. Check match history - should display "Wins 2-0" or "Wins 2-1"
4. Verify in Supabase: `match_format = 3`, `total_legs_played = 2 or 3`
5. Verify each player has correct `legsWon` count in JSONB

### Test Multi-Leg Match (Best of 5)
1. Play a 301 game with Best of 5 format
2. Win 3 legs (e.g., 3-0, 3-1, or 3-2)
3. Check match history - should display correct score
4. Verify in Supabase: `match_format = 5`, `total_legs_played = 3, 4, or 5`

## Backwards Compatibility

**Existing Matches:**
- Old matches in Supabase will have `match_format = 1` and `total_legs_played = 1` (default values)
- They will display as single-leg matches (correct behavior)
- No data migration needed

**Local Matches:**
- Local JSON matches already have `matchFormat` and `totalLegsPlayed` fields (added in Task 201)
- They will sync correctly to Supabase with new schema

## Files Modified

1. **New Migration:**
   - `/supabase_migrations/005_add_multi_leg_fields.sql`

2. **Updated Code:**
   - `/Services/MatchesService.swift` - SupabaseMatch model and syncMatch() method

3. **Documentation:**
   - `/MULTI_LEG_SUPABASE_FIX.md` (this file)

## Status
✅ Schema updated
✅ Model updated
✅ Sync logic updated
✅ Load logic updated
⚠️ **Migration Required** - Run `005_add_multi_leg_fields.sql` in Supabase

## Next Steps
1. Run the SQL migration in Supabase Dashboard
2. Test multi-leg match sync
3. Verify match history displays correctly
4. Check that both local and cloud matches show proper leg scores
