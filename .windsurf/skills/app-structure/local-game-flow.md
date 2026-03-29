> Supporting reference for: app-structure  
> Apply when: working on local game flow, game setup, gameplay screens, 
> end game behavior, or any task involving the GamesTab → GameEnd 
> navigation sequence  
> Do not apply to: remote match flow, tab-level structure, database 
> schema, or realtime behavior unless it directly affects local game 
> screen state

# Local Game Flow

## Purpose

This document describes the complete local match flow in Dart Freak,
from game selection through to end game.

It exists so Windsurf understands what each screen owns, what states
it can be in, and what triggers each transition — before touching any
local game code.

---

## Flow Summary
```
GamesTab → GameSetupView → PreGameHypeView → GameplayView → GameEndView
```

---

## Screen 1 — GamesTab (GamesListView)

### What it owns
- Static game list (`Game.loadGames()`)
- Current selected game index and scroll position
- Entry point navigation via router

### States
- Idle — displaying game list
- Selecting — user tapped Play on a game card
- Navigating — transitioning to GameSetupView

### Transition trigger
```swift
AppButton("Play") {
    onGameSelected(game) // router.push(.gameSetup(game: game))
}
```

---

## Screen 2 — GameSetupView

### What it owns
- Game configuration (`GameSetupConfigurable`)
- Player selection and validation (`GameSetupState`)
- Friends cache and guest player storage
- Sheet presentations and search state

### States
- Loading — fetching friends, loading guest players
- Configuring — selecting players, choosing game options
- Validating — checking minimum player requirements
- Ready — valid configuration, can start game

### Key state
```swift
@StateObject private var setupState = GameSetupState()
@State private var showSearchPlayer: Bool = false
private var canStartGame: Bool { 
    selectedPlayers.count >= config.minimumPlayers 
}
```

### Transition triggers
- Start Game — valid config → `router.push(.preGameHype(...))`
- Cancel — back button → return to GamesTab

---

## Screen 3 — PreGameHypeView

### What it owns
- Animation timeline and state
- Game info, player list, match format
- Navigation routing to correct gameplay view

### States
- Initializing — setting up animation timeline
- Animating — sequential reveal (players → VS → get ready)
- Ready — animations complete, user can tap to skip
- Transitioning — navigating to gameplay

### Key state
```swift
@State private var showPlayers = false
@State private var showVS = false
@State private var showGetReady = false
```

### Transition triggers
- Auto-transition — animations complete → `navigateToGameplay()`
- Manual skip — user taps screen → `navigateToGameplay()`

### Routing logic
- Halve-It → `.halveItGameplay`
- Knockout → `.knockoutGameplay`
- Countdown (301/501) → `.countdownGameplay`

---

## Screen 4 — GameplayView (Game-Specific)

### What it owns
- Game state via `GameViewModel`
- Scores, current player, turn history
- Scoring validation and win detection
- Turn management and dart input
- Menu visibility, alerts, scoreboard expansion

### States
- Starting — initializing ViewModel
- Playing — active dart input
- Scoring — processing throws, updating scores
- Turn End — switching players
- Leg Win — celebrating leg completion (multi-leg)
- Game End — winner detected, transitioning out

### Key state (countdown example)
```swift
@StateObject private var gameViewModel: CountdownViewModel
@Published var currentPlayerIndex: Int = 0
@Published var playerScores: [UUID: Int] = [:]
@Published var winner: Player? = nil
@Published var isMatchWon: Bool = false
```

### Transition triggers
- Game won — `gameViewModel.winner != nil` → navigate to GameEndView
- Leg won — `gameViewModel.legWinner != nil` → celebrate, continue
- Exit — user cancels → return to GamesTab

---

## Screen 5 — GameEndView

### What it owns
- Winner reveal and celebration animation
- Sound effects and trophy display
- Final scores and match results
- Navigation options (play again, change players, back)
- Optional match details and statistics

### States
- Initializing — setting up celebration
- Celebrating — winner reveal with animations
- Displaying — showing final scores and results
- Navigating — user selected next action

### Key state
```swift
@State private var showCelebration = false
@State private var showMatchDetails = false
let matchResult: MatchResult?
```

### Transition triggers
- Play Again → reset game, return to GameplayView
- Change Players → return to GameSetupView
- Back to Games → return to GamesTab
- Match Details → navigate to match details view

---

## Data Flow Through the Screens

| Handoff | Data Passed |
|---------|-------------|
| GamesTab → GameSetupView | `Game` object |
| GameSetupView → PreGameHypeView | players + config |
| PreGameHypeView → GameplayView | all game data |
| GameplayView → GameEndView | winner + match result |
| GameEndView → destination | restart / reconfigure signal |

---

## Bottom Line

Local game flow is a linear five-screen sequence.

Each screen owns its own state and passes only essential data forward.
No screen reaches back into a previous screen's state.
Router owns all navigation execution.