---
trigger: manual
---

Phase 9: Gameplay Screen - Scoring (301 Only)
---------------------------------------------

### Task 41: Create Gameplay View Structure

-   [ ] Create file: Views/Games/GameplayView.swift
-   [ ] Add full-screen layout (hide top bar/tabs)
-   [ ] Add player info section (top)
-   [ ] Add scoring button grid (center)
-   [ ] Add "Save Score" button (bottom)
-   [ ] Add "Exit Game" button (top left corner)
-   [ ] Style with dark background

**Acceptance Criteria:**

-   ✓ Full screen layout works
-   ✓ Structure matches design
-   ✓ All sections positioned correctly

* * * * *

### Task 42: Create Scoring Button Component

-   [ ] Create file: Views/Components/ScoringButton.swift
-   [ ] Create circular button (64pt diameter)
-   [ ] Add number label (SF Pro Display Medium 24pt)
-   [ ] Style with dark gray background
-   [ ] Add tap animation (scale 0.92)
-   [ ] Add active state (accent color fill)
-   [ ] Add haptic feedback on tap

**Acceptance Criteria:**

-   ✓ Button matches Calculator style
-   ✓ Tap animation smooth
-   ✓ Haptic feedback works
-   ✓ Active state visible

* * * * *

### Task 43: Create Scoring Button Grid

-   [ ] Add LazyVGrid to GameplayView
-   [ ] Create buttons for 1-20 in dartboard order: 20,1,18,4,13,6,10,15,2,17,3,19,7,16,8,11,14,9,12,5
-   [ ] Add "Bull" button (25 and 50)
-   [ ] Add "Miss" button
-   [ ] Arrange in 5 columns
-   [ ] Add spacing between buttons

**Acceptance Criteria:**

-   ✓ All 20 numbers plus Bull and Miss present
-   ✓ Dartboard order correct
-   ✓ Grid layout clean and tappable
-   ✓ Looks good on all iPhone sizes

**Dependencies:** Task 42

* * * * *

### Task 44: Implement Basic Score Input (Single Hits)

-   [ ] Add @State currentScore: Int
-   [ ] Add @State currentThrow: [Int] (max 3 darts)
-   [ ] Implement button tap actions
-   [ ] Update currentThrow array on tap
-   [ ] Display current throw scores
-   [ ] Limit to 3 darts per turn
-   [ ] Highlight active button briefly

**Acceptance Criteria:**

-   ✓ Tapping numbers adds to current throw
-   ✓ Max 3 darts enforced
-   ✓ Current throw visible to user
-   ✓ Scoring logic correct

**Dependencies:** Task 43

* * * * *

### Task 45: Implement Long-Press for Doubles/Triples

-   [ ] Add long-press gesture to scoring buttons
-   [ ] Show contextual menu with "Single", "Double", "Triple" options
-   [ ] Update throw calculation based on selection
-   [ ] Add visual indication (D or T prefix on display)
-   [ ] Test double and triple scoring

**Acceptance Criteria:**

-   ✓ Long-press shows menu
-   ✓ Double multiplies by 2
-   ✓ Triple multiplies by 3
-   ✓ Display shows D20 or T20 format

**Dependencies:** Task 44

* * * * *

### Task 46: Create Game State Manager (301 Logic)

-   [ ] Create file: ViewModels/GameViewModel.swift
-   [ ] Make ObservableObject
-   [ ] Add @Published players: [Player]
-   [ ] Add @Published currentPlayerIndex: Int
-   [ ] Add @Published playerScores: [UUID: Int] (starting at 301)
-   [ ] Add method: recordThrow(value: Int, multiplier: Int)
-   [ ] Add method: saveScore() - deduct from player total
-   [ ] Add method: switchPlayer()
-   [ ] Add @Published winner: Player?

**Acceptance Criteria:**

-   ✓ Can track 2+ players
-   ✓ Scores deduct correctly from 301
-   ✓ Current player switches after save
-   ✓ Winner detected when score reaches 0

* * * * *

### Task 47: Integrate Game State with Gameplay View

-   [ ] Add @StateObject gameViewModel in GameplayView
-   [ ] Initialize with game type and players
-   [ ] Bind scoring buttons to gameViewModel.recordThrow
-   [ ] Display player scores from gameViewModel
-   [ ] Highlight current player
-   [ ] Wire "Save Score" to gameViewModel.saveScore()
-   [ ] Show turn summary after save

**Acceptance Criteria:**

-   ✓ Scoring updates game state
-   ✓ Player scores display correctly
-   ✓ Current player highlighted
-   ✓ Score deducts properly from 301

**Dependencies:** Task 44, Task 46

* * * * *

### Task 48: Implement Undo Last Turn

-   [ ] Add @Published lastTurn in GameViewModel
-   [ ] Store last turn data before switching players
-   [ ] Add "Undo" button (appears for 5 seconds after save)
-   [ ] Implement undo logic (restore previous state)
-   [ ] Test undo functionality

**Acceptance Criteria:**

-   ✓ Undo button appears after save
-   ✓ Undo restores previous score and player
-   ✓ Undo disappears after 5 seconds
-   ✓ Can't undo more than once

**Dependencies:** Task 47

* * * * *

### Task 49: Implement Exit Game Confirmation

-   [ ] Add @State showExitAlert in GameplayView
-   [ ] Add "Exit" button action to show alert
-   [ ] Create alert with "Leave Game" and "Cancel" options
-   [ ] Navigate back to Games tab on confirm
-   [ ] Test exit flow

**Acceptance Criteria:**

