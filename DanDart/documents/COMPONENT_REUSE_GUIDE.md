# 🎯 Component Reuse Quick Reference

**Last Updated:** Oct 30, 2025

---

## 📦 Available Shared Components

### Universal UI Components (`/Views/Components/`)

| Component | Purpose | When to Use | Example |
|-----------|---------|-------------|---------|
| **ScoringButtonGrid** | Dart input (1-20, Bull, Miss, D/T) | Any game with standard dart scoring | All games |
| **CurrentThrowDisplay** | Shows 3 darts with tap-to-edit | Any game tracking individual throws | 301/501, Halve-It |
| **PlayerCard** | Player score/status display | Any game with player scores | All games |
| **AppButtons** | Primary/Secondary styled buttons | Any buttons in the app | All views |
| **PopAnimationModifier** | Button pop-in animation | Buttons that appear conditionally | Save Score buttons |
| **LegIndicators** | Multi-leg match indicators (dots) | Games with best-of-X format | 301/501 multi-leg |
| **AsyncAvatarImage** | Player avatar with loading state | Displaying player avatars | Player cards, profiles |
| **AvatarSelectionView** | Avatar picker modal | Player creation/editing | Setup views |
| **DartTextField** | Custom styled text input | Any text input in game context | Player name entry |
| **GameCard** | Game list card with gradient | Games list display | Games tab |
| **MatchCard** | Match history card | Match history display | History tab |
| **PlayerIdentity** | Player name + avatar compact | Compact player display | Match cards, lists |
| **ProfileHeaderView** | Profile header with stats | Profile screens | Profile tab |
| **StandardSheetView** | Modal sheet wrapper | Any modal presentation | Settings, modals |
| **TopBar** | Navigation top bar | Custom navigation headers | Some views |
| **GameplayMenuButton** | Menu button (•••) for gameplay | All gameplay screens | 301/501, Halve-It, Sudden Death |

---

### Shared Game Components (`/Views/Games/Shared/`)

| Component | Purpose | When to Use | Example |
|-----------|---------|-------------|---------|
| **GameEndView** | Winner celebration screen | Any game with a winner | All games |
| **PreGameHypeView** | Boxing-style countdown (3-2-1) | Before gameplay starts | All games |
| **GameInstructionsView** | Rules modal | Showing game rules | All games |
| **GamesListView** | Games tab list | Main games selection | Games tab |
| **GameView** | Game detail/navigation | Game info before setup | Game detail |

---

### Data Models (`/Models/`)

| Model | Purpose | When to Use | Properties |
|-------|---------|-------------|-----------|
| **ScoredThrow** | Single dart throw | Any game tracking dart throws | `baseValue`, `scoreType`, `totalValue` |
| **ScoreType** | Single/Double/Triple | Any game with multipliers | `.single`, `.double`, `.triple` |
| **Player** | Player data | Any game with players | `id`, `displayName`, `nickname`, `avatarURL` |
| **Game** | Game definition | Adding new game to list | `id`, `title`, `description`, `minPlayers`, `maxPlayers` |
| **MatchResult** | Match history data | Saving match results | `gameType`, `players`, `winner`, `date` |

---

## 🚫 Common Mistakes to Avoid

### ❌ DON'T: Copy-Paste from Existing Game
```swift
// ❌ BAD: Copying CurrentThrowDisplay into new game
struct MyNewGameView: View {
    var body: some View {
        // Copied from CountdownGameplayView
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { index in
                Text(currentThrow[index].displayText)
                // ... 50 lines of duplicated code
            }
        }
    }
}
```

### ✅ DO: Import and Reuse
```swift
// ✅ GOOD: Reusing existing component
import SwiftUI

struct MyNewGameView: View {
    @StateObject private var viewModel: MyGameViewModel
    
    var body: some View {
        VStack {
            // Reuse existing component
            CurrentThrowDisplay(
                currentThrow: viewModel.currentThrow,
                selectedDartIndex: viewModel.selectedDartIndex,
                onDartTapped: { index in
                    viewModel.selectDart(at: index)
                }
            )
        }
    }
}
```

---

## 🎯 Decision Tree: Should I Create a New Component?

```
Is this UI element needed?
    │
    ├─ YES → Does a similar component exist?
    │         │
    │         ├─ YES → Can I reuse it as-is?
    │         │         │
    │         │         ├─ YES → ✅ USE EXISTING COMPONENT
    │         │         │
    │         │         └─ NO → Can I extend it with parameters?
    │         │                   │
    │         │                   ├─ YES → ✅ ADD PARAMETERS TO EXISTING
    │         │                   │
    │         │                   └─ NO → Will other games need this?
    │         │                             │
    │         │                             ├─ YES → ✅ CREATE SHARED COMPONENT
    │         │                             │
    │         │                             └─ NO → ✅ CREATE GAME-SPECIFIC
    │         │
    │         └─ NO → Will other games need this?
    │                   │
    │                   ├─ YES → ✅ CREATE SHARED COMPONENT
    │                   │
    │                   └─ NO → ✅ CREATE GAME-SPECIFIC
    │
    └─ NO → ✅ DON'T CREATE
```

