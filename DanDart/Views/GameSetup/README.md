# Game Setup Architecture

## Overview
This folder contains the generic game setup system that eliminates code duplication across different game types.

## Structure

```
GameSetup/
├── GameSetupView.swift          # Generic setup view (used by all games)
├── GameSetupConfig.swift        # Protocol and base types
└── GameSetupOptions/            # Game-specific configurations
    ├── CountdownSetupConfig.swift     # 301/501 configuration
    ├── HalveItSetupConfig.swift       # Halve-It configuration
    └── SuddenDeathSetupConfig.swift   # Sudden Death configuration
```

## How It Works

### 1. GameSetupView (Generic)
- Single view that handles all game setup UI
- Works for ANY game type
- Uses `GameSetupConfigurable` protocol for game-specific behavior

### 2. GameSetupConfigurable Protocol
Defines what each game needs to provide:
- `game: Game` - The game being configured
- `playerLimit: Int` - Max players (8 or 10)
- `optionLabel: String` - Label for options section ("Match Format", "Difficulty", "Lives")
- `showOptions: Bool` - Whether to show options section
- `optionView(selection:)` - SwiftUI view for game-specific options
- `gameParameters(players:selection:)` - Converts selection to game parameters

### 3. Game-Specific Configs
Each game implements the protocol with its unique options:

**CountdownSetupConfig** (301/501):
- Options: Best of 1, 3, 5, 7 legs
- Player limit: 8

**HalveItSetupConfig**:
- Options: Easy, Medium, Hard difficulty
- Player limit: 8

**SuddenDeathSetupConfig**:
- Options: 1, 3, 5 lives
- Player limit: 10

## Usage

In `MainTabView.swift`:

```swift
.navigationDestination(for: Game.self) { game in
    GameSetupView(config: gameConfig(for: game))
}

private func gameConfig(for game: Game) -> any GameSetupConfigurable {
    switch game.title {
    case "Halve-It":
        return HalveItSetupConfig(game: game)
    case "Sudden Death":
        return SuddenDeathSetupConfig(game: game)
    default:
        return CountdownSetupConfig(game: game)
    }
}
```

## Adding a New Game

To add a new game type, just create a new config file:

1. Create `NewGameSetupConfig.swift` in `GameSetupOptions/`
2. Implement `GameSetupConfigurable` protocol
3. Add case to `gameConfig(for:)` in `MainTabView`

**That's it!** No need to duplicate the entire setup view.

## Benefits

✅ **Single Source of Truth** - One view for all games
✅ **Easy to Maintain** - Fix bugs in one place
✅ **Consistent UX** - All games have identical setup flow
✅ **Easy to Extend** - New games = just add a config
✅ **Less Code** - ~1500 lines reduced to ~500 lines

## Migration Notes

The old game-specific setup views are still in their original locations but are no longer used:
- `Views/Games/Countdown/CountdownSetupView.swift` (deprecated)
- `Views/Games/HalveIt/HalveItSetupView.swift` (deprecated)
- `Views/Games/SuddenDeath/SuddenDeathSetupView.swift` (deprecated)

These can be deleted once the new system is verified to work correctly.
