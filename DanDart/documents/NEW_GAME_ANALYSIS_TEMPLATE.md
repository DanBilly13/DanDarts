# 🎯 New Game Implementation Template

**Game Name:** _[e.g., Cricket, Killer, Around the Clock]_  
**Date:** _[Date]_  
**Estimated Complexity:** _[Low/Medium/High]_

---

## 📖 1. Game Rules Summary

### Core Mechanics
- **Objective:** _[What's the goal? First to X? Highest score? Eliminate opponents?]_
- **Starting Condition:** _[Score at 0? Score at 501? Empty board?]_
- **Win Condition:** _[How does a player win?]_
- **Scoring System:** _[How are points calculated?]_
- **Turn Structure:** _[3 darts per turn? Different?]_
- **Special Rules:** _[Any unique mechanics?]_

### Player Configuration
- **Min Players:** _[Number]_
- **Max Players:** _[Number]_
- **Teams Supported:** _[Yes/No]_

### Game Variants
- [ ] Single difficulty/mode only
- [ ] Multiple difficulties (Easy/Medium/Hard/Pro)
- [ ] Multiple game modes (e.g., 301/501/701)
- [ ] Configurable options (e.g., legs, rounds, targets)

---

## 🔍 2. Component Reusability Analysis

### ✅ Reusable Components (DON'T CREATE NEW)

| Component | Location | Usage in This Game | Notes |
|-----------|----------|-------------------|-------|
| `ScoringButtonGrid` | `/Views/Components/` | [ ] Yes [ ] No [ ] Modified | Dart input (1-20, Bull, Miss) |
| `CurrentThrowDisplay` | `/Views/Components/` | [ ] Yes [ ] No [ ] Modified | 3-dart display with tap-to-edit |
| `PlayerCard` | `/Views/Components/` | [ ] Yes [ ] No [ ] Modified | Player score/status display |
| `GameEndView` | `/Views/Games/Shared/` | [ ] Yes [ ] No [ ] Modified | Winner celebration |
| `PreGameHypeView` | `/Views/Games/Shared/` | [ ] Yes [ ] No [ ] Modified | Boxing-style countdown |
| `GameInstructionsView` | `/Views/Games/Shared/` | [ ] Yes [ ] No [ ] Modified | Rules modal |
| `PopAnimationModifier` | `/Views/Components/` | [ ] Yes [ ] No [ ] Modified | Button animations |
| `AppButtons` | `/Views/Components/` | [ ] Yes [ ] No [ ] Modified | Primary/Secondary buttons |
| `ScoredThrow` | `/Models/` | [ ] Yes [ ] No [ ] Modified | Dart throw data model |
| `ScoreType` | `/Models/` | [ ] Yes [ ] No [ ] Modified | Single/Double/Triple enum |
| `Player` | `/Models/` | [ ] Yes [ ] No [ ] Modified | Player data model |
| `Game` | `/Models/` | [ ] Yes [ ] No [ ] Modified | Game definition model |

**Reusability Score:** _[X/12 components reused]_ = _[X%]_

---

## 🆕 3. New Components Required

### ViewModels
- [ ] `[GameName]ViewModel.swift` in `/ViewModels/Games/`
  - **Purpose:** _[Describe game logic]_
  - **Key Properties:** _[List @Published properties]_
  - **Key Methods:** _[List main methods]_

### Views
- [ ] `[GameName]GameplayView.swift` in `/Views/Games/[GameName]/`
  - **Purpose:** _[Main gameplay screen]_
  - **Layout:** _[Describe UI structure]_
  
- [ ] `[GameName]SetupView.swift` in `/Views/Games/[GameName]/`
  - **Purpose:** _[Game setup/configuration]_
  - **Options:** _[List configuration options]_

### Game-Specific Components
- [ ] `[ComponentName].swift` in `/Views/Games/[GameName]/`
  - **Purpose:** _[Describe unique UI element]_
  - **Reusable?** _[Could other games use this?]_

### Models (if needed)
- [ ] `[ModelName].swift` in `/Models/`
  - **Purpose:** _[Describe data structure]_
  - **Properties:** _[List key properties]_

---

## 🎨 4. UI/UX Design

### Screen Layout
```
┌─────────────────────────────┐
│     Navigation Bar          │
├─────────────────────────────┤
│                             │
│   [Describe layout here]    │
│                             │
│   - Component 1             │
│   - Component 2             │
│   - Component 3             │
│                             │
├─────────────────────────────┤
│   Action Buttons            │
└─────────────────────────────┘
```

### Key Interactions
1. _[User action 1]_ → _[System response]_
2. _[User action 2]_ → _[System response]_
3. _[User action 3]_ → _[System response]_

### Animations/Feedback
- [ ] Haptic feedback on _[action]_
- [ ] Sound effects for _[event]_
- [ ] Visual animation for _[state change]_

---

## 📊 5. Data Flow

### State Management
```
User Input → ViewModel → Update State → UI Refresh
```

**Key State Variables:**
- `currentPlayer: Player`
- `[gameSpecificState]: Type`
- `isGameOver: Bool`
- `winner: Player?`

### Turn Flow
1. _[Step 1: e.g., Player throws 3 darts]_
2. _[Step 2: e.g., Calculate score]_
3. _[Step 3: e.g., Update game state]_
4. _[Step 4: e.g., Check win condition]_
5. _[Step 5: e.g., Next player or end game]_

---

## 🔄 6. Comparison with Existing Games

### Similar to Countdown (301/501)?
- [ ] Yes - Countdown scoring (score down to 0)
- [ ] No - Different scoring system

**If Yes, can we extend `CountdownViewModel`?** _[Yes/No/Partially]_

### Similar to Halve-It?
- [ ] Yes - Accumulation scoring (score up)
- [ ] Yes - Target-based gameplay
- [ ] No - Different mechanics

**If Yes, can we reuse patterns?** _[Yes/No/Partially]_

### Unique Mechanics
_[List what makes this game different from existing games]_

---

## ⚠️ 7. Potential Challenges

### Technical Challenges
- [ ] _[Challenge 1]_
  - **Solution:** _[Proposed approach]_
- [ ] _[Challenge 2]_
  - **Solution:** _[Proposed approach]_

### UX Challenges
- [ ] _[Challenge 1]_
  - **Solution:** _[Proposed approach]_

---

## 📝 8. Implementation Plan

### Phase 1: Data Models & ViewModel (Day 1)
- [ ] Create `[GameName]ViewModel.swift`
- [ ] Create any game-specific models
- [ ] Implement core game logic
- [ ] Write unit tests (if applicable)

### Phase 2: Setup View (Day 1-2)
- [ ] Create `[GameName]SetupView.swift`
- [ ] Implement player selection (reuse existing)
- [ ] Add game-specific configuration options
- [ ] Wire up navigation

### Phase 3: Gameplay View (Day 2-3)
- [ ] Create `[GameName]GameplayView.swift`
- [ ] Integrate reusable components
- [ ] Create game-specific UI components
- [ ] Implement game flow logic

### Phase 4: Polish & Testing (Day 3-4)
- [ ] Add animations and haptic feedback
- [ ] Test all game scenarios
- [ ] Add sound effects
- [ ] Update game instructions
- [ ] Test with multiple players

### Phase 5: Integration (Day 4)
- [ ] Update `MainTabView` navigation
- [ ] Add game to `games.json`
- [ ] Update `Game.swift` model if needed
- [ ] Test full flow from games list

---

## ✅ 9. Pre-Implementation Checklist

Before writing any code:
- [ ] Reviewed all existing components in `/Views/Components/`
- [ ] Reviewed all shared game components in `/Views/Games/Shared/`
- [ ] Identified at least 50% component reuse
- [ ] Documented all new components needed
- [ ] Created UI mockup or sketch
- [ ] Defined all game state variables
- [ ] Mapped out complete turn flow
- [ ] Identified potential code duplication risks

---

## 📈 10. Success Metrics

### Code Reuse
- **Target:** ≥60% component reuse
- **Actual:** _[Fill in after implementation]_

### Development Time
- **Estimated:** _[X days]_
- **Actual:** _[Fill in after implementation]_

### Code Quality
- [ ] No duplicated code from other games
- [ ] All shared components extracted
- [ ] Consistent naming conventions
- [ ] Proper folder structure

---

## 🎯 11. Post-Implementation Review

_[Fill in after completing the game]_

### What Went Well
- _[Success 1]_
- _[Success 2]_

### What Could Be Improved
- _[Improvement 1]_
- _[Improvement 2]_

### Components That Should Be Extracted
- [ ] _[Component 1]_ - Used in _[X games]_
- [ ] _[Component 2]_ - Could be reused in _[future game]_

### Lessons Learned
- _[Lesson 1]_
- _[Lesson 2]_

---

## 📚 12. References

### Similar Games
- _[Game 1]_ - _[What patterns can we reuse?]_
- _[Game 2]_ - _[What patterns can we reuse?]_

### External Resources
- _[Rules reference]_
- _[Design inspiration]_

---

**Template Version:** 1.0  
**Last Updated:** Oct 30, 2025  
**Created By:** DanDarts Development Team
