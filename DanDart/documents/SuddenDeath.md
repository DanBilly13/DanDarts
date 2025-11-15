# Sudden Death Game

This document describes the Sudden Death game implementation in the DanDart app.

## Overview

- **Game type:** Sudden Death
- **Core rule:** Each round, the player(s) with the lowest total score lose one life.
- **Lives modes:** Classic (1 life), 3 lives, 5 lives.
- **Players:** Uses the existing player system (supports up to 6 players).
- **Goal:** Last player with lives remaining wins.

---

## Setup & Routing

### SuddenDeathSetupConfig

File: `Views/GameSetup/GameSetupOptions/SuddenDeathSetupConfig.swift`

- Conforms to `GameSetupConfigurable`.
- Exposes a segmented control for lives:
  - `1` (Classic)
  - `3` lives
  - `5` lives
- Produces `GameParameters` with a Sudden Death–specific lives parameter (mirroring the Knockout lives pattern).

### GameSetupView

File: `Views/GameSetup/GameSetupView.swift`

- The config switch is extended to return `SuddenDeathSetupConfig` when the selected game is Sudden Death.
- This gives Sudden Death its own setup options while reusing the common setup UI.

### Router & PreGameHypeView

Files:
- `Services/Router.swift`
- `Views/Games/Shared/PreGameHypeView.swift`

- New router destination: `.suddenDeathGameplay`.
- Pre-game hype view routes Sudden Death to `SuddenDeathGameplayView` and passes:
  - `game`
  - `players`
  - `startingLives` (from the setup lives selector).

---

## ViewModel: SuddenDeathViewModel

File: `ViewModels/Games/SuddenDeathViewModel.swift`

### Published State

- `players: [Player]`
  - Shuffled at init for fair start order.
- `currentPlayerIndex: Int`
- `currentThrow: [ScoredThrow]`
- `selectedDartIndex: Int?`
- `winner: Player?`
- `isGameOver: Bool`

#### Lives

- `playerLives: [UUID: Int]`
  - True game state: how many lives each player actually has.
- `displayPlayerLives: [UUID: Int]`
  - What the UI shows for hearts.
  - Updated only at the start of a new round so hearts change in sync with the round number.

#### Round State

- `roundScores: [UUID: Int]`
  - Per-round totals (only for players who have thrown this round).
- `roundNumber: Int`

#### Animation-related

- `scoreAnimationPlayerId: UUID?`
  - The player whose round score just changed; drives the score pop animation in the UI.

#### Services

- `authService: AuthService?` for match saving (mirrors other games).

### Computed Properties

- `currentPlayer: Player`
- `currentThrowTotal: Int`
- `isTurnComplete: Bool`
  - True when `currentThrow.count == 3`.
- `activePlayers: [Player]`
  - Players with `playerLives[id] > 0`.
- `eliminatedPlayers: Set<UUID>`
  - Players with `playerLives[id] == 0`.
- `playersInDanger: Set<UUID>`
  - IDs of players currently at the lowest *saved* score for this round.
  - Implementation:
    - Look at `roundScores` only (no in-progress throws).
    - Find `min(roundScores.values)`.
    - Return all players whose score equals that minimum.
  - This means:
    - Skull moves only after Save Score is tapped.
    - Skull can highlight losers during the end-of-round pause.

### Turn Flow

#### recordThrow(_ scoredThrow: ScoredThrow)

- Replaces the selected dart (if any) or appends a new one (max 3 darts).
- Plays miss/score sounds via `SoundManager`.

#### completeTurn()

- Commits the current throw to the round:
  - `roundScores[currentPlayer.id] = currentThrowTotal`.
- Triggers score pop animation:
  - Sets `scoreAnimationPlayerId = currentPlayer.id`.
  - Resets it after ~0.25s to let the UI animation complete.
- If there is another active player who hasnt thrown this round:
  - Advances `currentPlayerIndex` to the next active player and clears the current throw.
- If all active players have thrown:
  - Calls `endRound()`.

#### endRound()

- Uses `roundScores` for the current round to determine losers **among active players**:
  1. Build `activeRoundScores` by filtering `roundScores` to active player IDs.
  2. Find `minScore` among those values.
  3. `losers` = all player IDs in `activeRoundScores` that equal `minScore`.
- Decrements lives in **game state only**:
  - For each loser, `playerLives[id] = max(0, currentLives - 1)`.
- If only one active player remains after life deduction:
  - Sets `winner` and `isGameOver`.
  - Plays game win sound.
  - Saves match result (local storage + Supabase), similar to other games.
- If the match continues:
  - Starts a **1.5 second pause** using `Task.sleep`.
  - After the pause, on the main actor:
    - `roundNumber += 1`.
    - `roundScores.removeAll()`.
    - `clearThrow()`.
    - Syncs UI hearts with new lives: `displayPlayerLives = playerLives`.
    - Resets `currentPlayerIndex` to the first active player.

#### restartGame()

- Resets lives and display lives:
  - `playerLives[id] = startingLives`
  - `displayPlayerLives[id] = startingLives`
- Clears round state and winner state.
- Resets to round 1 and first active player.

