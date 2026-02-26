# Navigation Architecture Verification Report

**Date:** Feb 26, 2026  
**Phase:** Remote Matches V2 - Navigation Stabilization

---

## ✅ PASSED CHECKS

### 1A. Single NavigationStack with router.path
**Status:** ✅ PASS  
**Result:** Exactly 1 instance found

```swift
// MainTabView.swift:34
NavigationStack(path: $router.path) {
```

### 1B. Single Router.shared Owner
**Status:** ✅ PASS  
**Result:** Exactly 1 instance found

```swift
// MainTabView.swift:24
@StateObject private var router = Router.shared
```

### 2. Environment Objects on NavigationStack
**Status:** ✅ PASS  
**Location:** MainTabView.swift:130-133

```swift
.environmentObject(router)
.environmentObject(authService)
.environmentObject(friendsService)
.environmentObject(remoteMatchService)
```

**Result:** All environment objects correctly applied at NavigationStack level, ensuring both tab content and navigation destinations inherit them.

---

## ⚠️ CRITICAL ISSUES FOUND

### Issue 1: Nested NavigationStacks in Tab Views

**Problem:** Three views create their own `NavigationStack` instances while already being inside the global `NavigationStack(path: $router.path)` from MainTabView.

**Affected Files:**

1. **`FriendsListView.swift:251`**
   ```swift
   var body: some View {
       NavigationStack {  // ❌ NESTED - Already inside MainTabView's NavigationStack
           listContent
           .navigationTitle("Friends")
           // ...
       }
   }
   ```

2. **`MatchHistoryView.swift:128`**
   ```swift
   private var navigationStackView: some View {
       NavigationStack {  // ❌ NESTED - Already inside MainTabView's NavigationStack
           mainContentZStack
           .navigationTitle("History")
           // ...
       }
   }
   ```

3. **`BlockedUsersView.swift:22`**
   ```swift
   var body: some View {
       NavigationStack {  // ❌ NESTED - Already inside MainTabView's NavigationStack
           ZStack {
               // ...
           }
       }
   }
   ```

**Why This Is Critical:**
- Creates nested navigation contexts
- Can cause duplicate view instances
- Back button behavior becomes unpredictable
- Tab switching while navigated can cause crashes
- Router.path changes may not propagate correctly

**Required Fix:**
Remove the `NavigationStack` wrappers from these three views. They should only contain their content, as the navigation container is already provided by MainTabView.

---

## 🔲 PENDING CHECKS (RemoteGameplay Not Yet Implemented)

### 3. Duplicate View/ViewModel Init Test

**Status:** ⏸️ DEFERRED  
**Reason:** `RemoteGameplayView` and `RemoteGameplayViewModel` do not exist yet

**Current State:**
- Only `RemoteGameplayPlaceholderView` exists
- Router uses placeholder for `.remoteGameplay` destination
- No ViewModel to test

**Action Required When Implemented:**
Add logging to both files:

```swift
// RemoteGameplayView.swift
init(...) {
    print("🟢 [RemoteGameplayView] INIT")
}

// RemoteGameplayViewModel.swift
init(...) {
    print("🟢 [RemoteGameplayViewModel] INIT")
}

deinit {
    print("🔴 [RemoteGameplayViewModel] DEINIT")
}
```

**Expected Behavior:**
- Exactly ONE `🟢 [RemoteGameplayView] INIT`
- Exactly ONE `🟢 [RemoteGameplayViewModel] INIT`
- Exactly ONE `🔴 [RemoteGameplayViewModel] DEINIT` when leaving gameplay

---

## 📋 MANUAL TESTING CHECKLIST

### 4. Hero Zoom Animation Test (iOS 18+)

**Test Cases:**
- [ ] Tap Local 301 card → GameSetupView (smooth zoom)
- [ ] Tap Local 501 card → GameSetupView (smooth zoom)
- [ ] Tap Remote 301 card → RemoteGameSetupView (smooth zoom)
- [ ] Tap Remote 501 card → RemoteGameSetupView (smooth zoom)

**Expected:**
- ✅ Smooth hero zoom (card expands into destination)
- ✅ No "nil view" zoom warnings in console
- ✅ No flicker/jump

**Current Implementation:**
```swift
// MainTabView.swift:402-437 - destinationView(for:)
case .gameSetup(let game):
    let view = GameSetupView(game: game)
    if #available(iOS 18.0, *) {
        view.navigationTransition(.zoom(sourceID: game.id, in: gameHeroNamespace))
    }

case .remoteGameSetup(let game, let opponent):
    let view = RemoteGameSetupView(game: game, preselectedOpponent: opponent, selectedTab: $selectedTab)
    if #available(iOS 18.0, *) {
        view.navigationTransition(.zoom(sourceID: game.id, in: gameHeroNamespace))
    }
```

