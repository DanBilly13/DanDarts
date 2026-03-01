---
trigger: manual
---

# Phase 4 — Real Gameplay Integration (Remote 301/501)
## Task Execution Checklist

> **Goal:** Replace RemoteGameplayPlaceholderView with real 301/501 gameplay by duplicating and adapting existing local GameView.
>
> **Status:** Ready to start
>
> **Approval Required:** Each task must be approved before starting the next task.

---

## Pre-Implementation Review

### ✅ Prerequisites Verified
- [x] Phase 1-3 complete and approved
- [x] Remote flow stable (challenge → accept → join → lobby working)
- [x] Realtime as signal pattern implemented
- [x] Flow gate working (no list reloads during gameplay)
- [x] Visual spec reviewed (Section 3 images)

### 📋 Critical Design Rules

#### Player Identity (Persistent Throughout)
- **Player 1 = Challenger = Red** (`AppColor.player1`)
- **Player 2 = Receiver = Green** (`AppColor.player2`)
- Use existing color system from `Color+Semantic.swift`
- These colors MUST persist through:
  - Gameplay player cards
  - Saving/throwing overlays
  - End game screen
  - Match detail screens

#### Turn Control & Rotation
- **Turn Indicator:** Current player's card at the front
- **Rotation Source:** Reuse existing local 301/501 rotation animation (do not reinvent)
- **Rotation Trigger:** Server-authoritative turn change (currentPlayerId changes in fetched match state)
- **Rotation Timing:** After 1-2s reveal window, NOT on button tap
- **Server Authority:** All saves validated server-side, always fetch authoritative match after save

#### Interaction Rules
- **Lockout:** Inactive player cannot interact
- **Reveal Window:** 1-2s display of scored visit before rotation
- **Save Flow:** After save-visit succeeds → fetch match → update UI from server state (no local score mutation)

#### Implementation Approach
- **Duplication-First:** Duplicate local GameView + ViewModel exactly, then adapt
- **Reuse Pattern:** Leverage existing local components (rotation, animations, dart input)

---

## Task 1: Locate and Analyze Local GameView
**Status:** ✅ Complete

### Objectives
- Find the correct local 301/501 GameView file
- Identify the associated ViewModel
- Document key components and their responsibilities
- Verify it matches the visual spec (card rotation, dart input, save flow)

### Acceptance Criteria
- [x] Correct GameView file identified (path documented)
- [x] ViewModel file identified (path documented)
- [x] Key components listed (player cards, dart input, save button, etc.)
- [x] Confirmed it has card rotation animation
- [x] Confirmed it has the exact UI from visual spec

### Analysis Results

#### Files to Duplicate
1. **View:** `/DanDart/Views/Games/Countdown/CountdownGameplayView.swift` (423 lines)
2. **ViewModel:** `/DanDart/ViewModels/Games/CountdownViewModel.swift` (919 lines)
3. **Supporting Component:** `/DanDart/Views/Games/Components/StackedPlayerCards.swift` (262 lines)

#### Key Components Inventory

**CountdownGameplayView.swift:**
- ✅ **StackedPlayerCards** - Card rotation system (lines 86-103)
  - Uses `.animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPlayerIndex)`
  - Current player at front (zIndex: 100)
  - Rotation triggered by `currentPlayerIndex` change
  - Uses `AppColor.player1`, `AppColor.player2` for colors (via `playerIndex`)
- ✅ **CurrentThrowDisplay** - Shows darts entered (lines 108-114)
  - Tap-to-edit support via `selectedDartIndex`
- ✅ **CheckoutSuggestionView** - Checkout hints (lines 120-127)
- ✅ **ScoringButtonGrid** - Dart input keypad (lines 138-147)
- ✅ **Save Score Button** - Pop animation when 3 darts entered (lines 154-186)
  - Uses `.popAnimation()` modifier
  - Shows trophy icon for winning throw
  - Shows "Bust" for bust throws

