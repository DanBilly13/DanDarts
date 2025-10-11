---
trigger: manual
---

Phase 15: Supabase Integration
------------------------------

### Task 79: Set Up Supabase Project

-   [ ] Create Supabase account
-   [ ] Create new project
-   [ ] Copy project URL
-   [ ] Copy anon key
-   [ ] Add to Xcode environment variables or Config file
-   [ ] Update SupabaseService with real credentials

**Acceptance Criteria:**

-   ✓ Supabase project created
-   ✓ Credentials stored securely
-   ✓ SupabaseClient connects successfully
-   ✓ No credentials in source control

**Dependencies:** Task 5

* * * * *

### Task 80: Create Database Tables

-   [ ] Open Supabase SQL Editor
-   [ ] Create `profiles` table with schema from SRS
-   [ ] Create `friendships` table
-   [ ] Create `matches` table
-   [ ] Set up foreign keys
-   [ ] Create indexes
-   [ ] Test tables with sample data

**Acceptance Criteria:**

-   ✓ All tables created
-   ✓ Foreign keys working
-   ✓ Indexes created
-   ✓ Can insert/query test data

**Dependencies:** Task 79

* * * * *

### Task 81: Set Up Row Level Security (RLS)

-   [ ] Enable RLS on all tables
-   [ ] Create policy: users can read all profiles
-   [ ] Create policy: users can update own profile
-   [ ] Create policy: users can read own friendships
-   [ ] Create policy: users can insert/delete own friendships
-   [ ] Create policy: users can read/insert own matches
-   [ ] Test policies with different users

**Acceptance Criteria:**

-   ✓ RLS enabled on all tables
-   ✓ Policies prevent unauthorized access
-   ✓ Authorized operations work
-   ✓ Security verified

**Dependencies:** Task 80

* * * * *

### Task 82: Implement Real Sign Up with Supabase

-   [ ] Update AuthService.signUp to use real Supabase
-   [ ] Call supabase.auth.signUp(email:password:)
-   [ ] Insert profile record in profiles table
-   [ ] Handle errors (duplicate email, network)
-   [ ] Test with real email

**Acceptance Criteria:**

-   ✓ Creates user in Supabase auth
-   ✓ Creates profile record
-   ✓ Error handling works
-   ✓ Can sign in with created account

**Dependencies:** Task 8, Task 81

* * * * *

### Task 83: Implement Real Sign In with Supabase

-   [ ] Update AuthService.signIn to use real Supabase
-   [ ] Call supabase.auth.signIn(email:password:)
-   [ ] Fetch profile from profiles table
-   [ ] Store session in Keychain
-   [ ] Handle errors
-   [ ] Test sign in flow

**Acceptance Criteria:**

-   ✓ Signs in with valid credentials
-   ✓ Fetches profile data
-   ✓ Session persists in Keychain
-   ✓ Error handling works

**Dependencies:** Task 9, Task 82

* * * * *

### Task 84: Implement Google OAuth

-   [ ] Configure Google OAuth in Supabase dashboard
-   [ ] Add Google OAuth redirect URL
-   [ ] Update AuthService with OAuth flow
-   [ ] Test Google sign in on device
-   [ ] Handle first-time vs returning users

**Acceptance Criteria:**

-   ✓ Google OAuth flow completes
-   ✓ Creates profile for new users
-   ✓ Fetches profile for existing users
-   ✓ Works on actual device

**Dependencies:** Task 82

* * * * *

### Task 85: Implement Friend Search with Supabase

-   [ ] Update friend search to query profiles table
-   [ ] Search by display_name or nickname
-   [ ] Use Supabase ilike query
-   [ ] Handle pagination (20 results)
-   [ ] Display results
-   [ ] Test search

**Acceptance Criteria:**

-   ✓ Searches Supabase profiles
-   ✓ Returns relevant results
-   ✓ Pagination works
-   ✓ Search is fast

**Dependencies:** Task 56, Task 81

* * * * *

### Task 86: Implement Add Friend with Supabase

