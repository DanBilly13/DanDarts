---
trigger: manual
---

# DanDarts Development Task List

## Instructions
- Complete tasks sequentially in order
- Check off subtasks as completed
- Task is only complete when all acceptance criteria are met
- Get approval before moving to next major task
- Dependencies noted where applicable

---

## Phase 1: Project Setup & Foundation

### Task 1: Initialize Xcode Project
- [ ] Create new iOS App project in Xcode
- [ ] Set app name: "DanDarts"
- [ ] Set bundle identifier: com.yourname.dandarts
- [ ] Set deployment target: iOS 17.0
- [ ] Choose SwiftUI interface and Swift language
- [ ] Initialize Git repository

**Acceptance Criteria:**
- ✓ Project builds successfully
- ✓ Empty app launches on simulator
- ✓ Git repository initialized with .gitignore

---

### Task 2: Configure Project Structure
- [ ] Create folder structure in Xcode:
  - Views/
  - ViewModels/
  - Models/
  - Services/
  - Utilities/
  - Resources/
- [ ] Add .gitignore for Xcode projects
- [ ] Create README.md with project description

**Acceptance Criteria:**
- ✓ Folder structure visible in Xcode navigator
- ✓ Project organization clear and logical

---

### Task 3: Set Up Color Assets
- [ ] Open Assets.xcassets
- [ ] Create Color Set: "AccentPrimary" (#0A84FF)
- [ ] Create Color Set: "AccentSecondary" (#FF9500)
- [ ] Create Color Set: "BackgroundPrimary" (#0A0A0F)
- [ ] Create Color Set: "SurfacePrimary" (#1C1C1E)
- [ ] Create Color Set: "TextPrimary" (White)
- [ ] Create Color Set: "TextSecondary" (White 70% opacity)
- [ ] Test colors in preview

**Acceptance Criteria:**
- ✓ All colors accessible via Color("ColorName")
- ✓ Colors match design spec
- ✓ Dark mode support configured

---

### Task 4: Add Supabase Dependency
- [ ] Open project settings > Package Dependencies
- [ ] Add Supabase Swift SDK via SPM
- [ ] URL: https://github.com/supabase/supabase-swift
- [ ] Select latest stable version
- [ ] Add to target: DanDarts
- [ ] Wait for package resolution

**Acceptance Criteria:**
- ✓ Package successfully added
- ✓ `import Supabase` compiles without errors
- ✓ No build warnings

---

### Task 5: Create Supabase Configuration
- [ ] Create file: Services/SupabaseService.swift
- [ ] Add Supabase URL and anon key as constants (use placeholders for now)
- [ ] Create singleton SupabaseClient instance
- [ ] Add TODO comments for environment variables

**Acceptance Criteria:**
- ✓ SupabaseService compiles
- ✓ Can access shared client instance
- ✓ Ready for actual credentials

**Dependencies:** Task 4

---

## Phase 2: Authentication System

### Task 6: Create User Model
- [ ] Create file: Models/User.swift
- [ ] Define User struct: id, displayName, nickname, avatarURL, totalWins, totalLosses
- [ ] Make Codable and Identifiable
- [ ] Add mock data for preview

**Acceptance Criteria:**
- ✓ User model compiles
- ✓ All properties match database schema
- ✓ Codable for JSON encoding/decoding

---

### Task 7: Create Auth Service
- [ ] Create file: Services/AuthService.swift
- [ ] Make ObservableObject with @Published currentUser
- [ ] Add @Published isAuthenticated: Bool
- [ ] Add @Published isLoading: Bool
- [ ] Create method stubs: signUp, signIn, signInWithGoogle, signOut, checkSession

**Acceptance Criteria:**
- ✓ AuthService compiles
- ✓ Can be injected as @EnvironmentObject
- ✓ Published properties trigger view updates

**Dependencies:** Task 6

---

### Task 8: Implement Sign Up Method
- [ ] Implement signUp(email:password:displayName:nickname:) async throws
- [ ] Call supabase.auth.signUp
- [ ] Create profile record in profiles table
- [ ] Store session token in Keychain
- [ ] Set currentUser and isAuthenticated
- [ ] Add error handling

**Acceptance Criteria:**
- ✓ Method compiles and handles async/await
- ✓ Error handling for network and validation errors
- ✓ Sets authentication state correctly

**Dependencies:** Task 7

---

### Task 9: Implement Sign In Method
- [ ] Implement signIn(email:password:) async throws
- [ ] Call supabase.auth.signIn
- [ ] Fetch user profile from profiles table
- [ ] Store session in Keychain
- [ ] Set currentUser and isAuthenticated
- [ ] Add error handling

**Acceptance Criteria:**
- ✓ Method compiles
- ✓ Error handling for invalid credentials
- ✓ Successfully authenticates test user

**Dependencies:** Task 7

---

### Task 10: Implement Session Check
- [ ] Implement checkSession() async
- [ ] Check Keychain for existing session
- [ ] Validate session with Supabase
- [ ] Fetch user profile if valid
- [ ] Set authentication state
- [ ] Handle expired sessions

**Acceptance Criteria:**
- ✓ Correctly detects existing sessions
- ✓ Handles expired/invalid sessions gracefully
- ✓ Auto-refreshes valid sessions

**Dependencies:** Task 7

---

### Task 11: Implement Sign Out
- [ ] Implement signOut() async
- [ ] Call supabase.auth.signOut()
- [ ] Clear Keychain session
- [ ] Reset currentUser to nil
- [ ] Set isAuthenticated to false

**Acceptance Criteria:**
- ✓ Clears all auth state
- ✓ Navigates to welcome screen
- ✓ No errors on logout

**Dependencies:** Task 7

---

## Phase 3: Splash & Welcome Screens

### Task 12: Create Splash Screen
- [ ] Create file: Views/SplashView.swift
- [ ] Add app logo text "DanDarts" with large bold font
- [ ] Add SF Symbol dartboard icon (or "target")
- [ ] Add ProgressView (loading indicator)
- [ ] Style with dark background

**Acceptance Criteria:**
- ✓ Splash screen matches design spec
- ✓ Centered content
- ✓ Loading indicator visible

---

### Task 13: Implement Splash Screen Logic
- [ ] Add onAppear modifier to SplashView
- [ ] Call AuthService.checkSession()
- [ ] Add 1-2 second minimum display time
- [ ] Navigate based on auth state (authenticated → Games, not authenticated → Welcome)
- [ ] Use @EnvironmentObject for AuthService

**Acceptance Criteria:**
- ✓ Checks session on launch
- ✓ Navigates correctly based on auth state
- ✓ No flicker or navigation bugs

**Dependencies:** Task 10, Task 12

---

### Task 14: Create Welcome Screen
- [ ] Create file: Views/WelcomeView.swift
- [ ] Add app logo and tagline
- [ ] Add "Sign In" button (accent color)
- [ ] Add "Sign Up" button (accent color)
- [ ] Add "Continue as Guest" text button
- [ ] Style with dark background

**Acceptance Criteria:**
- ✓ Layout matches design spec
- ✓ All buttons present and styled
- ✓ Responsive to different screen sizes

---

### Task 15: Implement Welcome Screen Navigation
- [ ] Add @State for showing SignInView
- [ ] Add @State for showing SignUpView
- [ ] Add sheet modifier for SignInView
- [ ] Add sheet modifier for SignUpView
- [ ] Wire up "Continue as Guest" to navigate to GamesTab
- [ ] Add button actions

**Acceptance Criteria:**
- ✓ Tapping "Sign In" shows sign in sheet
- ✓ Tapping "Sign Up" shows sign up sheet
- ✓ "Continue as Guest" navigates to app
- ✓ Sheets dismiss properly

**Dependencies:** Task 14

---

## Phase 4: Sign In & Sign Up Screens

### Task 16: Create Sign In Screen
- [ ] Create file: Views/Auth/SignInView.swift
- [ ] Add email TextField
- [ ] Add password SecureField
- [ ] Add "Sign In" button
- [ ] Add "Sign in with Google" button
- [ ] Add "Don't have an account? Sign Up" link
- [ ] Add "Continue as Guest" link
- [ ] Style inputs and buttons per design spec

**Acceptance Criteria:**
- ✓ Form layout matches design
- ✓ All fields and buttons present
- ✓ Keyboard types correct (email for email field)

---

### Task 17: Implement Sign In Logic
- [ ] Add @State for email and password
- [ ] Add @State for error message
- [ ] Add @State for isLoading
- [ ] Add @EnvironmentObject for AuthService
- [ ] Implement signIn button action (call AuthService.signIn)
- [ ] Show loading state during sign in
- [ ] Display error messages if sign in fails
- [ ] Dismiss sheet on success

**Acceptance Criteria:**
- ✓ Sign in works with valid credentials
- ✓ Shows error for invalid credentials
- ✓ Loading indicator appears during request
- ✓ Navigates to app on success

**Dependencies:** Task 9, Task 16

---

### Task 18: Create Sign Up Screen
- [ ] Create file: Views/Auth/SignUpView.swift
- [ ] Add display name TextField
- [ ] Add nickname TextField (with @ prefix hint)
- [ ] Add email TextField
- [ ] Add password SecureField
- [ ] Add confirm password SecureField
- [ ] Add "Create Account" button
- [ ] Add "Already have an account? Sign In" link
- [ ] Style per design spec

**Acceptance Criteria:**
- ✓ Form layout matches design
- ✓ All fields present with correct keyboard types
- ✓ Password fields are secure

---

### Task 19: Implement Sign Up Validation
- [ ] Add @State for all form fields
- [ ] Add @State for validation errors
- [ ] Validate display name (not empty)
- [ ] Validate nickname (alphanumeric, unique format)
- [ ] Validate email format
- [ ] Validate password strength (min 8 chars)
- [ ] Validate passwords match
- [ ] Show inline error messages

**Acceptance Criteria:**
- ✓ Validation runs on field blur or submit
- ✓ Clear error messages shown
- ✓ Submit disabled until valid

**Dependencies:** Task 18

---

### Task 20: Implement Sign Up Logic
- [ ] Add @EnvironmentObject for AuthService
- [ ] Add @State for isLoading
- [ ] Implement create account action
- [ ] Call AuthService.signUp with form data
- [ ] Handle errors (duplicate nickname, network issues)
- [ ] Navigate to Profile Setup on success
- [ ] Show loading state

**Acceptance Criteria:**
- ✓ Creates account with valid data
- ✓ Handles duplicate nickname error
- ✓ Shows loading indicator
- ✓ Navigates to profile setup

**Dependencies:** Task 8, Task 19

---

### Task 20.1: Implement Google OAuth Sign In/Sign Up

-   [ ] Add Google OAuth configuration to Supabase dashboard (get Client ID)
-   [ ] Update AuthService.signInWithGoogle() method stub
-   [ ] Implement OAuth flow using supabase.auth.signInWithOAuth(provider: .google)
-   [ ] Handle OAuth redirect/callback
-   [ ] Check if user profile exists in profiles table
-   [ ] If new user: navigate to Profile Setup
-   [ ] If existing user: navigate to GamesTab
-   [ ] Add error handling for OAuth failures
-   [ ] Test on actual device (OAuth doesn't work well in simulator)

**Acceptance Criteria:**

-   ✓ Google OAuth flow completes successfully
-   ✓ New users create profile automatically
-   ✓ Existing users sign in directly
-   ✓ Error handling for cancelled/failed OAuth
-   ✓ Works on physical device
-   ✓ Session persists in Keychain

---


### Task 21: Create Profile Setup Screen
- [ ] Create file: Views/Auth/ProfileSetupView.swift
- [ ] Add "Complete Your Profile" header
- [ ] Add avatar picker (placeholder for now)
- [ ] Add display name and nickname (pre-filled, editable)
- [ ] Add "Done" button
- [ ] Style per design spec

**Acceptance Criteria:**
- ✓ Layout matches design
- ✓ Shows user's current data
- ✓ Avatar picker UI present (functionality comes later)

---

### Task 22: Implement Profile Setup Logic
- [ ] Add @State for avatar selection
- [ ] Wire up "Done" button to save profile
- [ ] Call update profile API (placeholder for now)
- [ ] Navigate to GamesTab on completion
- [ ] Add dismiss action

**Acceptance Criteria:**
- ✓ Can skip avatar (use default)
- ✓ Navigates to app after completion
- ✓ No crashes on save

**Dependencies:** Task 21

---



Next: Continue with DanDarts task-list-2