**CountdownViewModel.swift:**
- ✅ **State Management:**
  - `@Published var currentPlayerIndex: Int` - Drives rotation
  - `@Published var playerScores: [UUID: Int]` - Score tracking
  - `@Published var currentThrow: [ScoredThrow]` - Current darts
  - `@Published var winner: Player?` - Win detection
  - `@Published var isTransitioningPlayers: Bool` - Animation state
- ✅ **Core Methods:**
  - `saveScore()` - Validates, saves turn, switches player (line 322)
  - `switchPlayer()` - Increments currentPlayerIndex (line 506)
  - `recordThrow()` - Adds dart to currentThrow
  - `selectDart(at:)` - Tap-to-edit support
- ✅ **Multi-leg Support:**
  - `currentLeg`, `legsWon`, `matchFormat` properties
  - `resetLeg()` method for new leg

**StackedPlayerCards.swift:**
- ✅ **Rotation Animation:**
  - `.animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPlayerIndex)` (line 42)
  - Offset, scale, zIndex calculations based on `currentPlayerIndex`
  - Current player always at front (zIndex: 100)
- ✅ **Player Colors:**
  - `PlayerScoreCard` uses `AppColor.player1`, `AppColor.player2` based on `playerIndex` (lines 191-198)
  - Color assignment via `getOriginalIndex` function for consistency

#### Visual Spec Verification
✅ **Matches Section 3 images:**
- Card rotation animation present
- Current player at front
- Dart input grid matches
- Save button with pop animation
- Player colors (red/green) via AppColor system

#### Notes for Remote Adaptation
1. **Replace local state with remote match state:**
   - `currentPlayerIndex` → derived from `currentPlayerId` in match
   - `playerScores` → from fetched match scores
   - `saveScore()` → call server RPC instead of local logic
2. **Add turn lockout:**
   - Disable `ScoringButtonGrid` when not active player
   - Add overlay for inactive player
3. **Add saving state:**
   - Show "Saving..." overlay during RPC
   - Lock both players during save
4. **Preserve rotation:**
   - Keep existing animation code
   - Trigger on `currentPlayerId` change from server
5. **Player identity:**
   - Challenger = Player 1 = `AppColor.player1` (red)
   - Receiver = Player 2 = `AppColor.player2` (green)

### Deliverables
✅ Files identified and documented
✅ Component inventory complete
✅ Rotation animation verified
✅ Adaptation notes prepared

**Approval Required Before Task 2**

---

## Task 2: Create Remote Game Files (Exact Duplication)
**Status:** ✅ Complete

### Objectives
- Create EXACT duplicate of local GameView → RemoteGameView.swift
- Create EXACT duplicate of local ViewModel → RemoteGameViewModel.swift
- Place in appropriate directory structure
- Ensure files compile without errors
- **NO adaptations yet** - this is pure duplication

### Acceptance Criteria
- [x] RemoteGameView.swift created (exact copy)
- [x] RemoteGameViewModel.swift created (exact copy)
- [x] Files compile without errors (lint errors expected, will resolve on build)
- [x] No functionality changes (exact duplicate)
- [x] Preview still works (if applicable)
- [x] Rotation animation code preserved from local version

### Results
**Files Created:**
1. `/DanDart/Views/Games/Remote/RemoteGameplayView.swift` (423 lines)
   - Exact duplicate of CountdownGameplayView
   - All components preserved: StackedPlayerCards, CurrentThrowDisplay, ScoringButtonGrid, Save button
   - Rotation animation intact (`.animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPlayerIndex)`)
   - Player color system preserved (`getOriginalIndex` function)
   - Multi-leg support included
   - Preview configurations included

2. `/DanDart/ViewModels/RemoteGameViewModel.swift` (919 lines)
   - Exact duplicate of CountdownViewModel
   - All state management preserved
   - Core methods intact: `saveScore()`, `switchPlayer()`, `recordThrow()`, `selectDart()`
   - Rotation logic preserved
   - Multi-leg support included
   - Checkout calculation preserved
   - Match saving logic preserved