-   [ ] Update addFriend to insert into friendships table
-   [ ] Handle errors (already friends, network)
-   [ ] Sync local friends list
-   [ ] Show success feedback
-   [ ] Test add friend flow

**Acceptance Criteria:**

-   ✓ Creates friendship record
-   ✓ Prevents duplicate friendships
-   ✓ Syncs to local state
-   ✓ Error handling works

**Dependencies:** Task 57, Task 85

* * * * *

### Task 87: Implement Load Friends from Supabase

-   [ ] Query friendships table on FriendsListView appear
-   [ ] Join with profiles to get friend data
-   [ ] Update local friends list
-   [ ] Handle empty state
-   [ ] Add loading indicator

**Acceptance Criteria:**

-   ✓ Loads friends from Supabase
-   ✓ Displays friend data correctly
-   ✓ Loading state shown
-   ✓ Empty state handled

**Dependencies:** Task 54, Task 86

* * * * *

### Task 88: Implement Match Sync to Supabase

-   [ ] Update match save to also insert into matches table
-   [ ] Include all match data
-   [ ] Handle sync failures (queue for retry)
-   [ ] Update synced_at timestamp
-   [ ] Test match sync

**Acceptance Criteria:**

-   ✓ Matches save to Supabase
-   ✓ Local and cloud data consistent
-   ✓ Failed syncs retry later
-   ✓ No duplicate matches

**Dependencies:** Task 53, Task 81

* * * * *

### Task 89: Implement Match History from Supabase

-   [ ] Query matches table on HistoryView appear
-   [ ] Filter by current user (player1 or player2)
-   [ ] Merge with local-only matches
-   [ ] Sort by date
-   [ ] Display in list

**Acceptance Criteria:**

-   ✓ Loads matches from Supabase
-   ✓ Shows both synced and local matches
-   ✓ No duplicates
-   ✓ Sorted correctly

**Dependencies:** Task 63, Task 88

* * * * *

### Task 90: Implement Pull-to-Refresh Sync

-   [ ] Add .refreshable modifier to HistoryView
-   [ ] Fetch latest matches from Supabase
-   [ ] Update local cache
-   [ ] Show sync status
-   [ ] Handle errors

**Acceptance Criteria:**

-   ✓ Pull-to-refresh triggers sync
-   ✓ Latest data loads
-   ✓ UI updates after sync
-   ✓ Error handling works

**Dependencies:** Task 89

* * * * *

Phase 16: Testing & Bug Fixes
-----------------------------

### Task 91: Test Complete User Flow (New User)

-   [ ] Test: Launch app → Sign up → Profile setup → Browse games → Start game → Play → View history
-   [ ] Document any bugs or issues
-   [ ] Fix critical bugs
-   [ ] Retest flow

**Acceptance Criteria:**

-   ✓ Flow works end-to-end
-   ✓ No crashes
-   ✓ Data persists correctly
-   ✓ UX smooth

**Dependencies:** All previous tasks

* * * * *

### Task 92: Test Complete User Flow (Returning User)

-   [ ] Test: Launch app → Auto sign in → View friends → Search friend → Add friend → Start game → Play
-   [ ] Test session persistence
-   [ ] Test offline mode
-   [ ] Fix any bugs

**Acceptance Criteria:**

-   ✓ Session restores correctly
-   ✓ Friends list syncs
-   ✓ Offline play works
-   ✓ No issues found

**Dependencies:** All previous tasks

* * * * *

### Task 93: Test Guest Mode

-   [ ] Test: Continue as guest → Add local players → Play game → View history
-   [ ] Verify no cloud sync
-   [ ] Test guest limitations
-   [ ] Ensure stable

**Acceptance Criteria:**

-   ✓ Guest mode works completely offline
-   ✓ Local players save correctly
-   ✓ No sync errors
-   ✓ Can upgrade to account later (future)

**Dependencies:** All previous tasks

* * * * *

### Task 94: Test Edge Cases