---

## Gameplay View: SuddenDeathGameplayView

File: `Views/Games/SuddenDeath/SuddenDeathGameplayView.swift`

### Layout

- Background: `Color("BackgroundPrimary")`, full-screen.
- **Top**: Player card row.
- **Middle**: `CurrentThrowDisplay` (reused from 301/Knockout).
- **Bottom**: `ScoringButtonGrid` plus a large `Save Score` button using the shared `popAnimation` modifier.

### Navigation Title

- Title: `"\(game.title) - R\(viewModel.roundNumber)"`.
- Display mode: `.inline`.
- Toolbars and behavior match other games (menu button, exit confirmation, hidden tab bar, etc.).

### Player Cards Row

- Logic:
  - If `roundScores` is **empty** (start of a round):
    - `playersToShow = viewModel.activePlayers` (eliminated players removed).
  - If `roundScores` is **non-empty** (during or immediately after a round):
    - `playersToShow = viewModel.players` (everyone visible so you can see who lost).
- Spacing:
  - `<= 3` players: spacing = `32`.
  - `>= 4` players: spacing = `-8` (cards overlap slightly).
- Each card binds to:
  - `roundScore: viewModel.roundScores[player.id]`
  - `lives: viewModel.displayPlayerLives[player.id] ?? 0`
  - `startingLives: viewModel.startingLives`
  - `isEliminated: viewModel.eliminatedPlayers.contains(player.id)`
  - `isInDanger: viewModel.playersInDanger.contains(player.id)`
  - `isCurrentPlayer: player.id == viewModel.currentPlayer.id`
  - `showScoreAnimation: viewModel.scoreAnimationPlayerId == player.id`

### SuddenDeathPlayerCard

- **Skull indicator**
  - Fixed-height container above the avatar.
  - Shows custom `"skull"` image when `isInDanger` is true.
  - Prevents layout jumps when skull appears/disappears.

- **Avatar & current player highlight**
  - For the current player:
    - Outer ring: `Circle().stroke(Color("AccentSecondary"), lineWidth: 2).frame(width: 64, height: 64)`.
    - Inner ring: `Circle().stroke(Color.black, lineWidth: 2).frame(width: 60, height: 60)`.
    - Avatar image: 56pt inside the inner ring.
  - For others:
    - Plain 64pt avatar.

- **Name**
  - First name only (derived from `displayName`).
  - `subheadline`, semibold, `TextPrimary` color.
  - `lineLimit(1)` and `truncationMode(.tail)`.
  - `frame(maxWidth: 56)` to match the design.

- **Round score**
  - Shows `"-"` until the player has thrown this round.
  - Monospaced `title3`, bold, `TextPrimary` color.
  - Score pop animation reused from 301:
    - `scaleEffect(showScoreAnimation ? 1.35 : 1.0)`.
    - `.animation(.spring(response: 0.2, dampingFraction: 0.4), value: showScoreAnimation)`.
    - Medium haptic on transition to `true`.

- **Lives**
  - Only shown if `startingLives > 1` (hidden in 1-life Classic mode).
  - SF Symbol `heart.fill` + `lives` value from `displayPlayerLives`.

---

## Round Timing & UX

### Skull & Save Score

- The skull is driven by `playersInDanger`, which only considers **saved** round scores.
- It updates when the current player taps **Save Score**, not while darts are being entered.
- This makes the skull movement feel discrete and tied to the Save action.

### End-of-round Pause

- After the last active player saves their score for a round:
  - `endRound()` determines who lost a life.
  - Lives are updated in `playerLives`, but **not yet** in `displayPlayerLives`.
  - The UI shows:
    - Round scores for all players.
    - Skull on the lowest scorer(s).
    - Hearts still showing the old life counts.
- A 1.5 second pause gives time to see who lost.
- When the pause ends and the next round starts:
  - The navigation title updates to the next round (e.g., `R2`).
  - `displayPlayerLives` syncs to `playerLives` so hearts change in that moment.
  - Players with 0 lives are no longer included in `activePlayers` and drop out of the row.

This sequencing ensures:

1. **Clarity:** You can clearly see who lost (skull + score) before anything changes.
2. **Consistency:** Hearts and round number update at the same visual moment.
3. **Clean removal:** Eliminated players disappear at the start of the next round, not mid-round.

---

## Previews

File: `Views/Games/SuddenDeath/SuddenDeathGameplayView.swift`

- Previews are provided for 2, 3, 4, 5, and 6 players.
- All use mock players (`Player.mockGuestX` / `Player.mockConnectedX`).
- All inject `AuthService.mockAuthenticated` into the environment.
- Useful for quickly checking:
  - Layout and spacing for different player counts.
  - Skull placement.
  - Current player ring.

---

## Notes / Future Tweaks

- We intentionally delayed the visual hearts update via `displayPlayerLives` to align with round transitions.
- The 1.5s pause and animation timings can be tuned if gameplay feels too slow or too fast.
- If needed, we could reintroduce a subtle loser animation (e.g., a small scale/opacity pulse) during the pause, now that the timing and state are stable.
