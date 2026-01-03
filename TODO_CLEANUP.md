# 🧹 Database Cleanup TODO

## Pending Cleanup Tasks

### 1. Drop Backup Table (After Testing)
**Created:** 2026-01-03  
**Test Period:** 3-7 days  
**Action Required:** Drop the backup table once confident everything works

**When to do this:**
- ✅ App has been tested thoroughly
- ✅ No issues with match data
- ✅ No RLS-related errors in logs
- ✅ At least 3-7 days have passed

**SQL to run:**
```sql
DROP TABLE IF EXISTS public.match_throws_backup_20260103;
```

**Why:** This backup table was created during RLS security fix (Migration 033). It's safe to delete once we're confident the fix works properly.

**Reminder Date:** 2026-01-10 (7 days from now)

---

## Completed Tasks
- [x] Fix RLS security warning for match_throws (2026-01-03)
- [x] Enable RLS on match_throws_backup_20260103 (2026-01-03)

---

## Notes
- Backup contains snapshot of match_throws from 2026-01-03
- Original security issue is RESOLVED
- This is just cleanup, not critical
