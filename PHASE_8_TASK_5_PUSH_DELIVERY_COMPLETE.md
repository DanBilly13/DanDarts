# Phase 8 - Task 5: Push Delivery Edge Function - COMPLETE ✅

## Summary
Successfully implemented and tested the `send-push-notification` edge function that sends push notifications to users via APNs (Apple Push Notification service).

## What Was Built

### 1. Edge Function: `send-push-notification`
**Location:** `supabase/functions/send-push-notification/index.ts`

**Features:**
- ✅ JWT-based authentication (user must be signed in)
- ✅ APNs integration with ES256 JWT signing
- ✅ Environment-aware push endpoint selection (sandbox vs production)
- ✅ Push token loading from `push_tokens` table
- ✅ Delivery logging to `push_delivery_log` table
- ✅ Invalid token deactivation (410 Gone from APNs)
- ✅ Deduplication via APNs collapse-id header
- ✅ Comprehensive error handling and logging
- ✅ CORS support for cross-origin requests

**API Contract:**
```typescript
POST /functions/v1/push-notifications
Authorization: Bearer <user_jwt>
Content-Type: application/json

{
  "user_id": "uuid",
  "notification_type": "challenge_received" | "match_ready",
  "match_id": "uuid",
  "title": "string",
  "body": "string",
  "route": "remote" (optional),
  "highlight": "incoming" | "ready" (optional)
}

Response:
{
  "success": true,
  "message": "Push sent to X of Y device(s)",
  "tokens_sent": number,
  "tokens_failed": number,
  "results": [...]
}
```

### 2. Environment Variables (Supabase Secrets)
Required secrets configured in Supabase Dashboard:
- `APNS_KEY_ID` - APNs key ID from Apple Developer Portal
- `APNS_TEAM_ID` - Apple Team ID
- `APNS_BUNDLE_ID` - App bundle identifier (com.dandart.DanDart)
- `APNS_PRIVATE_KEY` - APNs .p8 private key (full PEM format)
- `SUPABASE_URL` - Auto-provided by Supabase
- `SUPABASE_ANON_KEY` - Auto-provided by Supabase
- `SUPABASE_SERVICE_ROLE_KEY` - Auto-provided by Supabase

### 3. APNs Payload Structure
```json
{
  "aps": {
    "alert": {
      "title": "Challenge from John!",
      "body": "John challenged you to a 501 match"
    },
    "sound": "default",
    "badge": 1
  },
  "type": "challenge_received",
  "matchId": "uuid",
  "route": "remote",
  "highlight": "incoming"
}
```

## Key Implementation Details

### Authentication Pattern (Critical Fix)
The edge function uses a **two-client pattern**:

1. **User Authentication Client** (anon key):
   ```typescript
   const supabaseClient = createClient(
     Deno.env.get('SUPABASE_URL') ?? '',
     Deno.env.get('SUPABASE_ANON_KEY') ?? '',
     {
       global: {
         headers: { Authorization: `Bearer ${jwt}` },
       },
     }
   )
   
   // CRITICAL: Must pass JWT as parameter
   const { data: { user }, error } = await supabaseClient.auth.getUser(jwt)
   ```

2. **Admin Client** (service role key):
   ```typescript
   const adminClient = createClient(
     Deno.env.get('SUPABASE_URL') ?? '',
     Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
   )
   
   // Use for cross-user database operations
   await adminClient.from('push_tokens').select('*').eq('user_id', targetUserId)
   ```

**Why this pattern?**
- User auth client verifies the caller is authenticated
- Admin client allows reading push tokens for ANY user (needed for sending to other players)
- RLS policies are bypassed with service role key

### APNs JWT Generation
Uses ES256 (ECDSA with P-256 and SHA-256):
1. Import private key from PEM format
2. Create JWT header with `alg: 'ES256'` and `kid: APNS_KEY_ID`
3. Create JWT payload with `iss: APNS_TEAM_ID` and `iat: timestamp`
4. Sign with `crypto.subtle.sign()`
5. Base64 URL encode all parts

### Token Management
- Loads active tokens from `push_tokens` table
- Sends to all active tokens for the target user
- Deactivates tokens that return 410 Gone (invalid/expired)
- Logs all delivery attempts to `push_delivery_log`

### Error Handling
- Returns 401 if caller not authenticated
- Returns 400 if required fields missing
- Returns 500 if token loading fails
- Catches and logs all APNs errors
- Continues sending to other tokens if one fails

## Testing Results

