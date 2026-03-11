# Migration 071: Create match_players INSERT Policy

## Quick Start

1. Open Supabase Dashboard → SQL Editor
2. Copy contents of `071_create_match_players_insert_policy.sql`
3. Paste and run
4. Verify output shows "STATUS: SUCCESS"

## What This Does

Creates the missing INSERT policy that allows authenticated users to insert into `match_players` table.

**Policy Details:**
- Name: `"Authenticated users can insert match_players"`
- Scope: `FOR INSERT TO authenticated`
- Condition: `WITH CHECK (true)` (permissive)

## Expected Output

```
=== MIGRATION 071 COMPLETE ===
Policy Exists: true
INSERT Policy Count: 1
STATUS: SUCCESS

Next Steps:
1. Test local match save in app
2. Verify console shows no 42501 error
3. Check player/friend stats update correctly
```

## Testing After Migration

### 1. Test Match Save
- Build and run app in Xcode
- Play a local match with a friend
- Check console for:
  ```
  ✅ Inserted 2 participants into match_participants table
  ✅ Match saved successfully
  ✅ Updated stats for [Player]: XW/YL
  ```
- Should see NO 42501 error

### 2. Test Player Profile Stats
- Navigate to your profile
- Verify W/L stats updated correctly
- Should show new totals immediately

### 3. Test Friend Profile Stats
- Navigate to friend's profile (tap their card in Friends tab)
- Verify their W/L stats updated
- Should reflect the match result

### 4. Test Friends List Stats
- Go to Friends tab
- Check friend's card shows updated stats
- Should match their profile stats

## If Migration Fails

Check the output for:
- "ERROR - No INSERT policy found" → Policy creation failed, check permissions
- "WARNING - Multiple INSERT policies" → Duplicate policies, may need cleanup
- "Policy Exists: false" → Creation failed, review error messages above

## Rollback (if needed)

```sql
DROP POLICY IF EXISTS "Authenticated users can insert match_players" ON public.match_players;
```

This will restore the broken state (RLS enabled, no INSERT policy).

## Related Files

- **Diagnostic:** `070_diagnose_match_players_rls.sql`
- **Fix:** `071_create_match_players_insert_policy.sql` (this migration)
- **Instructions:** `070_DIAGNOSTIC_INSTRUCTIONS.md`