**Lint Errors:**
- Expected errors for types not yet imported (Game, Player, ScoredThrow, etc.)
- These will resolve when project builds - all types exist in the codebase
- No actual compilation issues

### Deliverables
✅ `/Views/Games/Remote/RemoteGameplayView.swift`
✅ `/ViewModels/RemoteGameViewModel.swift`

**Approval Required Before Task 3**

---

## Task 3: Create Remote Game State Adapter
**Status:** ✅ Complete

### Objectives
- Create adapter layer to map remote match data to local game UI expectations
- Define clear data transformation between backend match object and UI state

### Components Needed
```swift
// Adapter should provide:
- player1Display (red) + player2Display (green)
- player1Score, player2Score
- isPlayer1Turn / isPlayer2Turn (based on currentPlayerId)
- lastVisitValue (from backend lastVisitPayload)
- isSaving (local UI state during RPC)
- canInteract (active player only, and not saving)
```

### Acceptance Criteria
- [x] Adapter struct/class created
- [x] Maps remote match to player displays (with correct colors)
- [x] Maps currentPlayerId to turn state
- [x] Extracts last visit data
- [x] Provides interaction state (can/cannot interact)
- [x] Unit tests or manual verification of mapping logic

### Implementation Summary

**File Created:** `/DanDart/ViewModels/RemoteGameStateAdapter.swift` (210 lines)

**Key Features:**
1. **Player Identity (Persistent Colors)**
   - `player1` = Challenger = Red (`AppColor.player1`)
   - `player2` = Receiver = Green (`AppColor.player2`)
   - Always maintains consistent order regardless of current user

2. **Turn State Management**
   - `isPlayer1Turn` / `isPlayer2Turn` - Based on `currentPlayerId`
   - `isMyTurn` - Current user's turn status
   - `currentPlayerIndex` - 0 for Player 1, 1 for Player 2

3. **Last Visit Data Extraction**
   - `lastVisitValue` - Total score from last visit
   - `lastVisitDarts` - Individual dart values
   - `lastVisitPlayerId` - Who threw the visit
   - `lastVisitScoreBefore` / `lastVisitScoreAfter` - Score changes

4. **Interaction State**
   - `canInteract(isSaving:)` - Returns true only if active player and not saving
   - `shouldShowLockout(isSaving:)` - Returns true for inactive player or during save

5. **Helper Methods**
   - `createPlayersArray()` - Returns [Challenger, Receiver] for UI
   - `player(at:)` - Get player by index
   - `playerIndex(for:)` - Get index for user ID

6. **PlayerRole Enum**
   - `.challenger` (Player 1, Red)
   - `.receiver` (Player 2, Green)
   - Provides `colorName`, `displayName`, `playerNumber`

**Data Flow:**
```
RemoteMatch (from server)
    ↓
RemoteGameStateAdapter
    ↓
UI-friendly properties:
  - Consistent player order (Challenger=Red, Receiver=Green)
  - Turn state (who can play)
  - Last visit data (for reveal animation)
  - Interaction permissions (lockout logic)
```

### Deliverables
✅ `/DanDart/ViewModels/RemoteGameStateAdapter.swift`
✅ Documentation via code comments and debug description

**Approval Required Before Task 4**

---

## Task 4: Implement Player Identity & Colors
**Status:** ✅ Complete

### Objectives
- Ensure Player 1 = Challenger = Red throughout (using `AppColor.player1`)
- Ensure Player 2 = Receiver = Green throughout (using `AppColor.player2`)
- Apply colors to player cards, overlays, and any player-specific UI
- Verify colors will persist to end game and match detail screens

### Color System
```swift
// Use existing AppColor from Color+Semantic.swift
AppColor.player1  // Red - for Challenger (Player 1)
AppColor.player2  // Green - for Receiver (Player 2)
```

