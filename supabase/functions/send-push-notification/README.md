# send-push-notification Edge Function

## Purpose
Sends push notifications to users via Apple Push Notification service (APNs). This function is invoked explicitly by other edge functions (e.g., `accept-challenge`, `create-challenge`) when push-worthy events occur.

## Architecture
- **Provider:** Direct APNs (not FCM)
- **Authentication:** JWT-based using ES256 signing with APNs auth key
- **Environment handling:** Supports both sandbox (dev/debug) and production (TestFlight/App Store)
- **Delivery logging:** All attempts logged to `push_delivery_log` table
- **Invalid token handling:** Automatically deactivates tokens that return 410 Gone from APNs

## Required Environment Variables

You must set these in the Supabase Edge Functions secrets:

```bash
# APNs Authentication
APNS_KEY_ID=ABC123XYZ        # Your APNs Key ID (10 characters)
APNS_TEAM_ID=DEF456UVW       # Your Apple Team ID (10 characters)
APNS_BUNDLE_ID=com.yourdomain.dandart  # Your app's bundle identifier

# APNs Private Key (P8 file contents)
APNS_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
-----END PRIVATE KEY-----"
```

### How to get these values:

1. **APNS_KEY_ID & APNS_PRIVATE_KEY:**
   - Go to [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list)
   - Create a new key with "Apple Push Notifications service (APNs)" enabled
   - Download the `.p8` file (you can only download once!)
   - The filename contains your Key ID: `AuthKey_ABC123XYZ.p8`
   - The file contents are your `APNS_PRIVATE_KEY`