**Source Modifiers:**
```swift
// GamesTabView - GameCard and GameCardRemote
.modifier(GameHeroSourceModifier(game: game, namespace: gameHeroNamespace))
```

---

### 5. Back Navigation + Tab Switching Test

**Test Cases:**
- [ ] Push GameSetupView, pop back (repeat 2x)
- [ ] Push GameSetupView, switch to Friends tab, return to Games tab
- [ ] Push GameSetupView, switch to Remote tab, return to Games tab
- [ ] Push RemoteGameSetupView, pop back (repeat 2x)
- [ ] While on GameSetupView, switch tabs and return

**Expected:**
- ✅ No crashes
- ✅ Back button works consistently
- ✅ Stack behaves predictably
- ✅ No phantom destinations
- ✅ Correct view displayed after tab switch

**Known Risk:**
The nested NavigationStacks in FriendsListView, MatchHistoryView, and BlockedUsersView may cause issues when switching tabs while navigated.

---

### 6. Realtime Subscription Sanity Check

**Status:** ⏸️ DEFERRED (after navigation stable + RemoteGameplay implemented)

**Test:**
Search console logs for "SUBSCRIBING TO MATCH" during gameplay

**Expected:**
- ✅ One subscription per matchId
- ⚠️ Multiple subscriptions = duplicate ViewModels

---

## 🚨 IMMEDIATE ACTION REQUIRED

### Priority 1: Fix Nested NavigationStacks

**Files to Modify:**

1. **`FriendsListView.swift`**
   - Remove `NavigationStack` wrapper (line 251)
   - Keep only `listContent` and modifiers

2. **`MatchHistoryView.swift`**
   - Remove `NavigationStack` wrapper (line 128)
   - Keep only `mainContentZStack` and modifiers

3. **`BlockedUsersView.swift`**
   - Remove `NavigationStack` wrapper (line 22)
   - Keep only `ZStack` content and modifiers

**Why This Must Be Fixed:**
These nested stacks violate the "exactly one NavigationStack(path: $router.path)" rule and can cause the same duplicate ViewModel issues we're trying to prevent.

---

## 📊 VERIFICATION SUMMARY

| Check | Status | Result |
|-------|--------|--------|
| 1A. Single NavigationStack(path: $router.path) | ✅ PASS | 1 found in MainTabView |
| 1B. Single @StateObject router = Router.shared | ✅ PASS | 1 found in MainTabView |
| 2. Environment objects on NavigationStack | ✅ PASS | All 4 objects applied |
| **Nested NavigationStacks** | ❌ **FAIL** | **3 nested stacks found** |
| 3. RemoteGameplay init/deinit logging | ⏸️ DEFERRED | Not yet implemented |
| 4. Hero zoom animation | 🧪 MANUAL TEST | Implementation ready |
| 5. Back navigation + tab switching | 🧪 MANUAL TEST | At risk due to nested stacks |
| 6. Realtime subscription check | ⏸️ DEFERRED | After navigation stable |

---

## 🎯 SUCCESS CRITERIA

**Current Status:** ⚠️ BLOCKED by nested NavigationStacks

**To Achieve Success:**
1. ✅ ~~One global NavigationStack(path: $router.path)~~ (achieved)
2. ✅ ~~One owner of Router.shared~~ (achieved)
3. ✅ ~~No destination EnvironmentObject crash~~ (fixed)
4. ❌ **Remove nested NavigationStacks** (REQUIRED)
5. ⏸️ Exactly 1 gameplay View + ViewModel init per push (pending implementation)
6. 🧪 Hero zoom preserved (manual test required)
7. 🧪 Navigation stable (manual test required after fix)

**Next Steps:**
1. Fix nested NavigationStacks in FriendsListView, MatchHistoryView, BlockedUsersView
2. Test hero zoom animations
3. Test back navigation and tab switching
4. Implement RemoteGameplayView + ViewModel with logging
5. Verify single instance behavior
6. Test realtime subscriptions

---

## 📝 NOTES

- Preview NavigationStacks are OK (they're in #Preview blocks)
- CreateChallengeView has its own NavigationStack but it's presented as a sheet, not in the tab hierarchy - this is acceptable
- The three problematic NavigationStacks are in views that are displayed within tabs, creating actual nesting issues
