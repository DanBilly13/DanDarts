# Expired Match Lock Cleanup Fix

## Issue
Users with expired matches couldn't create new challenges because stale locks in `remote_match_locks` table weren't being cleaned up.

**Error:** `RemoteMatchError.alreadyHasActiveMatch` (error 6)

**From logs:**
```
🔍 Found 1 locks for user 22978663-6C1A-4D48-A717-BA5F18E9A1BB
❌ createChallenge threw error: alreadyHasActiveMatch
```

## Root Cause

When matches expire (via `challenge_expires_at` or `join_window_expires_at`), the locks in `remote_match_locks` table were not being deleted. The `create-challenge` edge function checks for existing locks before allowing new challenges, and it was finding these stale locks from expired matches.

**Lifecycle gap:**
1. Match created → lock created ✓
2. Match expires → **lock NOT deleted** ✗
3. User tries to create new challenge → finds stale lock → rejects ✗

## Solution

Added **defensive cleanup logic** to `create-challenge` edge function that runs **before** checking for active locks:

1. Query all locks for the current user
2. For each lock, fetch the associated match
3. Check if match is expired/cancelled/completed
4. Delete locks for finished matches
5. Then proceed with normal lock validation

This ensures stale locks are cleaned up automatically when users try to create new challenges.

## Implementation

### File: `/supabase/functions/create-challenge/index.ts`

**Added at lines 93-133:**

```typescript
// Clean up any locks for expired matches before checking
const { data: userLocks } = await supabaseClient
  .from('remote_match_locks')
  .select('match_id')
  .eq('user_id', user.id)

if (userLocks && userLocks.length > 0) {
  // Check each lock's match to see if it's expired
  const lockMatchIds = userLocks.map((lock: any) => lock.match_id)
  
  const { data: lockMatches } = await supabaseClient
    .from('matches')
    .select('id, remote_status, challenge_expires_at, join_window_expires_at')
    .in('id', lockMatchIds)
  
  const now = new Date()
  const expiredMatchIds: string[] = []
  
  lockMatches?.forEach((match: any) => {
    const isExpired = 
      (match.challenge_expires_at && new Date(match.challenge_expires_at) < now) ||
      (match.join_window_expires_at && new Date(match.join_window_expires_at) < now) ||
      match.remote_status === 'expired' ||
      match.remote_status === 'cancelled' ||
      match.remote_status === 'completed'
    
    if (isExpired) {
      expiredMatchIds.push(match.id)
    }
  })
  
  // Delete locks for expired/finished matches
  if (expiredMatchIds.length > 0) {
    await supabaseClient
      .from('remote_match_locks')
      .delete()
      .in('match_id', expiredMatchIds)
    
    console.log(`🧹 Cleaned up ${expiredMatchIds.length} expired locks for user ${user.id}`)
  }
}

// Now check if user has any remaining active locks
const { data: existingLock, error: lockCheckError } = await supabaseClient
  .from('remote_match_locks')
  .select('*')
  .eq('user_id', user.id)
  .maybeSingle()
```

## What Gets Cleaned Up

Locks are deleted if the associated match is:
- **Expired by time:** `challenge_expires_at` or `join_window_expires_at` in the past
- **Expired by status:** `remote_status` is `'expired'`, `'cancelled'`, or `'completed'`

## Benefits

1. **User-friendly:** Users can create new challenges even if old ones expired
2. **Defensive:** Cleans up stale data before validation
3. **Self-healing:** Automatically fixes the problem when encountered
4. **Simple:** No need for cron jobs or database triggers (yet)
5. **Safe:** Only deletes locks for truly finished matches

## Expected Behavior After Fix

**Before:**
1. User has expired match with stale lock
2. Try to create new challenge → Error: "You already have a match ready"
3. User stuck, cannot create challenges

**After:**
1. User has expired match with stale lock
2. Try to create new challenge → Cleanup runs automatically
3. Stale lock deleted
4. New challenge created successfully ✓

**Console output:**
```
🧹 Cleaned up 1 expired locks for user 22978663-6C1A-4D48-A717-BA5F18E9A1BB
✅ Challenge created: [new-match-id]
```

## Testing

After deploying this fix:
- [ ] User with expired match can create new challenge
- [ ] Cleanup log appears in edge function console
- [ ] New challenge creates successfully
- [ ] No stale locks remain in database
- [ ] Subsequent challenges work normally

## Future Improvements

While this defensive cleanup works, consider adding:

1. **Database trigger:** Auto-delete locks when match status changes to expired/cancelled/completed
2. **Cron job:** Periodic cleanup of all expired locks (mentioned in FRD TODO)
3. **Cancel-match cleanup:** Ensure `cancel-match` edge function also cleans up locks (already does)
4. **Complete-match cleanup:** Add lock cleanup when match completes

For now, the defensive cleanup in `create-challenge` solves the immediate problem.

## Files Modified

1. `/supabase/functions/create-challenge/index.ts` - Added expired lock cleanup logic

---

**Status:** ✅ Implementation Complete - Ready for Deployment

**Next Step:** Deploy updated `create-challenge` edge function to Supabase
