---
trigger: manual
---

**Task 59: Create Friend Profile View**

-   [ ] Create file: Views/Friends/FriendProfileView.swift
-   [ ] Add large avatar (120pt)
-   [ ] Add display name and nickname
-   [ ] Add total W/L stats
-   [ ] Add head-to-head stats section (placeholder)
-   [ ] Add match history section (placeholder)
-   [ ] Add "Remove Friend" button
-   [ ] Style per design spec

**Acceptance Criteria:**

-   ✓ Profile shows all user info
-   ✓ Layout clean and readable
-   ✓ Remove button present
-   ✓ Navigates from friend list tap

**Task 60: Integrate Friends Tab Navigation**

-   [ ] Add NavigationStack to FriendsListView
-   [ ] Add NavigationLink on friend card tap
-   [ ] Navigate to FriendProfileView
-   [ ] Pass friend data
-   [ ] Test navigation flow

**Acceptance Criteria:**

-   ✓ Tapping friend navigates to profile
-   ✓ Back button works
-   ✓ Correct data displayed

**Dependencies:** Task 54, Task 59



Phase 12: History Tab
---------------------

### Task 61: Create Match History View

-   [ ] Create file: Views/History/MatchHistoryView.swift
-   [ ] Add pull-to-refresh (placeholder for future sync)
-   [ ] Add filter buttons (All, 301, 501, etc.)
-   [ ] Add List of match cards
-   [ ] Add empty state ("No matches yet")
-   [ ] Style per design spec

**Acceptance Criteria:**

-   ✓ Layout matches design
-   ✓ Filter buttons present
-   ✓ Empty state shows when no matches
-   ✓ List scrollable

* * * * *

### Task 62: Create Match Card Component

-   [ ] Create file: Views/Components/MatchCard.swift
-   [ ] Add game type badge (top left)
-   [ ] Add player names
-   [ ] Add winner indicator
-   [ ] Add final scores
-   [ ] Add date (relative: "2 days ago")
-   [ ] Set height ~100pt
-   [ ] Add border and background
-   [ ] Style per design spec

**Acceptance Criteria:**

-   ✓ Card shows all match info clearly
-   ✓ Winner highlighted
-   ✓ Date formatted nicely
-   ✓ Looks good with different data

* * * * *

### Task 63: Load Match History from Local Storage

-   [ ] Add @State matches: [MatchResult]
-   [ ] Load matches from JSON file on appear
-   [ ] Sort by date (most recent first)
-   [ ] Display using MatchCard
-   [ ] Test with saved matches

**Acceptance Criteria:**

-   ✓ Loads all saved matches
-   ✓ Sorted correctly
-   ✓ Displays in list
-   ✓ Performance good with many matches

**Dependencies:** Task 53, Task 61, Task 62

* * * * *

### Task 64: Implement Match History Filtering

-   [ ] Add @State selectedFilter: GameType?
-   [ ] Filter matches based on selectedFilter
-   [ ] Update filter button states
-   [ ] Test all filters
-   [ ] "All" shows everything

**Acceptance Criteria:**

-   ✓ Filtering works correctly
-   ✓ Filter buttons highlight active state
-   ✓ List updates smoothly
-   ✓ Can reset to "All"

**Dependencies:** Task 63

* * * * *

### Task 65: Create Match Detail View

-   [ ] Create file: Views/History/MatchDetailView.swift
-   [ ] Add game type header
-   [ ] Add player names and avatars
-   [ ] Add final scores (large)
-   [ ] Add date and time
-   [ ] Add turn-by-turn breakdown (if available)
-   [ ] Style per design spec

**Acceptance Criteria:**

-   ✓ Shows complete match info
-   ✓ Layout clean and readable
-   ✓ Turn data displayed if available
-   ✓ Navigates from match card tap

* * * * *

### Task 66: Integrate Match Detail Navigation

-   [ ] Add NavigationLink on match card tap
-   [ ] Navigate to MatchDetailView
-   [ ] Pass match data
-   [ ] Test navigation

**Acceptance Criteria:**

-   ✓ Tapping match card shows detail
-   ✓ Correct data displayed
-   ✓ Back navigation works

**Dependencies:** Task 63, Task 65

* * * * *

Phase 13: Profile & Settings
----------------------------

### Task 67: Create Profile View

-   [ ] Create file: Views/Profile/ProfileView.swift
-   [ ] Add user avatar (large, 120pt, tappable)
-   [ ] Add display name and nickname
-   [ ] Add total W/L stats
-   [ ] Add Settings section with grouped list
-   [ ] Add "Log Out" button (bottom)
-   [ ] Style per design spec

**Acceptance Criteria:**

-   ✓ Layout matches design
-   ✓ User info displayed from AuthService
-   ✓ Settings section present
-   ✓ Logout button visible

* * * * *

### Task 68: Implement Profile Navigation

-   [ ] Add @State showProfile in MainTabView
-   [ ] Wire top bar avatar tap to show ProfileView
-   [ ] Present as sheet
-   [ ] Test from all tabs
-   [ ] Add dismiss action

**Acceptance Criteria:**

-   ✓ Avatar tap shows profile sheet
-   ✓ Works from all tabs
-   ✓ Sheet dismisses correctly
-   ✓ No navigation bugs

