# Bug Fix: Sign-In Network Error for Existing Users

## Issue
User "david smith" (and potentially other users) gets a "network connection error" when trying to sign in with valid email/password credentials.

## Root Cause
During the signup process, if there was a database timeout or error when inserting the user profile into the `users` table, the signup would continue anyway (lines 126-137 in AuthService). This resulted in:

1. User account created in Supabase Auth ✅
2. User profile NOT created in `users` table ❌

When the user tries to sign in:
1. Auth succeeds (credentials are valid) ✅
2. Query to fetch user profile from `users` table fails ❌
3. Error is caught and converted to "network connection error"

### The Problematic Code:
```swift
// During signup:
do {
    try await supabaseService.client
        .from("users")
        .insert(newUser)
        .execute()
} catch {
    print("⚠️ Database insert error (but might have succeeded): \(error)")
    // The insert might have worked even if we got a timeout
    // Let's continue anyway  ← THIS CAUSES THE PROBLEM
}
```

## Solution
Made the sign-in process more robust by automatically creating a user profile if it doesn't exist during sign-in. This handles cases where signup partially failed.

### Changes Made:

**AuthService.swift - signIn() method:**

**Before:**
```swift
// 2. Fetch user profile from users table
let userProfile: User = try await supabaseService.client
    .from("users")
    .select()
    .eq("id", value: user.id)
    .single()
    .execute()
    .value
```

**After:**
```swift
// 2. Fetch user profile from users table
let userProfile: User
do {
    userProfile = try await supabaseService.client
        .from("users")
        .select()
        .eq("id", value: user.id)
        .single()
        .execute()
        .value
    
    print("✅ User profile fetched: \(userProfile.displayName)")
} catch {
    // User profile doesn't exist - this can happen if signup partially failed
    print("⚠️ User profile not found in database, creating it now...")
    
    // Create a basic user profile from auth data
    let newUser = User(
        id: user.id,
        displayName: user.email?.components(separatedBy: "@").first ?? "User",
        nickname: user.email?.components(separatedBy: "@").first?.lowercased() ?? "user\(Int.random(in: 1000...9999))",
        handle: nil,
        avatarURL: nil,
        createdAt: Date(),
        lastSeenAt: Date(),
        totalWins: 0,
        totalLosses: 0
    )
    
    try await supabaseService.client
        .from("users")
        .insert(newUser)
        .execute()
    
    print("✅ User profile created: \(newUser.displayName)")
    userProfile = newUser
}
```

## How It Works Now

### Sign-In Flow (User Profile Missing):
1. User enters email/password
2. Supabase Auth validates credentials ✅
3. Try to fetch user profile from `users` table
4. Profile not found → Catch error
5. Create basic user profile from auth data:
   - `displayName`: Email prefix (e.g., "david" from "david@example.com")
   - `nickname`: Lowercase email prefix or random (e.g., "david" or "user1234")
   - Other fields: Default values
6. Insert profile into `users` table ✅
7. Set current user and authenticate ✅
8. User can now sign in successfully ✅

### Sign-In Flow (User Profile Exists):
1. User enters email/password
2. Supabase Auth validates credentials ✅
3. Fetch user profile from `users` table ✅
4. Set current user and authenticate ✅
5. Navigate to MainTabView ✅

## Additional Improvements

Added comprehensive debug logging to trace the sign-in flow:
- "🔐 Attempting sign in for email: ..."
- "✅ Auth successful, user ID: ..."
- "📥 Fetching user profile from database..."
- "✅ User profile fetched: ..." OR "⚠️ User profile not found, creating..."
- "🎉 Sign in complete!"

This helps diagnose any future authentication issues.

## Testing

**Test Case 1: Normal Sign-In (Profile Exists)**
- User signs in with valid credentials
- Profile fetched from database
- Navigate to MainTabView ✅

**Test Case 2: Sign-In with Missing Profile**
- User has auth account but no database profile
- Profile automatically created during sign-in
- Navigate to MainTabView ✅
- User can update profile later

**Test Case 3: Invalid Credentials**
- User enters wrong password
- Auth fails with "Invalid credentials" error ✅

## Files Modified
- **AuthService.swift** - Updated `signIn()` method to handle missing user profiles

## Benefits
1. **Resilient to partial signup failures** - Users can always sign in even if database insert failed
2. **Self-healing** - Missing profiles are automatically created
3. **Better debugging** - Comprehensive logging helps diagnose issues
4. **No data loss** - User accounts are never orphaned

## Note for Future
Consider improving the signup process to ensure the database insert always succeeds, or implement a retry mechanism. However, this fix ensures users are never locked out even if signup partially fails.
