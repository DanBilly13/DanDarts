---
trigger: manual
---

## Phase 5: Main Navigation Structure

### Task 23: Create Tab Bar Navigation
- [ ] Create file: Views/MainTabView.swift
- [ ] Add TabView with 3 tabs
- [ ] Add GamesTab with SF Symbol "target"
- [ ] Add FriendsTab with SF Symbol "person.2.fill"
- [ ] Add HistoryTab with SF Symbol "chart.bar.fill"
- [ ] Style tab bar for dark mode
- [ ] Set accent color

**Acceptance Criteria:**
- ✓ 3 tabs visible and labeled
- ✓ Icons show correctly
- ✓ Selected state shows accent color
- ✓ Can switch between tabs

---

### Task 24: Create Top Bar Component
- [ ] Create file: Views/Components/TopBar.swift
- [ ] Add "DanDarts" title text (left)
- [ ] Add avatar button (right, 32pt circle)
- [ ] Add placeholder avatar image
- [ ] Style with dark background
- [ ] Make height 44pt

**Acceptance Criteria:**
- ✓ Top bar matches design spec
- ✓ Logo and avatar positioned correctly
- ✓ Avatar tappable (no action yet)

---

### Task 25: Integrate Top Bar in Main Tabs
- [ ] Add TopBar to GamesTab
- [ ] Add TopBar to FriendsTab
- [ ] Add TopBar to HistoryTab
- [ ] Ensure consistent appearance
- [ ] Test safe area insets

**Acceptance Criteria:**
- ✓ Top bar appears on all main tabs
- ✓ Consistent styling across tabs
- ✓ No overlap with status bar

**Dependencies:** Task 23, Task 24

---

Phase 6: Games Tab - Game List
------------------------------

### Task 26: Create Game Model

-   [ ] Create file: Models/Game.swift
-   [ ] Define Game struct: id, name, tagline, type (enum), instructions
-   [ ] Make Identifiable
-   [ ] Add GameType enum: game301, game501, halveIt, knockout, suddenDeath, cricket, killer
-   [ ] Add mock data for all 7 games

**Acceptance Criteria:**

-   ✓ Game model compiles
-   ✓ All 7 game types defined
-   ✓ Mock data includes all games with instructions

* * * * *

### Task 27: Create Game Card Component

-   [ ] Create file: Views/Components/GameCard.swift
-   [ ] Add game name (SF Pro Display Bold 28pt)
-   [ ] Add tagline (SF Pro Text 16pt, 70% opacity)
-   [ ] Add "Play" button (pill shaped, accent color)
-   [ ] Set size: 90% width, 200pt height
-   [ ] Add dark background with gradient
-   [ ] Add rounded corners (16pt) and shadow

**Acceptance Criteria:**

-   ✓ Card matches design spec
-   ✓ Gradient background visible
-   ✓ "Play" button styled correctly
-   ✓ Looks good in preview

* * * * *

### Task 28: Create Games List View

-   [ ] Create file: Views/Games/GamesListView.swift
-   [ ] Add ScrollView with horizontal paging
-   [ ] Use ForEach with mock game data
-   [ ] Display GameCard for each game
-   [ ] Add snap-to-center behavior
-   [ ] Test scrolling with 7 games

**Acceptance Criteria:**

-   ✓ Horizontal scrolling works
-   ✓ Cards snap to center
-   ✓ All 7 games visible
-   ✓ Smooth scrolling performance

**Dependencies:** Task 26, Task 27

* * * * *

### Task 29: Integrate Games List into GamesTab

-   [ ] Replace placeholder in GamesTab with GamesListView
-   [ ] Add TopBar above list
-   [ ] Test navigation and layout
-   [ ] Ensure proper spacing

**Acceptance Criteria:**

-   ✓ Games list appears in Games tab
-   ✓ Top bar visible
-   ✓ Layout correct on different screen sizes

**Dependencies:** Task 25, Task 28

* * * * *

Phase 7: Game Details & Player Selection
----------------------------------------

### Task 30: Create Game Detail View

-   [ ] Create file: Views/Games/GameDetailView.swift
-   [ ] Add game title (large)
-   [ ] Add game description
-   [ ] Add rules section (scrollable)
-   [ ] Add "Back" button
-   [ ] Add player selection section
-   [ ] Add "Start Game" button (disabled initially)
-   [ ] Style per design spec

**Acceptance Criteria:**

-   ✓ Layout matches design
-   ✓ Rules text readable
-   ✓ Start button present
-   ✓ Back navigation works

* * * * *

### Task 31: Create Player Model

-   [ ] Create file: Models/Player.swift
-   [ ] Define Player struct: id, displayName, nickname, avatarURL, isGuest, totalWins, totalLosses
-   [ ] Make Identifiable and Codable
-   [ ] Add mock data for testing

**Acceptance Criteria:**

-   ✓ Player model compiles
-   ✓ Supports both guest and connected players
-   ✓ Codable for local storage

* * * * *

### Task 32: Create Player Card Component