---

## 📋 Pre-Implementation Checklist

Before creating ANY new component:

- [ ] **Search** `/Views/Components/` for similar components
- [ ] **Search** `/Views/Games/Shared/` for game-specific patterns
- [ ] **Ask:** "Will at least 2 games use this?"
  - If YES → Create in `/Views/Components/` or `/Views/Games/Shared/`
  - If NO → Create in `/Views/Games/[GameName]/`
- [ ] **Check** if existing component can be extended with parameters
- [ ] **Document** why you're creating a new component (in code comments)

---

## 🔄 Refactoring Triggers

Extract to shared component when:

1. **Used in 2+ games** → Extract immediately
2. **Copy-pasted code** → Extract before committing
3. **Similar logic in multiple places** → Extract and parameterize
4. **File > 500 lines** → Consider breaking into smaller components

---

## 📊 Component Reuse Scorecard

After implementing a new game, calculate your reuse score:

```
Reuse Score = (Reused Components / Total Components) × 100%

Target: ≥60% reuse
Good: ≥70% reuse
Excellent: ≥80% reuse
```

**Example: Halve-It Game**
- Reused: 9 components (ScoringButtonGrid, CurrentThrowDisplay, PlayerCard, GameEndView, PreGameHypeView, GameInstructionsView, PopAnimationModifier, ScoredThrow, ScoreType)
- Created: 4 components (HalveItViewModel, HalveItGameplayView, HalveItSetupView, TargetProgressView)
- **Score: 9/13 = 69%** ✅ Good!

---

## 🎨 Styling Consistency

### Colors
Always use semantic color names from Assets:
- `Color("AccentPrimary")` - Blue accent (#0A84FF)
- `Color("BackgroundPrimary")` - Dark background (#0A0A0F)
- `Color("SurfacePrimary")` - Card background (#1C1C1E)
- `Color("TextPrimary")` - White text
- `Color("TextSecondary")` - Gray text

### Typography
```swift
.font(.system(size: 18, weight: .semibold, design: .monospaced)) // Scores
.font(.system(size: 16, weight: .medium)) // Labels
.font(.system(size: 14, weight: .regular)) // Secondary text
```

### Spacing
```swift
.padding(.horizontal, 16) // Standard horizontal padding
.padding(.vertical, 8)    // Standard vertical padding
.padding(.top, 12)        // Below navigation bar
```

---

## 🚀 Quick Start: Adding a New Game

### Step 1: Fill Out Template
```bash
cp documents/NEW_GAME_ANALYSIS_TEMPLATE.md documents/[GAME_NAME]_ANALYSIS.md
# Fill out the template completely before coding
```

### Step 2: Create Folder Structure
```bash
mkdir -p DanDart/Views/Games/[GameName]
mkdir -p DanDart/ViewModels/Games  # If not exists
```

### Step 3: Implement in Order
1. **Models** (if needed)
2. **ViewModel** (game logic)
3. **Setup View** (reuse player selection)
4. **Gameplay View** (reuse as much as possible)
5. **Integration** (navigation, game list)

### Step 4: Review & Refactor
- Check for duplicated code
- Extract shared patterns
- Update this guide if new patterns emerge

---

## 📚 Examples

### Example 1: Cricket Game (Hypothetical)

**Reusable:**
- ✅ ScoringButtonGrid (dart input)
- ✅ CurrentThrowDisplay (throw display)
- ✅ PlayerCard (shows marks instead of score)
- ✅ GameEndView (winner screen)
- ✅ PreGameHypeView (countdown)
- ✅ ScoredThrow, ScoreType (models)

**New:**
- 🆕 CricketTargetBoard (15-20 + Bull with marks)
- 🆕 CricketViewModel (cricket scoring logic)
- 🆕 CricketGameplayView (layout)
- 🆕 CricketSetupView (setup)

**Reuse Score: 6/10 = 60%** ✅

---

### Example 2: Around the Clock (Hypothetical)

**Reusable:**
- ✅ ScoringButtonGrid (dart input)
- ✅ CurrentThrowDisplay (throw display)
- ✅ PlayerCard (shows current target)
- ✅ GameEndView (winner screen)
- ✅ PreGameHypeView (countdown)
- ✅ ScoredThrow, ScoreType (models)

**New:**
- 🆕 ClockProgressView (1-20 progression)
- 🆕 ClockViewModel (sequential target logic)
- 🆕 ClockGameplayView (layout)
- 🆕 ClockSetupView (setup)

**Reuse Score: 6/10 = 60%** ✅

---

## 💡 Pro Tips

1. **Start with the template** - Don't skip the analysis phase
2. **Reuse > Customize > Create** - Always prefer reusing existing components
3. **Extract early** - Don't wait until you have 3 games to extract
4. **Document decisions** - Comment why you created a new component
5. **Review regularly** - Update this guide as patterns emerge

---

**Remember:** The goal is not 100% reuse (that's impossible), but **thoughtful reuse** that saves time and maintains consistency! 🎯