**Dependencies:** Task 25, Task 67

* * * * *

### Task 69: Implement Settings Toggles

-   [ ] Add sound effects toggle in ProfileView
-   [ ] Store preference in UserDefaults
-   [ ] Load preference on app launch
-   [ ] Update SoundManager to respect setting
-   [ ] Test toggle functionality

**Acceptance Criteria:**

-   ✓ Toggle saves to UserDefaults
-   ✓ Setting persists across launches
-   ✓ Sounds muted when off
-   ✓ Toggle state reflects actual setting

**Dependencies:** Task 67

* * * * *

### Task 70: Implement Avatar Change (Basic)

-   [ ] Add @State showImagePicker
-   [ ] Add tap gesture on avatar
-   [ ] Present PhotosPicker (iOS 17)
-   [ ] Allow user to select new photo
-   [ ] Update avatar in memory (don't sync yet)
-   [ ] Show updated avatar immediately

**Acceptance Criteria:**

-   ✓ Tapping avatar opens picker
-   ✓ Can select photo from library
-   ✓ Avatar updates in UI
-   ✓ No crashes

**Dependencies:** Task 67

* * * * *

### Task 71: Implement Logout

-   [ ] Wire logout button to AuthService.signOut()
-   [ ] Add confirmation alert
-   [ ] Clear local app state
-   [ ] Navigate to WelcomeView
-   [ ] Test logout flow

**Acceptance Criteria:**

-   ✓ Confirmation prevents accidents
-   ✓ Successfully logs out
-   ✓ Returns to welcome screen
-   ✓ Can log back in

**Dependencies:** Task 11, Task 67

* * * * *

### Task 72: Add About Section

-   [ ] Add "About" section in ProfileView
-   [ ] Add app version number
-   [ ] Add "Privacy Policy" link (placeholder URL)
-   [ ] Add "Terms of Service" link (placeholder URL)
-   [ ] Open links in Safari

**Acceptance Criteria:**

-   ✓ Version number correct
-   ✓ Links present
-   ✓ Links open in Safari
-   ✓ Returns to app after viewing

**Dependencies:** Task 67

* * * * *

Phase 14: Sound Effects & Polish
--------------------------------

### Task 73: Create Sound Manager Service

-   [ ] Create file: Services/SoundManager.swift
-   [ ] Make singleton with shared instance
-   [ ] Add AVAudioPlayer properties
-   [ ] Add method: playThrowSound()
-   [ ] Add method: play180Sound()
-   [ ] Add method: playBellSound()
-   [ ] Respect sound settings from UserDefaults

**Acceptance Criteria:**

-   ✓ SoundManager compiles
-   ✓ Can play multiple sounds
-   ✓ Respects mute setting
-   ✓ No audio conflicts

**Dependencies:** Task 38

* * * * *

### Task 74: Add Sound Files

-   [ ] Add throw.mp3 to Resources (basic tap sound)
-   [ ] Add 180.mp3 to Resources (voice callout "One Eighty!")
-   [ ] Add bell.mp3 (if not done in Task 38)
-   [ ] Test sound file quality
-   [ ] Ensure files are included in build

**Acceptance Criteria:**

-   ✓ All sound files present
-   ✓ Files play without errors
-   ✓ Audio quality acceptable
-   ✓ File sizes reasonable

* * * * *

### Task 75: Integrate Throw Sound

-   [ ] Call SoundManager.playThrowSound() on score button tap
-   [ ] Test with sound on/off
-   [ ] Ensure no lag or delay
-   [ ] Test rapid tapping

**Acceptance Criteria:**

-   ✓ Sound plays on every tap
-   ✓ No audio lag
-   ✓ Works with rapid inputs
-   ✓ Respects mute setting

**Dependencies:** Task 44, Task 73, Task 74

* * * * *

### Task 76: Implement 180 Detection & Callout

-   [ ] Detect when current throw totals 180
-   [ ] Call SoundManager.play180Sound()
-   [ ] Show visual celebration (brief scale animation)
-   [ ] Test 180 detection

**Acceptance Criteria:**

-   ✓ Correctly detects 180 (T20, T20, T20)
-   ✓ Voice callout plays
-   ✓ Visual feedback shown
-   ✓ Only triggers once per 180

**Dependencies:** Task 47, Task 73, Task 74

* * * * *

### Task 77: Polish Animations & Transitions

-   [ ] Review all screen transitions
-   [ ] Ensure smooth navigation animations
-   [ ] Add subtle spring animations to buttons
-   [ ] Polish card hover/press states
-   [ ] Test on actual device

**Acceptance Criteria:**

-   ✓ All animations smooth (60 fps)
-   ✓ No jarring transitions
-   ✓ Feels polished and professional
-   ✓ Performs well on device

* * * * *

### Task 78: Test Dark Mode Support

-   [ ] Test all screens in dark mode
-   [ ] Verify color contrast ratios
-   [ ] Check readability of all text
-   [ ] Ensure images/icons work in dark mode
-   [ ] Fix any issues

**Acceptance Criteria:**

-   ✓ All screens look good in dark mode
-   ✓ No contrast issues
-   ✓ Consistent dark aesthetic
-   ✓ Matches design spec

* * * * *

---

Next: Continue with DanDarts task-list-5