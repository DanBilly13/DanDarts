# Google Sign-In Setup for iOS

## Step 1: Add GoogleSignIn Package

In Xcode:
1. File → Add Package Dependencies
2. Enter URL: `https://github.com/google/GoogleSignIn-iOS`
3. Version: Up to Next Major (7.0.0 or later)
4. Add both **GoogleSignIn** and **GoogleSignInSwift** to DanDart target

## Step 2: Configure URL Scheme

### Get your iOS Client ID from Google Cloud Console:
1. Go to: https://console.cloud.google.com/apis/credentials
2. Find your iOS OAuth client
3. Copy the **Client ID** (looks like: `123456-abc.apps.googleusercontent.com`)
4. Copy the **iOS URL scheme** (the reversed Client ID)

### Add URL Scheme to Xcode:
1. Open project settings (click on DanDart project in navigator)
2. Select **DanDart** target
3. Go to **Info** tab
4. Expand **URL Types**
5. Click **+** to add new URL Type
6. **Identifier**: `com.google.signin`
7. **URL Schemes**: Enter your **reversed Client ID**
   - Example: If Client ID is `123456-abc.apps.googleusercontent.com`
   - URL Scheme is: `com.googleusercontent.apps.123456-abc`

## Step 3: Add Google Client ID to Project

You need to add your Google Client ID to the app. Two options:

### Option A: Create GoogleService-Info.plist
1. Download from Firebase Console (if using Firebase)
2. Add to project

### Option B: Add to Config.plist or Environment
Add `GOOGLE_CLIENT_ID` with your iOS Client ID value

## Step 4: Update Info.plist Queries

In Xcode project settings → Info → Custom iOS Target Properties:
Add `LSApplicationQueriesSchemes` array with:
- `googlegmail`
- `googlemail`

Or add this to Info.plist:
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>googlegmail</string>
    <string>googlemail</string>
</array>
```

## Step 5: Test

Run the app and try Google Sign-In!
