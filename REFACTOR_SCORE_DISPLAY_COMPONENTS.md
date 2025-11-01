# Score Display Components Refactor

## 🎯 Problem
The `MatchPlayerCard` component had complex nested conditionals to handle different game types. As more games are added (Cricket, Knockout, Killer, etc.), this would become unmaintainable.

## ✅ Solution
Created two reusable score display components that encapsulate the display logic for different game scoring systems.

---

## 📦 New Components

### 1. **CountdownScoreDisplay**
**Location:** `Views/Shared/MatchHistory/CountdownScoreDisplay.swift`

**For games where:** Lower score is better, winner always has 0
**Games:** 301, 501

**Display logic:**
- **Winner:** Trophy only (32pt) - no score shown (we know it's 0)
- **Non-winner:** Placement text + remaining points in parentheses
- **Multi-leg:** Shows leg indicators instead of points

---

### 2. **AccumulationScoreDisplay**
**Location:** `Views/Shared/MatchHistory/AccumulationScoreDisplay.swift`

**For games where:** Higher score is better, winner's score is meaningful
**Games:** Halve It, Cricket, Killer (future)

**Display logic:**
- **Winner:** Small trophy (24pt) + final score
- **Non-winner:** Placement text + final score
- **Multi-leg:** Shows leg indicators instead of score

---

## 🔧 Refactored Component

### **MatchPlayerCard**
**Location:** `Views/History/MatchDetailView.swift`

**Before:** 90+ lines with nested `if/else` statements
**After:** 50 lines with clean component composition

**Key changes:**
- Removed all conditional score display logic
- Added `isCountdownGame` computed property (checks for "301" or "501")
- Added `scoreDisplayView` with `@ViewBuilder` that selects the right component
- All score display logic moved to dedicated components

---

## 🚀 Benefits

### 1. **Maintainability**
- No more nested conditionals in `MatchPlayerCard`
- Each score display type has its own file with clear responsibility
- Easy to understand at a glance

### 2. **Scalability**
- Adding new games is simple: just map them to countdown or accumulation
- If a new scoring system is needed (e.g., for Killer), create a 3rd component
- No need to modify existing components

### 3. **Reusability**
- Score display components can be used anywhere in the app
- Consistent behavior across all views (MatchDetailView, HalveItMatchDetailView, MatchSummarySheetView)

### 4. **Testability**
- Each component can be tested independently
- Clear inputs and outputs
- No hidden dependencies

---

## 📋 Game Type Mapping

### Countdown Games (use `CountdownScoreDisplay`)
- ✅ 301
- ✅ 501

### Accumulation Games (use `AccumulationScoreDisplay`)
- ✅ Halve It
- 🔜 Cricket (future)
- 🔜 Killer (future)
- 🔜 Knockout (future)
- 🔜 Sudden Death (future)

---

## 🔄 Migration Path

When adding a new game:

1. **Determine scoring type:**
   - Is lower better? → Countdown
   - Is higher better? → Accumulation
   - Is it unique? → Create new component

2. **Update `isCountdownGame` check:**
   ```swift
   private var isCountdownGame: Bool {
       gameType == "301" || gameType == "501" || gameType == "NewGame"
   }
   ```

3. **Done!** The right component will be used automatically.

---

## 📁 Files Modified

### Created:
- `Views/Shared/MatchHistory/CountdownScoreDisplay.swift`
- `Views/Shared/MatchHistory/AccumulationScoreDisplay.swift`

### Modified:
- `Views/History/MatchDetailView.swift` (MatchPlayerCard refactored)
- All usages already pass `gameType` parameter (no changes needed)

---

## ✨ Result

**Clean, maintainable, scalable code** that's ready for all 7 game modes! 🎯
