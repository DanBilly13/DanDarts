---
trigger: always_on
---

Extra Implementation
----------------------

### Task 100: Implement Voice Scoring Modal

-   [ ]  Add Speech framework permission to Info.plist
-   [ ]  Create VoiceScoringService with SFSpeechRecognizer
-   [ ]  Implement continuous listening for wake phrase "score visit"
-   [ ]  Present VoiceScoringModal (full screen) when wake phrase detected
-   [ ]  Show "Listening..." state with microphone animation
-   [ ]  Recognize dart scores: numbers (1-20, 25, 50), "double"/"D", "triple"/"T", "miss"
-   [ ]  Parse and display recognized throw (e.g., "15 D5 10")
-   [ ]  Show "Save Score" and "Cancel" buttons in modal
-   [ ]  Listen for voice commands: "save score" or "cancel"
-   [ ]  Also support tap on buttons
-   [ ]  On save: apply scores to GameViewModel and dismiss
-   [ ]  On cancel: dismiss modal, return to manual entry
-   [ ]  Handle misrecognition errors gracefully

**Acceptance Criteria:**

-   ✓ Detects "score visit" wake phrase
-   ✓ Modal appears with clear UI (Siri-style)
-   ✓ Recognizes numbers, doubles, triples, miss
-   ✓ Displays parsed throw clearly (e.g., "15 D5 10")
-   ✓ Both voice ("save score"/"cancel") and tap work for confirmation
-   ✓ Applies scores correctly on save
-   ✓ Dismisses cleanly on cancel
-   ✓ Gives audio/haptic feedback
-   ✓ Works in reasonably noisy environments

**Dependencies:** Task 44, Task 47

**Note:** Wake phrase listening can be paused during opponent's turn to save battery and avoid false triggers.

*****

### Task 101: Add Voice Scoring Settings Toggle

-   [ ]  Add "Voice Scoring" toggle to ProfileView settings section
-   [ ]  Store preference in UserDefaults (key: "voiceScoringEnabled")
-   [ ]  Default to ON for new users
-   [ ]  Load preference on app launch
-   [ ]  Update VoiceScoringService to respect setting
-   [ ]  Disable wake phrase listening when toggle is OFF
-   [ ]  Show explanatory text: "Say 'Score visit' during gameplay to enter scores by voice"
-   [ ]  Request microphone permission when toggle turned ON (if not already granted)
-   [ ]  Handle permission denied gracefully (disable toggle, show alert)

**Acceptance Criteria:**

-   ✓ Toggle visible in settings
-   ✓ Preference persists across app launches
-   ✓ Wake phrase listening disabled when OFF
-   ✓ Microphone permission handled correctly
-   ✓ Clear explanation of feature shown
-   ✓ Default state is ON

**Dependencies:** Task 48.1, Task 69 (Settings section)

*****

Task 200: Add Legs Selection to Game Detail (301/501)
-----------------------------------------------------

-   [ ]  Add legs selector to GameDetailView (above player selection)
-   [ ]  Only show for 301 and 501 game types
-   [ ]  Create segmented control or picker with options: "Best of 1", "Best of 3", "Best of 5", "Best of 7"
-   [ ]  Store selected legs count in @State
-   [ ]  Default to "Best of 1" (single game)
-   [ ]  Pass legs configuration to GameViewModel on game start
-   [ ]  Add label: "Match Format" or "Legs"
-   [ ]  Style per design spec

**Acceptance Criteria:**

-   ✓ Legs selector visible only for 301/501
-   ✓ Options: Best of 1, 3, 5, 7
-   ✓ Default is Best of 1
-   ✓ Selection persists during game setup
-   ✓ Visual design matches other selectors

**Dependencies:** Task 30, Task 33

* * * * *

Task 201: Implement Multi-Leg Match Logic
-----------------------------------------

-   [ ]  Update GameViewModel to track legs
-   [ ]  Add @Published currentLeg: Int
-   [ ]  Add @Published legsWon: [UUID: Int] (player ID to legs won)
-   [ ]  Add @Published matchFormat: Int (1, 3, 5, or 7)
-   [ ]  When a leg is won: increment winner's leg count
-   [ ]  Check if match is won (e.g., 2 legs in best of 3)
-   [ ]  If match not won: reset scores and start new leg
-   [ ]  If match won: show final match winner
-   [ ]  Display current leg status during gameplay (e.g., "Leg 2/5")
-   [ ]  Update match save to include legs data

**Acceptance Criteria:**

-   ✓ Tracks legs won per player
-   ✓ Automatically starts new leg after leg win
-   ✓ Detects match winner correctly (first to required legs)
-   ✓ Displays leg score during gameplay
-   ✓ Shows current leg number
-   ✓ Match result includes legs won

**Dependencies:** Task 47, Task 52, Task 200

* * * * *

Task 202: Update UI for Multi-Leg Display
-----------------------------------------

-   [ ]  Add legs header to GameplayView (above player cards)
-   [ ]  Show current leg format: "Leg 2/5" (current leg / total legs in match)
-   [ ]  Show legs won for each player with visual indicators (filled/empty dots or circles)
-   [ ]  Alternative format: "Bob: ⚫⚫⚪ Alice: ⚫⚪⚪"
-   [ ]  Position clearly but don't obstruct player info
-   [ ]  Update GameEndView to show match result with legs
-   [ ]  Display: "Bob wins 2-0" or "Alice wins 2-1"
-   [ ]  Add subtle transition animation when moving to next leg
-   [ ]  Distinguish between leg win and match win celebrations (smaller for leg, full confetti for match)
-   [ ]  Style per design spec (dark mode, accent colors)

**Acceptance Criteria:**

-   ✓ "Leg X/Y" format displayed in header
-   ✓ Legs won visible for each player (visual indicators)
-   ✓ Clear but unobtrusive positioning
-   ✓ Match result shows final leg score
-   ✓ Different celebration animations for leg vs match wins
-   ✓ Smooth transition to next leg
-   ✓ Design matches existing UI aesthetic

**Dependencies:** Task 201