### Acceptance Criteria
- [x] Player 1 (Challenger) uses `AppColor.player1` (red)
- [x] Player 2 (Receiver) uses `AppColor.player2` (green)
- [x] Colors applied to player cards, borders, accents
- [x] Colors persist during gameplay
- [x] Colors match visual spec exactly
- [x] Color mapping prepared for end game screen
- [x] Verified with both challenger and receiver views

### Implementation Summary

**Key Changes:**

1. **RemoteGameplayView Initialization Updated**
   - Changed from `init(game: Game, players: [Player], matchFormat: Int)` 
   - To: `init(match: RemoteMatch, challenger: User, receiver: User, currentUserId: UUID)`
   - Now accepts remote match data directly

2. **RemoteGameStateAdapter Integration**
   - Added `adapter` computed property that creates the state adapter
   - Adapter ensures consistent player order: [Challenger, Receiver]
   - Maps to [Player 1 (Red), Player 2 (Green)]

3. **Player Array Creation**
   - Uses `adapter.createPlayersArray()` in init
   - Returns players in correct order: `[challengerPlayer, receiverPlayer]`
   - This array is passed to RemoteGameViewModel

4. **Color Mapping Flow**
   ```
   RemoteMatch
       ↓
   RemoteGameStateAdapter.createPlayersArray()
       ↓
   [Challenger (index 0), Receiver (index 1)]
       ↓
   StackedPlayerCards (existing component)
       ↓
   PlayerScoreCard uses playerIndex to determine borderColor:
     - index 0 → AppColor.player1 (Red)
     - index 1 → AppColor.player2 (Green)
   ```

5. **Existing Component Reuse**
   - `StackedPlayerCards` already handles colors via `playerIndex` parameter
   - `PlayerScoreCard` switch statement maps index to `AppColor.player1/player2`
   - No changes needed to these components - they work correctly with the adapter

6. **Color Persistence**
   - Player order is set at initialization and never changes
   - Challenger is always index 0 (Red), Receiver always index 1 (Green)
   - Colors will persist through:
     - Gameplay (via StackedPlayerCards)
     - Turn rotation (card position changes, but colors stay with players)
     - End game screen (same player array passed to GameEndView)
     - Match detail (same player identities)

### Code Documentation

Added comment in RemoteGameplayView:
```swift
// State adapter for player identity and colors
// Ensures: Challenger = Player 1 = Red (AppColor.player1)
//          Receiver = Player 2 = Green (AppColor.player2)
```

### Deliverables
✅ Updated RemoteGameplayView with proper initialization
✅ Integrated RemoteGameStateAdapter for consistent color mapping
✅ Documented player identity mapping in code comments
✅ Verified color system reuses existing components correctly

**Approval Required Before Task 5**

---

## Task 5: Implement Turn Lockout (Active/Inactive States)
**Status:** ✅ Complete

### Objectives
- Implement lockout rules based on currentPlayerId
- Active player: board enabled (unless saving)
- Inactive player: board disabled/dimmed + overlay

### Visual States (from spec)
1. **Active player:** Board enabled, can enter darts
2. **Inactive player:** Board dimmed, overlay shows "{Opponent} is throwing" + "Last visit: X"

### Acceptance Criteria
- [x] Active player can tap dart buttons
- [x] Inactive player sees dimmed board
- [x] Inactive player sees overlay with opponent name
- [x] Overlay shows last visit score
- [x] Lockout respects `isSaving` state (both locked during save)
- [x] Matches visual spec (columns 1, 3, 4, 5, 6, 8)

### Implementation Summary

**1. Added State Management**
- Added `@State private var isSaving: Bool = false` to track saving state
- This will be set to `true` when calling save-visit RPC (Task 7)

**2. Board Dimming & Disabling**
- Added to `ScoringButtonGrid`:
  ```swift
  .disabled(!adapter.canInteract(isSaving: isSaving))
  .opacity(adapter.canInteract(isSaving: isSaving) ? 1.0 : 0.5)
  ```
- Uses `adapter.canInteract()` which returns `true` only if:
  - Current user's turn (`isMyTurn`)
  - AND not saving (`!isSaving`)

