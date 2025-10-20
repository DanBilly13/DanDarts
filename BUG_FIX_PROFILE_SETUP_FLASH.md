# Bug Fix: Profile Setup View Flash on Signup

## Issue
When signing up with email, the "Complete Your Profile" view appeared for about half a second before immediately navigating to the games tab.

## Root Cause
The authentication flow was setting `isAuthenticated = true` immediately after successful signup, which caused `ContentView` to switch from showing the auth flow to showing `MainTabView` before `ProfileSetupView` could be properly displayed.

### Flow Before Fix:
1. User completes signup form
2. `SignUpView` calls `authService.signUp()`
3. `AuthService.signUp()` creates user and calls `updateAuthenticationState()`
4. `isAuthenticated` becomes `true` immediately
5. `ContentView` switches to `MainTabView` (because `isAuthenticated == true`)
6. Meanwhile, `SignUpView` tries to show `ProfileSetupView` as a sheet
7. Result: Brief flash of `ProfileSetupView` before it's dismissed

## Solution
Introduced a new `needsProfileSetup` flag in `AuthService` to track when a user has signed up but hasn't completed profile setup yet. The user is only marked as authenticated after they complete or skip profile setup.

### Flow After Fix:
1. User completes signup form
2. `SignUpView` calls `authService.signUp()`
3. `AuthService.signUp()` creates user and sets `needsProfileSetup = true` (but NOT `isAuthenticated`)
4. `SignUpView` dismisses
5. `ContentView` shows `ProfileSetupView` (because `needsProfileSetup == true`)
6. User completes or skips profile setup
7. `AuthService` sets `needsProfileSetup = false` and `isAuthenticated = true`
8. `ContentView` switches to `MainTabView`

## Files Modified

### 1. AuthService.swift
- **Added:** `@Published var needsProfileSetup: Bool = false`
- **Modified:** `signUp()` - Sets `needsProfileSetup = true` instead of calling `updateAuthenticationState()`
- **Modified:** `signInWithGoogle()` - For new users, sets `needsProfileSetup = true` instead of authenticating
- **Modified:** `updateProfile()` - Calls `completeProfileSetup()` after successful profile update
- **Added:** `completeProfileSetup()` - Sets `needsProfileSetup = false` and calls `updateAuthenticationState()`

### 2. ContentView.swift
- **Added:** Check for `needsProfileSetup` state
- **Modified:** Navigation logic to show `ProfileSetupView` when `needsProfileSetup == true`

### 3. ProfileSetupView.swift
- **Modified:** `handleSkipSetup()` - Calls `authService.completeProfileSetup()` to properly complete setup

### 4. SignUpView.swift
- **Removed:** `@State private var showingProfileSetup` (no longer needed)
- **Removed:** `.sheet(isPresented: $showingProfileSetup)` presentation
- **Modified:** `handleSignUp()` - Simply dismisses after successful signup
- **Modified:** `handleGoogleSignUp()` - Simply dismisses after successful auth

## Testing Checklist
- [ ] Email signup → ProfileSetupView appears without flash
- [ ] Complete profile setup → Navigate to MainTabView
- [ ] Skip profile setup → Navigate to MainTabView
- [ ] Google signup (new user) → ProfileSetupView appears
- [ ] Google signin (existing user) → Navigate directly to MainTabView
- [ ] Email signin (existing user) → Navigate directly to MainTabView

## Benefits
1. **No more flash** - ProfileSetupView is shown at the root level by ContentView
2. **Cleaner architecture** - Single source of truth for navigation state
3. **Consistent flow** - Same behavior for email and Google signup
4. **Better UX** - Smooth transition between signup and profile setup
