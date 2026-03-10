# APNs Push Notification Setup Guide
## Phase 8: Push Notifications for Remote Matches

This guide covers the setup required for Apple Push Notification service (APNs) integration.

---

## Prerequisites

- Apple Developer Account with admin access
- Access to Supabase project dashboard
- Xcode project with proper bundle identifier configured

---

## Step 1: Generate APNs Authentication Key (.p8)

### In Apple Developer Portal

1. Navigate to [Apple Developer Portal](https://developer.apple.com/account)
2. Go to **Certificates, Identifiers & Profiles**
3. Select **Keys** from the left sidebar
4. Click the **+** button to create a new key
5. Configure the key:
   - **Key Name:** DanDarts APNs Key (or similar descriptive name)
   - **Enable:** Apple Push Notifications service (APNs)
6. Click **Continue**, then **Register**
7. **Download the .p8 file immediately** (you can only download it once)
8. Note the following values (you'll need them later):
   - **Key ID:** 10-character identifier (e.g., `ABC123DEFG`)
   - **Team ID:** Found in the top-right of the developer portal (e.g., `XYZ987TEAM`)

### Important Notes

- The .p8 key file can only be downloaded once. Store it securely.
- Token-based authentication does not expire (unlike certificates)
- One .p8 key can be used for all apps under your team

---

## Step 2: Configure Supabase Environment Secrets

### In Supabase Dashboard

1. Navigate to your Supabase project dashboard
2. Go to **Settings** → **Edge Functions**
3. Add the following secrets:

```bash
# APNs Key ID (10-character identifier from Apple)
APNS_KEY_ID=ABC123DEFG

# Apple Developer Team ID
APNS_TEAM_ID=XYZ987TEAM

# APNs Private Key Content (entire .p8 file content)
APNS_P8_KEY=-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
(paste full key content here)
...
-----END PRIVATE KEY-----
```

### How to Extract .p8 Key Content

```bash
# Open the .p8 file in a text editor
cat AuthKey_ABC123DEFG.p8

# Copy the entire content including the BEGIN/END lines
# Paste into Supabase secret as a single value
```

---

## Step 3: Enable Push Notifications in Xcode

### In Xcode Project Settings

1. Open `DanDart.xcodeproj` in Xcode
2. Select the **DanDart** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Push Notifications**
6. Verify the capability appears in the list

### Verify Entitlements

The `DanDart.entitlements` file should include:

```xml
<key>aps-environment</key>
<string>development</string>
```

**Note:** This will automatically change to `production` for release builds.

---

## Step 4: Configure App ID in Apple Developer Portal

### Enable Push Notifications for App ID

1. Go to **Certificates, Identifiers & Profiles**
2. Select **Identifiers**
3. Find your app's identifier (e.g., `com.dandarts.app`)
4. Click to edit
5. Scroll to **Push Notifications** and enable it
6. Click **Save**

---

## Step 5: Verify Environment Configuration

### Debug Builds → Sandbox

Debug builds automatically use the APNs **sandbox** environment:
- Xcode builds with Debug configuration
- Tokens registered during development
- Endpoint: `https://api.sandbox.push.apple.com`

### Release Builds → Production

Release builds use the APNs **production** environment:
- TestFlight builds
- App Store builds
- Endpoint: `https://api.push.apple.com`

### Critical Warning

**TestFlight builds MUST use production APNs endpoint.**

Sandbox tokens will NOT work against production endpoint (and vice versa).

---

## Step 6: Test APNs Configuration

### Using Terminal (Optional Verification)

You can test APNs connectivity using curl:

```bash
# For sandbox environment
curl -v \
  --header "apns-topic: com.dandarts.app" \
  --header "apns-push-type: alert" \
  --header "authorization: bearer YOUR_JWT_TOKEN" \
  --data '{"aps":{"alert":"Test"}}' \
  --http2 \
  https://api.sandbox.push.apple.com/3/device/YOUR_DEVICE_TOKEN
```

### Expected Response

- **200 Success:** Push sent successfully
- **400 Bad Request:** Invalid token or payload
- **403 Forbidden:** Invalid APNs key or topic
- **410 Gone:** Device token is no longer valid

---

## Step 7: Database Migration

Run the following migrations in Supabase SQL Editor:

1. **068_create_push_tokens_table.sql** - Creates `push_tokens` table
2. **069_create_push_delivery_log_table.sql** - Creates `push_delivery_log` table

### Run Migrations

```sql
-- In Supabase Dashboard → SQL Editor
-- Copy and paste each migration file content
-- Execute in order (068, then 069)
```

---

## Troubleshooting

### Common Issues

**Issue:** "Invalid APNs key"
- **Solution:** Verify APNS_P8_KEY includes BEGIN/END lines and is properly formatted

**Issue:** "Topic disallowed"
- **Solution:** Ensure bundle identifier matches the APNs topic exactly

**Issue:** "Device token not for topic"
- **Solution:** Token was generated for different app/environment - regenerate token

**Issue:** "Sandbox token sent to production endpoint"
- **Solution:** Verify build configuration matches environment (Debug→sandbox, Release→production)

### Debug Logging

Enable verbose APNs logging in Edge Function:

```typescript
console.log('APNs Request:', {
  environment,
  token: deviceToken.substring(0, 10) + '...',
  endpoint: apnsEndpoint
})
```

---

## Security Best Practices

1. **Never commit .p8 key files to version control**
   - Add `*.p8` to `.gitignore`
   - Store keys in secure password manager

2. **Rotate keys periodically**
   - Generate new .p8 key annually
   - Update Supabase secrets
   - Old keys remain valid until revoked

3. **Restrict Supabase secret access**
   - Only team members who need access
   - Use separate keys for staging/production if needed

4. **Monitor push delivery logs**
   - Check `push_delivery_log` table for failures
   - Set up alerts for high error rates

---

## Next Steps

After completing this setup:

1. ✅ APNs key generated and stored in Supabase
2. ✅ Push Notifications capability enabled in Xcode
3. ✅ Database migrations run
4. ⏭️ Proceed to **Task 3:** Request notification permissions
5. ⏭️ Proceed to **Task 4:** Implement token sync

---

## Reference Links

- [Apple Push Notification Service Documentation](https://developer.apple.com/documentation/usernotifications)
- [APNs Provider API](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server)
- [Token-Based Authentication](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_token-based_connection_to_apns)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)

---

## Support

For issues specific to:
- **APNs setup:** Check Apple Developer Forums
- **Supabase configuration:** Check Supabase Discord/Docs
- **DanDarts implementation:** See Phase 8 task list and contract