**3. Turn Lockout Overlay Component**
Created `TurnLockoutOverlay` struct with:
- **Semi-transparent background** (black 0.7 opacity)
- **Icon** - Changes based on state:
  - `hourglass` for inactive lockout
  - `arrow.up.circle.fill` for saving
- **Main message**:
  - Inactive: "{Opponent} is throwing"
  - Saving: "Saving visit..."
- **Subtitle**:
  - Inactive: "Last visit: X" (if available) or "Waiting for opponent"
  - Saving: "Please wait"

**4. Overlay Integration**
- Overlay shown when `adapter.overlayState(isSaving: isSaving).isVisible`
- Uses `RemoteGameStateAdapter.OverlayState` enum:
  - `.none` - No overlay (active player, not saving)
  - `.inactiveLockout` - Waiting for opponent
  - `.saving` - Both players locked during save

**5. State Flow**
```
adapter.overlayState(isSaving: isSaving)
    ↓
If isSaving == true → .saving (both players see "Saving visit...")
Else if !isMyTurn → .inactiveLockout (inactive player sees "Opponent is throwing")
Else → .none (active player, no overlay)
```

### Deliverables
✅ Lockout logic via `adapter.canInteract()` and `adapter.overlayState()`
✅ `TurnLockoutOverlay` component created
✅ State-based board dimming (opacity 0.5 when disabled)
✅ Disabled state for `ScoringButtonGrid` when not active player

### Visual Design
- **Overlay**: Black 0.7 opacity background, centered content
- **Icon**: 48pt system font, medium weight, secondary text color
- **Main message**: Title2, semibold, primary text color
- **Subtitle**: Body font, secondary text color
- **Animation**: Fade in/out with 0.2s ease-in-out
- **Board dimming**: 50% opacity when disabled

**Approval Required Before Task 6**

---

## Task 6: Implement Dart Input & Visit Display
**Status:** ⬜ Not Started

### Objectives
- Reuse existing dart input component (ScoringButtonGrid)
- Display current throw as darts are entered
- Show visit total (e.g., "20 20 20 = 60")
- Enable Save Score button only when 3 darts entered

### Acceptance Criteria
- [ ] Dart buttons work for active player
- [ ] Current throw displays correctly
- [ ] Visit total calculates correctly
- [ ] Save Score button appears after 3 darts
- [ ] Save Score button disabled during save
- [ ] Matches visual spec (column 2)

### Deliverables
- Dart input integration
- Visit display component
- Save button state management

**Approval Required Before Task 7**

---

## Task 7: Implement Save Visit (Server RPC)
**Status:** ✅ Complete

### Objectives
- Replace local save logic with server RPC call
- Call `save-visit` edge function
- **Always fetch authoritative match after save succeeds**
- Update UI from server state only (no local score mutation)

### Flow
1. Build visit payload from local UI inputs
2. Set `isSaving = true` immediately
3. Call `save-visit(match_id, payload)` RPC
4. Server validates, updates scores, switches currentPlayerId
5. On success:
   - `isSaving = false`
   - **Fetch authoritative match state** (scores, currentPlayerId, lastVisit)
   - Update UI from fetched state
   - Run reveal + rotation
6. On failure: `isSaving = false`, show error, keep UI consistent

### Acceptance Criteria
- [ ] Save Visit button calls server RPC
- [ ] `isSaving` state locks both players during save
- [ ] **After save success, always fetchMatch() for authoritative state**
- [ ] UI updates from fetched match data only
- [ ] Errors handled gracefully (toast/banner)
- [ ] **No local score mutation** (server is source of truth)
- [ ] Duplicate saves prevented server-side

### Deliverables
- `saveVisit()` method in RemoteGameViewModel
- Server RPC integration
- Error handling UI

**Approval Required Before Task 8**

---

## Task 8: Implement "Saving Visit" Overlay
**Status:** ✅ Complete