-   [ ] Create file: Views/Components/PlayerCard.swift
-   [ ] Add 48pt avatar (left)
-   [ ] Add display name and nickname (center)
-   [ ] Add W/L stats (right)
-   [ ] Set height 80pt
-   [ ] Add dark background with border
-   [ ] Style per design spec

**Acceptance Criteria:**

-   ✓ Card matches design
-   ✓ Avatar, name, stats all visible
-   ✓ Looks good with different data

**Dependencies:** Task 31

* * * * *

### Task 33: Implement Player Selection in Game Detail

-   [ ] Add @State selectedPlayers: [Player] in GameDetailView
-   [ ] Add "Add Guest Player" button
-   [ ] Add "Search for Player" button
-   [ ] Display selected players using PlayerCard
-   [ ] Add remove button on each card
-   [ ] Enable "Start Game" when 2+ players selected
-   [ ] Add player limit (2 for MVP)

**Acceptance Criteria:**

-   ✓ Can add/remove players
-   ✓ Start button enables with 2 players
-   ✓ Player cards display correctly
-   ✓ Limit enforced

**Dependencies:** Task 30, Task 32

* * * * *

### Task 34: Create Add Guest Player Sheet

-   [ ] Create file: Views/Players/AddGuestPlayerView.swift
-   [ ] Add display name TextField
-   [ ] Add nickname TextField
-   [ ] Add "Save" button
-   [ ] Add "Cancel" button
-   [ ] Validate inputs
-   [ ] Style as sheet

**Acceptance Criteria:**

-   ✓ Form validates inputs
-   ✓ Saves new guest player
-   ✓ Dismisses on save or cancel
-   ✓ New player appears in selection

**Dependencies:** Task 33

* * * * *

### Task 35: Implement Navigation from Games List to Detail

-   [ ] Add NavigationStack to GamesListView
-   [ ] Add NavigationLink on GameCard tap
-   [ ] Pass selected game to GameDetailView
-   [ ] Test navigation flow
-   [ ] Ensure back button works

**Acceptance Criteria:**

-   ✓ Tapping game card navigates to detail
-   ✓ Correct game data shown
-   ✓ Back navigation works smoothly

**Dependencies:** Task 28, Task 30

* * * * *

Phase 8: Pre-Game Hype Screen
-----------------------------

### Task 36: Create Pre-Game Hype View

-   [ ] Create file: Views/Games/PreGameHypeView.swift
-   [ ] Add dark background with subtle gradient
-   [ ] Add game name at top (28pt)
-   [ ] Add player 1 avatar (120pt, left side)
-   [ ] Add player 2 avatar (120pt, right side)
-   [ ] Add "VS" text (bold, center, large)
-   [ ] Add nicknames under avatars
-   [ ] Add "GET READY! 🎯" text (bold, bottom)
-   [ ] Style per design spec

**Acceptance Criteria:**

-   ✓ Layout matches boxing match design
-   ✓ All elements positioned correctly
-   ✓ Dark dramatic aesthetic achieved

* * * * *

### Task 37: Implement Hype Screen Animations

-   [ ] Add slide-in animation for avatars (0.6s spring, damping 0.7)
-   [ ] Avatar 1 slides from left
-   [ ] Avatar 2 slides from right
-   [ ] Add fade/scale animation for "VS" (0.4s delay)
-   [ ] Add fade in for "GET READY!"
-   [ ] Use withAnimation and .transition modifiers

**Acceptance Criteria:**

-   ✓ Avatars slide in smoothly
-   ✓ VS appears after slight delay
-   ✓ Animations feel dramatic and energetic
-   ✓ No animation glitches

**Dependencies:** Task 36

* * * * *

### Task 38: Add Bell Sound Effect

-   [ ] Add bell.mp3 to Resources folder
-   [ ] Import AVFoundation
-   [ ] Create SoundManager service (singleton)
-   [ ] Implement playBell() method
-   [ ] Call playBell() when hype screen appears
-   [ ] Test sound playback

**Acceptance Criteria:**

-   ✓ Bell sound plays on hype screen appear
-   ✓ Sound file loads without errors
-   ✓ Volume appropriate

**Dependencies:** Task 36

* * * * *

### Task 39: Implement Hype Screen Auto-Transition

-   [ ] Add @State for navigation to gameplay
-   [ ] Add Timer or Task.sleep for 2-3 second delay
-   [ ] Navigate to GameplayView after delay
-   [ ] Add "Tap to Skip" gesture recognizer
-   [ ] Test auto-transition and manual skip

**Acceptance Criteria:**

-   ✓ Automatically transitions after 2-3 seconds
-   ✓ Can tap to skip immediately
-   ✓ Smooth transition to gameplay

**Dependencies:** Task 37

* * * * *

### Task 40: Connect Hype Screen to Game Flow

-   [ ] Update GameDetailView "Start Game" button
-   [ ] Navigate to PreGameHypeView with game and players
-   [ ] Pass data correctly
-   [ ] Test complete flow: List → Detail → Hype → Gameplay

**Acceptance Criteria:**

-   ✓ Flow works end-to-end
-   ✓ Correct data passed through
-   ✓ No navigation bugs

**Dependencies:** Task 35, Task 39

* * * * *

---

Next: Continue with DanDarts task-list-3