2. **APNS_TEAM_ID:**
   - Found in [Apple Developer Membership](https://developer.apple.com/account/#/membership/)
   - 10-character alphanumeric string

3. **APNS_BUNDLE_ID:**
   - Your app's bundle identifier from Xcode
   - Must match exactly what's in your app

### Setting secrets in Supabase:

```bash
# Using Supabase CLI
supabase secrets set APNS_KEY_ID=ABC123XYZ
supabase secrets set APNS_TEAM_ID=DEF456UVW
supabase secrets set APNS_BUNDLE_ID=com.yourdomain.dandart
supabase secrets set APNS_PRIVATE_KEY="$(cat AuthKey_ABC123XYZ.p8)"
```

Or set them in the Supabase Dashboard under Edge Functions → Settings → Secrets.

## Request Format

```typescript
POST /send-push-notification
Authorization: Bearer <user-jwt>
Content-Type: application/json

{
  "user_id": "uuid-of-target-user",
  "notification_type": "challenge_received" | "match_ready",
  "match_id": "uuid-of-match",
  "title": "New Challenge!",
  "body": "John Doe challenged you to a game of 501",
  "route": "remote",           // optional, defaults to "remote"
  "highlight": "incoming"      // optional, defaults based on type
}
```

## Response Format

### Success (200)
```json
{
  "success": true,
  "message": "Push sent to 2 of 2 device(s)",
  "tokens_sent": 2,
  "tokens_failed": 0,
  "results": [
    { "success": true, "status": 200 },
    { "success": true, "status": 200 }
  ]
}
```

### No Active Tokens (200)
```json
{
  "success": true,
  "message": "No active tokens to send to",
  "tokens_sent": 0
}
```

### Error (4xx/5xx)
```json
{
  "error": "Error message",
  "details": { /* additional error info */ }
}
```

## APNs Payload Structure

The function sends this payload to APNs:

```json
{
  "aps": {
    "alert": {
      "title": "New Challenge!",
      "body": "John Doe challenged you to a game of 501"
    },
    "sound": "default",
    "badge": 1
  },
  "type": "challenge_received",
  "matchId": "uuid-of-match",
  "route": "remote",
  "highlight": "incoming"
}
```

The custom fields (`type`, `matchId`, `route`, `highlight`) are used by the iOS app for deep linking and card highlighting.

## Token Management

### Active Tokens
- Function only sends to tokens where `is_active = true`
- Tokens are loaded from `push_tokens` table filtered by `user_id`

### Invalid Token Handling
- If APNs returns 410 Gone (invalid token), the function automatically sets `is_active = false`
- This prevents future send attempts to dead tokens

### Environment Routing
- Sandbox tokens → `https://api.sandbox.push.apple.com`
- Production tokens → `https://api.push.apple.com`
- Environment is stored in `push_tokens.environment` field

## Delivery Logging

Every send attempt is logged to `push_delivery_log`:

```sql
INSERT INTO push_delivery_log (
  user_id,
  match_id,
  notification_type,
  device_install_id,
  push_token_id,
  status,              -- 'sent' or 'failed'
  apns_status_code,    -- HTTP status from APNs
  error_message,       -- Error details if failed
  payload              -- Full APNs payload sent
)
```

This provides full observability for debugging delivery issues.

## Deduplication

APNs handles deduplication using the `apns-collapse-id` header:
- Set to `match-{matchId}`
- Multiple pushes for the same match will collapse to the latest one
- Prevents notification spam if multiple events fire quickly

## Integration Example

From `accept-challenge/index.ts`:

```typescript
// After successfully accepting challenge...

// Send push to challenger
const pushResponse = await supabaseClient.functions.invoke('send-push-notification', {
  body: {
    user_id: match.challenger_id,
    notification_type: 'match_ready',
    match_id: match_id,
    title: 'Match Ready!',
    body: `${receiverName} accepted your challenge`,
    route: 'remote',
    highlight: 'ready',
  }
})

if (pushResponse.error) {
  console.error('Push notification failed:', pushResponse.error)
  // Don't fail the main operation - push is best-effort
}
```

## Testing

### Test with a known token:

```bash
curl -X POST https://your-project.supabase.co/functions/v1/send-push-notification \
  -H "Authorization: Bearer YOUR_USER_JWT" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user-uuid-here",
    "notification_type": "challenge_received",
    "match_id": "match-uuid-here",
    "title": "Test Push",
    "body": "This is a test notification"
  }'
```

### Check logs:

```bash
supabase functions logs send-push-notification
```

Look for:
- `📤 [Push] Sending...` - Function invoked
- `📱 [Push] Found X active token(s)` - Tokens loaded
- `✅ [Push] Sent to device...` - Success
- `❌ [Push] Failed to send...` - Failure
- `📊 [Push] Results: X sent, Y failed` - Summary

## Troubleshooting

### No tokens found
- User hasn't granted notification permission
- Token sync failed (check `push_tokens` table)
- Token was deactivated due to previous 410 response

### 403 Forbidden from APNs
- Invalid APNs credentials
- Check `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`
- Verify key has APNs capability enabled

### 400 Bad Request from APNs
- Invalid device token format
- Malformed payload
- Check logs for APNs error details

### Wrong environment
- Sandbox tokens won't work with production endpoint and vice versa
- Verify `push_tokens.environment` matches your build type
- Debug builds → sandbox
- TestFlight/App Store → production

### JWT signing errors
- Private key format issue
- Ensure key includes `-----BEGIN PRIVATE KEY-----` header/footer
- No extra whitespace or newlines in secret value

## Security Notes

- Function requires valid user authentication (JWT)
- Uses service role key to access all user tokens (admin operation)
- APNs private key is stored as environment secret (never in code)
- Tokens are never exposed in responses or logs (only device_install_id prefix)

## Performance

- Sends to all active tokens in parallel (for multi-device users)
- Each APNs request has ~100ms latency
- Function timeout: 60 seconds (Supabase default)
- Typical execution: < 500ms for 1-2 devices

## Future Enhancements

Potential improvements (not in v1):
- Batch sending for multiple users
- Retry logic for transient failures
- Rate limiting per user
- Notification categories for interactive actions
- Silent pushes for background updates
- Analytics integration
