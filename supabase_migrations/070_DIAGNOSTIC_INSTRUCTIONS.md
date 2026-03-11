# Migration 070: match_players RLS Diagnostic Instructions

## Purpose

Diagnose why local match saves fail with RLS error 42501 on `match_players` table.

## Error Context

```
❌ Failed to save match to Supabase: PostgrestError(
  code: "42501", 
  message: "new row violates row-level security policy for table \"match_players\""
)
```

## How to Run

1. Open Supabase Dashboard → SQL Editor
2. Copy contents of `070_diagnose_match_players_rls.sql`
3. Paste and run
4. Review output in "Results" panel

## What It Checks

1. **RLS Status** - Is Row Level Security enabled on `match_players`?
2. **Active Policies** - What policies currently exist?
3. **INSERT Policy** - Is there a policy allowing authenticated users to INSERT?
4. **Policy Conflicts** - Are there duplicate or conflicting policies?
5. **Recommendations** - What action to take based on findings

## Expected Output

The diagnostic will show tables with:
- RLS enabled/disabled status
- List of all policies on `match_players`
- Specific INSERT policy details
- Count of INSERT policies (should be 1)
- Recommendations for next steps

## Interpretation Guide

### Scenario A: RLS Disabled
```
RLS Enabled: false
INSERT Policies: 0
```
**Meaning:** RLS is off, error shouldn't occur
**Action:** Investigate if error comes from different source (maybe `matches` or `match_throws`)

### Scenario B: RLS Enabled, No INSERT Policy
```
RLS Enabled: true
INSERT Policies: 0
```
**Meaning:** RLS is on but no INSERT policy exists
**Action:** Run migration 071 to create INSERT policy

### Scenario C: RLS Enabled, Policy Exists
```
RLS Enabled: true
INSERT Policies: 1
Expected Policy Exists: true
```
**Meaning:** Policy exists, check `with_check_expression` in output
**Action:** 
- If `WITH CHECK = true` → Policy is correct, investigate further
- If `WITH CHECK` has conditions → Policy is too restrictive, fix it

### Scenario D: Multiple INSERT Policies
```
RLS Enabled: true
INSERT Policies: 2+
```
**Meaning:** Conflicting policies from different migrations
**Action:** Drop duplicates, keep correct one

## Next Steps

After running diagnostic:

1. **Share the output** - Copy results and share findings
2. **Wait for migration 071** - Fix will be created based on diagnostic results
3. **Test the fix** - Play a local match to verify

## Files

- **Diagnostic:** `070_diagnose_match_players_rls.sql` (this migration)
- **Fix:** `071_fix_match_players_insert_policy.sql` (created after diagnostic)

## Notes

- This diagnostic makes **NO changes** to the database
- Safe to run multiple times
- Output includes detailed recommendations
- Fix migration will be tailored to your specific findings