### Manual Test (curl)
```bash
curl -X POST https://sxovyuctkssdrendihag.supabase.co/functions/v1/push-notifications \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "22978663-6C1A-4D48-A717-BA5F18E9A1BB",
    "notification_type": "challenge_received",
    "match_id": "00000000-0000-0000-0000-000000000001",
    "title": "Test Push 🎯",
    "body": "Testing push notifications from edge function!"
  }'
```

**Result:** ✅ SUCCESS
```json
{
  "success": true,
  "message": "Push sent to 2 of 2 device(s)",
  "tokens_sent": 2,
  "tokens_failed": 0,
  "results": [
    {"success": true, "status": 200},
    {"success": true, "status": 200}
  ]
}
```

**Device Verification:** ✅ Push notification received on iPhone

### Supabase Logs
```
📥 [Push] Request received: POST
🔑 [Push] Auth header present: true
🔑 [Push] JWT extracted, length: 573
🔍 [Push] Calling auth.getUser(jwt)...
👤 [Push] User result: { hasUser: true, hasError: false }
✅ [Push] Authenticated user: 22978663-6c1a-4d48-a717-ba5f18e9a1bb
📤 [Push] Sending challenge_received to user 22978663... for match 00000000...
📱 [Push] Found 2 active token(s)
✅ [Push] Sent to device D548D2C6... (sandbox)
✅ [Push] Sent to device 3DC5D9A8... (sandbox)
📊 [Push] Results: 2 sent, 0 failed
```

## Debugging Journey

### Issue 1: AuthSessionMissingError
**Problem:** `auth.getUser()` was called without passing the JWT as a parameter.

**Fix:** Extract JWT from Authorization header and pass to `getUser(jwt)`:
```typescript
const jwt = authHeader.replace('Bearer ', '').trim()
const { data: { user } } = await supabaseClient.auth.getUser(jwt)
```

### Issue 2: Module Not Found
**Problem:** Supabase Dashboard editor couldn't resolve imports from `_shared/` folder.

**Fix:** Inline all shared types and CORS headers directly in `index.ts`.

## Database Records Created

### push_delivery_log entries
Two successful delivery records logged:
- `user_id`: 22978663-6C1A-4D48-A717-BA5F18E9A1BB
- `match_id`: 00000000-0000-0000-0000-000000000001
- `notification_type`: challenge_received
- `status`: sent
- `apns_status_code`: 200
- `device_install_id`: D548D2C6-9609-43C6-94B6-F351727FE1BF, 3DC5D9A8-...

## Next Steps

### Task 6: Wire Challenge Received Push
**Goal:** Call `send-push-notification` from `create-challenge` edge function when a challenge is created.

**Implementation:**
1. Update `create-challenge/index.ts`
2. After challenge created, invoke `send-push-notification` for receiver
3. Pass challenge details in notification payload
4. Handle errors gracefully (don't fail challenge creation if push fails)

### Task 7: Wire Match Ready Push
**Goal:** Call `send-push-notification` from `accept-challenge` edge function when match becomes ready.

**Implementation:**
1. Update `accept-challenge/index.ts`
2. After challenge accepted, invoke `send-push-notification` for challenger
3. Pass match details in notification payload
4. Handle errors gracefully

## Files Modified/Created

### Created:
- `supabase/functions/send-push-notification/index.ts` (342 lines)
- `supabase/functions/send-push-notification/README.md` (documentation)
- `PHASE_8_TASK_5_COMPLETE.md` (initial completion doc)
- `PHASE_8_TASK_5_PUSH_DELIVERY_COMPLETE.md` (this file)

### Modified:
- `DanDart/Services/AuthService.swift` (added JWT debug print)
- `DanDart/Views/Remote/RemoteGamesTab.swift` (added JWT debug call)

### Deployment:
- Edge function deployed via Supabase Dashboard editor
- All APNs secrets configured in Supabase Dashboard

## Acceptance Criteria ✅

- ✅ Edge function accepts user_id, notification_type, match_id, title, body
- ✅ Loads active push tokens for target user
- ✅ Sends push via APNs with proper JWT authentication
- ✅ Logs delivery attempts to push_delivery_log table
- ✅ Handles invalid tokens (deactivates on 410 Gone)
- ✅ Returns success/failure counts
- ✅ Works with sandbox environment (development builds)
- ✅ Tested end-to-end with curl and verified on device

## Status: COMPLETE ✅

Task 5 is fully implemented, tested, and verified working. Ready to proceed with Task 6 (wire challenge received) and Task 7 (wire match ready).

---

**Date Completed:** March 10, 2026
**Tested By:** User (manual curl test + device verification)
**Environment:** Sandbox (development)
