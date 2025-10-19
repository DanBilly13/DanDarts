# ✅ Complete Google Sign-In Setup

## What I've Done:
1. ✅ Updated AuthService with native Google Sign-In SDK implementation
2. ✅ Added GoogleSignIn import
3. ✅ Replaced web OAuth with native iOS flow
4. ✅ Created setup documentation

## What You Need to Do:

### Step 1: Add GoogleSignIn Package to Xcode
1. Open Xcode
2. Go to **File → Add Package Dependencies...**
3. Enter URL: `https://github.com/google/GoogleSignIn-iOS`
4. Click **Add Package**
5. Select **GoogleSignIn** library
6. Click **Add Package**

### Step 2: Get Your iOS Client ID
1. Go to Google Cloud Console: https://console.cloud.google.com/apis/credentials
2. Find your **iOS OAuth client** (the one you just created)
3. Copy the **Client ID** (looks like: `873425113437-xxxxx.apps.googleusercontent.com`)
4. Note the **iOS URL scheme** (reversed Client ID, like: `com.googleusercontent.apps.873425113437-xxxxx`)

### Step 3: Add Client ID to Info.plist
In Xcode:
1. Click on **DanDart** project in navigator
2. Select **DanDart** target
3. Go to **Info** tab
4. Find **Custom iOS Target Properties**
5. Click **+** to add new property
6. Key: `GOOGLE_CLIENT_ID`
7. Type: `String`
8. Value: Your iOS Client ID (from Step 2)

### Step 4: Add URL Scheme
Still in Info tab:
1. Scroll down to **URL Types**
2. Click **+** to add new URL Type
3. **Identifier**: `com.google.signin`
4. **URL Schemes**: Your reversed Client ID (from Step 2)
   - Example: `com.googleusercontent.apps.873425113437-h5avmtu297u914djmg0k952jubdk1k4p`

### Step 5: Add LSApplicationQueriesSchemes
Still in Info tab → Custom iOS Target Properties:
1. Click **+** to add new property
2. Key: `LSApplicationQueriesSchemes`
3. Type: `Array`
4. Add two items:
   - Item 0: `googlegmail` (String)
   - Item 1: `googlemail` (String)

### Step 6: Add Callback URL to Google Cloud Console
1. Go back to Google Cloud Console
2. Edit your **iOS OAuth client**
3. Under **Authorized redirect URIs**, add:
   - `https://sxovyuctkssdrencihag.supabase.co/auth/v1/callback`
4. Click **Save**

### Step 7: Test!
1. Build and run the app on a real device (Google Sign-In doesn't work well in simulator)
2. Tap "Sign in with Google"
3. You should see the native Google account picker
4. Select your account
5. The app should authenticate and create/fetch your profile

## Troubleshooting:

**Error: "No such module 'GoogleSignIn'"**
- Make sure you added the package in Step 1
- Clean build folder: Product → Clean Build Folder
- Restart Xcode

**Error: "Client ID not found"**
- Check that GOOGLE_CLIENT_ID is in Info.plist (Step 3)
- Make sure the value matches your iOS Client ID exactly

**Error: "redirect_uri_mismatch"**
- Make sure you added the Supabase callback URL to Google Cloud Console (Step 6)

**Google Sign-In doesn't open**
- Check URL scheme is correct (Step 4)
- Check LSApplicationQueriesSchemes is added (Step 5)
- Test on a real device, not simulator

## Need Help?
Let me know which step you're stuck on and I'll help troubleshoot!