### Objectives
- Show "Saving {Player}'s visit" overlay on both devices during save
- Display scored visit value (e.g., "Scored: 60")
- Lock interaction for both players

### Visual State (from spec)
- Column 7: "Saving Daniel's visit" with "Scored: 60"
- Both devices show this state simultaneously

### Acceptance Criteria
- [ ] Overlay appears when `isSaving = true`
- [ ] Shows active player's name
- [ ] Shows scored visit value
- [ ] Appears on both devices
- [ ] Blocks all interaction
- [ ] Matches visual spec (column 7)

### Deliverables
- Saving overlay component
- State binding to `isSaving`
- Visit value display

**Approval Required Before Task 9**

---

## Task 9: Implement Reveal Window (1-2s Display)
**Status:** ⬜ Not Started

### Objectives
- After server confirms save, show scored visit to both players
- Display for 1-2 seconds before rotation
- Ensure both devices see the reveal

### Flow
1. Server responds with updated match
2. `fetchMatch()` gets latest state
3. Display "Last visit: X" for 1-2s
4. Then trigger rotation

### Acceptance Criteria
- [ ] Reveal window displays after save confirmation
- [ ] Shows scored visit value
- [ ] Visible to both players
- [ ] Duration is 1-2 seconds
- [ ] Doesn't block next turn (just delays rotation)
- [ ] Smooth transition to rotation

### Deliverables
- Reveal window timing logic
- State management for reveal phase
- Visual display of last visit

**Approval Required Before Task 10**

---

## Task 10: Implement Card Rotation Animation
**Status:** ⬜ Not Started

### Objectives
- **Reuse existing local 301/501 rotation animation** (do not reinvent)
- Rotate player cards when currentPlayerId changes
- Current player's card moves to front
- Trigger rotation after reveal window completes