-   ✓ Alert appears on exit tap
-   ✓ Cancel keeps user in game
-   ✓ Confirm exits to Games tab
-   ✓ No crashes

**Dependencies:** Task 41

* * * * *

Phase 10: Game End Screen
-------------------------

### Task 50: Create Game End View

-   [ ] Create file: Views/Games/GameEndView.swift
-   [ ] Add winner avatar (large, 120pt)
-   [ ] Add winner name (bold, large)
-   [ ] Add celebration animation placeholder
-   [ ] Add "Play Again" button
-   [ ] Add "New Game" button
-   [ ] Add "Change Players" button
-   [ ] Style per design spec

**Acceptance Criteria:**

-   ✓ Layout matches design
-   ✓ Winner info prominent
-   ✓ All buttons present and styled
-   ✓ Looks celebratory

* * * * *

### Task 51: Implement Confetti Animation

-   [ ] Create simple confetti particle system
-   [ ] Use Canvas or SpriteKit for particles
-   [ ] Trigger on view appear
-   [ ] Duration: 2 seconds
-   [ ] Colors: Accent primary and secondary
-   [ ] Make subtle and tasteful

**Acceptance Criteria:**

-   ✓ Confetti appears on screen
-   ✓ Animation smooth
-   ✓ Not overwhelming
-   ✓ Performs well

**Dependencies:** Task 50

* * * * *

### Task 52: Implement Game End Navigation

-   [ ] Detect winner in GameViewModel
-   [ ] Navigate to GameEndView when winner exists
-   [ ] Pass winner and game data
-   [ ] Implement "Play Again" (same players, reset scores)
-   [ ] Implement "New Game" (back to game detail)
-   [ ] Implement "Change Players" (back to game detail, clear players)

**Acceptance Criteria:**

-   ✓ Automatically shows end screen when game completes
-   ✓ "Play Again" resets and starts new game
-   ✓ "New Game" navigates to detail with same game
-   ✓ "Change Players" clears selection

**Dependencies:** Task 47, Task 50

* * * * *

### Task 53: Save Match to Local Storage

-   [ ] Create MatchResult model
-   [ ] Add method to save match to JSON file
-   [ ] Include: game type, players, winner, scores, timestamp
-   [ ] Call save method on game end
-   [ ] Update player win/loss stats locally

**Acceptance Criteria:**

-   ✓ Match saves to local JSON file
-   ✓ Data includes all relevant info
-   ✓ Player stats update correctly
-   ✓ Can read saved matches

**Dependencies:** Task 52

* * * * *

Phase 11: Friends Tab
---------------------

### Task 54: Create Friends List View

-   [ ] Create file: Views/Friends/FriendsListView.swift
-   [ ] Add search bar at top
-   [ ] Add "Add Friend" button
-   [ ] Add List of friend PlayerCards
-   [ ] Add empty state ("No friends yet")
-   [ ] Style per design spec

**Acceptance Criteria:**

-   ✓ Layout matches design
-   ✓ Search bar and button present
-   ✓ Empty state shows when no friends
-   ✓ List scrollable

* * * * *

### Task 55: Create Friend Search View

-   [ ] Create file: Views/Friends/FriendSearchView.swift
-   [ ] Add search TextField
-   [ ] Add search results list (PlayerCards)
-   [ ] Add "Add Friend" button on each result
-   [ ] Add loading state
-   [ ] Add empty results state
-   [ ] Style as sheet

**Acceptance Criteria:**

-   ✓ Search input works
-   ✓ Results display correctly
-   ✓ Add button visible
-   ✓ Sheet dismisses after add

* * * * *

### Task 56: Implement Friend Search Logic (Mock Data)

-   [ ] Add @State searchQuery
-   [ ] Add @State searchResults: [Player]
-   [ ] Implement debounced search (300ms)
-   [ ] Filter mock player data by query
-   [ ] Display results
-   [ ] Test search functionality

**Acceptance Criteria:**

-   ✓ Search filters as user types
-   ✓ Debounce prevents excessive filtering
-   ✓ Results update smoothly
-   ✓ Can find players by name or nickname

**Dependencies:** Task 55

* * * * *

### Task 57: Implement Add Friend Action (Local)

-   [ ] Add @State friends: [Player] in FriendsListView
-   [ ] Implement addFriend(player: Player) method
-   [ ] Save to local JSON file
-   [ ] Update friends list
-   [ ] Show success feedback
-   [ ] Prevent duplicate adds

**Acceptance Criteria:**

-   ✓ Friend added to list
-   ✓ Persists to local storage
-   ✓ No duplicates allowed
-   ✓ Success message shown

**Dependencies:** Task 56

* * * * *

### Task 58: Implement Remove Friend

-   [ ] Add swipe-to-delete on friend cards
-   [ ] Show confirmation alert
-   [ ] Remove from friends list
-   [ ] Update local storage
-   [ ] Test remove flow

**Acceptance Criteria:**

-   ✓ Swipe reveals delete option
-   ✓ Confirmation prevents accidents
-   ✓ Friend removed from list and storage
-   ✓ UI updates immediately

**Dependencies:** Task 54

* * * * *

### Task 59: Create Friend Profile View

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

* * * * *

### Task 60: Integrate Friends Tab Navigation

-   [ ] Add NavigationStack to FriendsListView
-   [ ] Add NavigationLink on friend card tap
-   [ ] Navigate to FriendProfileView
-   [ ] Pass friend data
-   [ ] Test navigation flow

**Acceptance Criteria:**

-   ✓ Tapping friend navigates to profile
-   ✓ Back button works
-   ✓ Correct data displayed

**Dependencies:** Task 54, Task 59

* * * * *

Phase 12: History Tab