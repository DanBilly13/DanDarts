# Friend Request Push Notifications - Deployment Instructions

## ✅ Changes Completed

### 1. Client-Side (iOS)
- **FriendsService.swift** - Updated to call `push-notifications` (matches deployed function)
- **NotificationService.swift** - Made `NotificationRouteIntent` support optional `matchId`
- **NotificationPayloadParser.swift** - Added friend request type detection
- **MainTabView.swift** - Updated navigation routing
- **RemoteNotificationIntentConsumer.swift** - Added guard for optional `matchId`

### 2. Server-Side (Edge Function)
- **Folder renamed:** `send-push-notification/` → `push-notifications/`
- **Updated `push-notifications/index.ts`** with:
  - Optional `match_id` in `PushPayload` interface
  - Added `'friend_request_received'` notification type
  - Conditional `matchId` in APNs payload: `...(payload.match_id && { matchId: payload.match_id })`
  - Updated validation to not require `match_id`
  - Updated logging for optional match ID
  - Null-safe delivery logging

---

## 🚀 Deployment Steps

### Deploy the Updated Edge Function

```bash
cd /Users/billinghamdaniel/Documents/Windsurf/DanDart
supabase functions deploy push-notifications
```

**Expected output:**
```
Deploying function push-notifications...
Function push-notifications deployed successfully!
```

---

## 🧪 Testing

### Test Friend Request Push Notification

1. **Send a friend request** from User A to User B
2. **User B should:**
   - Hear notification sound ✅
   - See notification banner ✅ (this was the bug we fixed)
   - Tap notification → navigate to Friends tab

### Verify in Logs

```bash
supabase functions logs push-notifications --tail
```

Look for:
```
📤 [Push] Sending friend_request_received to user xxxxxxxx... (no match ID)
📱 [Push] Found X active token(s)
✅ [Push] Sent to device xxxxxxxx... (sandbox)
📊 [Push] Results: 1 sent, 0 failed
```

---

## 🔍 What Was Fixed

### The Root Cause
The Edge Function was sending `matchId: undefined` in the APNs payload for friend requests because:
1. FriendsService wasn't sending `match_id` (correct - friend requests don't have one)
2. Edge Function was always including `matchId: payload.match_id` (incorrect - sent `undefined`)
3. APNs rejected malformed payloads → sound played but no banner

### The Solution
```typescript
// Before (broken)
const apnsPayload = {
  aps: { ... },
  type: payload.notification_type,
  matchId: payload.match_id,  // ❌ undefined for friend requests
  ...
}

// After (fixed)
const apnsPayload = {
  aps: { ... },
  type: payload.notification_type,
  ...(payload.match_id && { matchId: payload.match_id }),  // ✅ Only include if present
  ...
}
```

---

## 📋 Verification Checklist

After deployment, verify:

- [ ] Friend request push shows banner when app is closed/background
- [ ] Friend request push shows banner when app is in foreground
- [ ] Tapping notification navigates to Friends tab
- [ ] Remote match pushes still work (challenge_received, match_ready)
- [ ] Push delivery logged to `push_delivery_log` table
- [ ] No errors in Edge Function logs

---

## 🔄 Rollback (if needed)

If something breaks:

```bash
# Revert to previous version
git checkout HEAD~1 supabase/functions/push-notifications/index.ts
supabase functions deploy push-notifications
```

---

## 📝 Files Modified

**Client (iOS):**
1. `DanDart/Services/FriendsService.swift`
2. `DanDart/Services/NotificationService.swift`
3. `DanDart/Services/NotificationPayloadParser.swift`
4. `DanDart/Views/MainTabView.swift`
5. `DanDart/Views/Remote/RemoteNotificationIntentConsumer.swift`

**Server (Edge Function):**
1. `supabase/functions/push-notifications/index.ts` (renamed from `send-push-notification/`)

---

## 🎉 Expected Behavior After Deployment

### Friend Request Flow
1. User A sends friend request to User B
2. Edge Function called with:
   ```json
   {
     "user_id": "user-b-id",
     "notification_type": "friend_request_received",
     "title": "Friend request from User A",
     "body": "User A wants to be friends",
     "route": "friends",
     "highlight": "friend_request"
   }
   ```
3. APNs payload sent (no `matchId` field):
   ```json
   {
     "aps": {
       "alert": {
         "title": "Friend request from User A",
         "body": "User A wants to be friends"
       },
       "sound": "default",
       "badge": 1
     },
     "type": "friend_request_received",
     "route": "friends",
     "highlight": "friend_request"
   }
   ```
4. User B receives notification with banner ✅
5. Tap → Navigate to Friends tab ✅

### Remote Match Flow (Unchanged)
1. User A challenges User B
2. Edge Function called with `match_id`
3. APNs payload includes `matchId` field
4. User B receives notification
5. Tap → Navigate to Remote tab, scroll to match ✅

---

**Status:** Ready for deployment! 🚀