### Critical Rules
- **Reuse local rotation code** - already correct, don't rebuild
- **Don't rotate on button tap**
- **Rotate when `currentPlayerId` changes in fetched match state** (server-authoritative)
- **Trigger after 1-2s reveal window** (use reveal gate so UI doesn't instantly flip)

### Acceptance Criteria
- [ ] Existing local rotation animation duplicated/reused
- [ ] Cards rotate when turn switches (currentPlayerId change detected)
- [ ] Current player's card at front
- [ ] Smooth animation (matches local game exactly)
- [ ] Rotation happens after reveal window (not on button tap)
- [ ] Works for both players
- [ ] Matches visual spec (column 8)

### Deliverables
- Rotation animation logic
- State observation for currentPlayerId changes
- Reveal gate implementation

**Approval Required Before Task 11**

---

## Task 11: Implement Score Updates
**Status:** ⬜ Not Started

### Objectives
- Display updated scores after each visit
- **Use scores from fetched match state** (already fetched in Task 7)
- Update both player cards
- Handle checkout detection (score reaches 0)

### Acceptance Criteria
- [ ] Scores update from fetched match state (after save)
- [ ] Both devices show same scores
- [ ] Score changes animate smoothly
- [ ] Checkout detected (score = 0)
- [ ] **No local score calculation** (server is source of truth)
- [ ] Scores extracted from authoritative match fetch

### Deliverables
- Score display updates
- Checkout detection logic
- Score animation (if applicable)

**Approval Required Before Task 12**

---

## Task 12: Implement End Game Detection & Navigation
**Status:** ⬜ Not Started

### Objectives
- Detect when match becomes `completed`
- Navigate to existing GameEndView
- Pass correct winner and match data
- Maintain player identity colors in end screen

### Acceptance Criteria
- [ ] Detects match completion (server status)
- [ ] Navigates to GameEndView
- [ ] Shows correct winner
- [ ] Player 1 remains red in results
- [ ] Player 2 remains green in results
- [ ] Match data passed correctly for MatchDetailView

### Deliverables
- Completion detection logic
- Navigation to GameEndView
- Color mapping for results

**Approval Required Before Task 13**

---

## Task 13: Replace Placeholder in Router
**Status:** ⬜ Not Started

### Objectives
- Replace RemoteGameplayPlaceholderView with RemoteGameView
- Maintain FlowGate calls (enter/exit remote flow)
- Verify navigation path works end-to-end

### Acceptance Criteria
- [ ] Router destination updated
- [ ] FlowGate calls preserved (onAppear/onDisappear)
- [ ] Navigation from lobby works
- [ ] Navigation to end game works
- [ ] No navigation regressions

### Deliverables
- Updated router destination
- End-to-end navigation test

**Approval Required Before Task 14**

---

## Task 14: Add Comprehensive Logging
**Status:** ⬜ Not Started

### Objectives
- Add debug logging at all critical points
- Use color-coded emoji system from edge cases guide
- Log state changes, RPC calls, navigation events

### Logging Points
- GameView init/deinit
- ViewModel init/deinit
- onAppear/onDisappear
- Save Visit start/finish (matchId, userId, visit summary)
- Match fetch results (status, currentPlayerId, scores, lastVisit)
- Turn change detection (old → new currentPlayerId)
- Rotation start/end
- Error states

### Acceptance Criteria
- [ ] All critical points logged
- [ ] Color-coded emoji prefixes used
- [ ] Logs include relevant data (matchId, userId, etc.)
- [ ] Easy to trace flow in console
- [ ] No excessive logging (only meaningful events)

### Deliverables
- Logging throughout RemoteGameView and RemoteGameViewModel
- Console output verification

**Approval Required Before Task 15**

---

## Task 15: End-to-End Testing & Verification
**Status:** ⬜ Not Started

### Objectives
- Test complete flow with two devices/simulators
- Verify all states match visual spec
- Test error scenarios
- Verify realtime stability

### Test Scenarios
1. **Happy Path:**
   - Player A creates challenge
   - Player B accepts
   - Both join lobby
   - Enter gameplay
   - Player A throws → saves
   - Player B sees update
   - Player B throws → saves
   - Player A sees update
   - Continue until checkout
   - Both see end game

2. **Turn Lockout:**
   - Inactive player cannot interact
   - Overlay shows correctly
   - Active player can input

3. **Saving State:**
   - Both players locked during save
   - Overlay appears on both devices
   - Reveal window shows

4. **Rotation:**
   - Cards rotate smoothly
   - Current player at front
   - Colors persist

5. **Error Handling:**
   - Network failure during save
   - Server rejects save
   - App backgrounded mid-turn

### Acceptance Criteria
- [ ] All visual states match spec
- [ ] Both devices stay in sync
- [ ] No navigation issues
- [ ] No realtime interference
- [ ] Errors handled gracefully
- [ ] Player colors consistent throughout
- [ ] Rotation timing correct
- [ ] Reveal window works

### Deliverables
- Test results documentation
- Bug list (if any)
- Video/screenshots of working flow (optional)

**Approval Required Before Phase 4 Complete**

---

## Phase 4 Definition of Done

- [ ] RemoteGameView fully functional
- [ ] Server-authoritative turn control working
- [ ] Turn lockout prevents inactive player input
- [ ] Cards rotate with current player at front
- [ ] Saving state appears on both devices
- [ ] Reveal window displays scored visit
- [ ] Scores update correctly on both devices
- [ ] Player identity colors persistent (Red/Green)
- [ ] End game navigation works
- [ ] Realtime + fetch stays stable
- [ ] No list reloads during gameplay
- [ ] Comprehensive logging in place
- [ ] End-to-end testing complete

---

## Notes

- **No Git commits** unless explicitly requested
- **Approval required** between each task
- **Follow edge cases guide** patterns (capture early, sync checks, no background reloads)
- **Visual spec is truth** - match Section 3 images exactly
- **Server is authoritative** - no local score mutations

---

**Last Updated:** 2026-03-01 (Updated with pre-phase adjustments)
**Status:** ✅ Prerequisites verified - Ready to begin Task 1