-   [ ] Test: Very long usernames/nicknames
-   [ ] Test: No internet during sign up
-   [ ] Test: App backgrounding during game
-   [ ] Test: Rapid button tapping
-   [ ] Test: Memory warnings
-   [ ] Fix any crashes or bugs

**Acceptance Criteria:**

-   ✓ Handles long text gracefully
-   ✓ Network errors handled
-   ✓ State preserved on background
-   ✓ No crashes from rapid input
-   ✓ Performs well under pressure

* * * * *

### Task 95: Test on Multiple Devices

-   [ ] Test on iPhone SE (small screen)
-   [ ] Test on iPhone 15 Pro Max (large screen)
-   [ ] Test on older iOS 17 device
-   [ ] Fix layout issues
-   [ ] Verify performance

**Acceptance Criteria:**

-   ✓ Layouts adapt correctly
-   ✓ No content cut off
-   ✓ Performance acceptable on all devices
-   ✓ Consistent experience

* * * * *

### Task 96: Accessibility Testing

-   [ ] Enable VoiceOver and test navigation
-   [ ] Test Dynamic Type (large text)
-   [ ] Enable Reduce Motion and test animations
-   [ ] Fix accessibility issues
-   [ ] Document remaining issues

**Acceptance Criteria:**

-   ✓ VoiceOver can navigate app
-   ✓ Text scales appropriately
-   ✓ Animations respect Reduce Motion
-   ✓ Critical features accessible

* * * * *

Phase 17: Polish & Launch Prep
------------------------------

### Task 97: Create App Icon

-   [ ] Design app icon (dartboard or target theme)
-   [ ] Create all required sizes
-   [ ] Add to Assets.xcassets
-   [ ] Test icon on home screen

**Acceptance Criteria:**

-   ✓ Icon looks professional
-   ✓ All sizes provided
-   ✓ Shows correctly on device
-   ✓ Matches app aesthetic

* * * * *

### Task 98: Create Launch Screen

-   [ ] Design launch screen (match splash screen)
-   [ ] Add to LaunchScreen.storyboard or use Info.plist
-   [ ] Test launch screen appearance
-   [ ] Ensure quick transition to splash

**Acceptance Criteria:**

-   ✓ Launch screen appears immediately
-   ✓ Matches app design
-   ✓ Smooth transition to app
-   ✓ No white flash

* * * * *

### Task 99: Configure App Metadata

-   [ ] Set display name: "DanDarts"
-   [ ] Set bundle version and build number
-   [ ] Add app description
-   [ ] Configure supported orientations (portrait only)
-   [ ] Set status bar style (light content)

**Acceptance Criteria:**

-   ✓ App name correct
-   ✓ Version numbers set
-   ✓ Orientation locked to portrait
-   ✓ Status bar readable

* * * * *

### Task 100: Privacy & Permissions

-   [ ] Add camera usage description (for avatar)
-   [ ] Add photo library usage description
-   [ ] Review data collection practices
-   [ ] Create privacy policy (basic)
-   [ ] Ensure GDPR compliance basics

**Acceptance Criteria:**

-   ✓ Permission prompts have clear descriptions
-   ✓ Privacy policy accessible
-   ✓ Compliant with App Store requirements
-   ✓ User data handled appropriately

* * * * *

### Task 101: Final Testing Round

-   [ ] Complete regression testing
-   [ ] Test all features once more
-   [ ] Check for console warnings/errors
-   [ ] Verify no crashes
-   [ ] Test on physical device

**Acceptance Criteria:**

-   ✓ All features work
-   ✓ No crashes during 30min+ session
-   ✓ Performance smooth
-   ✓ Ready for TestFlight

* * * * *

### Task 102: Prepare for TestFlight

-   [ ] Archive app in Xcode
-   [ ] Upload to App Store Connect
-   [ ] Add beta testing information
-   [ ] Invite beta testers
-   [ ] Create feedback collection process

**Acceptance Criteria:**

-   ✓ App successfully uploaded
-   ✓ TestFlight build available
-   ✓ Beta testers invited
-   ✓ Feedback mechanism ready

* * * * *

---

Next: Continue with DanDarts task-list-6