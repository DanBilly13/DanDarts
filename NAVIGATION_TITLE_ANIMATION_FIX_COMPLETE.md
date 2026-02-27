# Navigation Title Fly-In Animation - FIXED ✅

## Problem
Navigation bar titles were animating in (flying in from the left) when popping from GameSetupView/RemoteGameSetupView back to the main tab view.

## Root Cause
**Known SwiftUI NavigationStack bug** caused by `navigationBarTitleDisplayMode` mismatch:
- Root NavigationStack defaulting to `.large` title mode
- Destination views using `.inline` or hidden navigation bar
- Pop transition triggers title animation glitch/twitching

This is a documented SwiftUI issue when parent and child views have different title display modes.

## Solution
Set consistent `.navigationBarTitleDisplayMode(.inline)` throughout the entire navigation hierarchy.

### Implementation

**File: `/Users/billinghamdaniel/Documents/Windsurf/DanDart/DanDart/Views/MainTabView.swift`**

**1. NavigationStack Root (line 259):**
```swift
NavigationStack(path: $router.path) {
    // ... content ...
}
.navigationBarTitleDisplayMode(.inline)  // ✅ ADDED
.toolbar {
    toolbarContent
}
```

**2. GameSetup Destination Wrapper (lines 553, 559):**
```swift
case .gameSetup(let game):
    let view = GameSetupView(game: game)
    if #available(iOS 18.0, *) {
        view
            .navigationTransition(.zoom(sourceID: game.id, in: gameHeroNamespace))
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)  // ✅ ADDED
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(AppColor.backgroundPrimary)
    } else {
        view
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)  // ✅ ADDED
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(AppColor.backgroundPrimary)
    }
```

**3. RemoteGameSetup Destination Wrapper (lines 570, 576):**
```swift
case .remoteGameSetup(let game, let opponent):
    let view = RemoteGameSetupView(game: game, preselectedOpponent: opponent, selectedTab: $selectedTab)
    if #available(iOS 18.0, *) {
        view
            .navigationTransition(.zoom(sourceID: game.id, in: gameHeroNamespace))
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)  // ✅ ADDED
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(AppColor.backgroundPrimary)
    } else {
        view
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)  // ✅ ADDED
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(AppColor.backgroundPrimary)
    }
```

## Why This Works

**The Bug:**
- SwiftUI's NavigationStack has a known issue with title display mode transitions
- When popping from `.inline` (or hidden) back to `.large` (default), it animates the title
- This animation is part of the mode transition, not the view transition

**The Fix:**
- By setting `.inline` mode consistently on both root and destinations
- We eliminate the mode mismatch
- No mode transition = no title animation
- Title appears instantly without fly-in effect

## Failed Approaches (5 Attempts)

For reference, these approaches did NOT work:

1. **Scoped `.navigationBarHidden(true)`** - UIKit still animates visibility change during pop
2. **Modern `.toolbar(.hidden, for: .navigationBar)`** - SwiftUI still animates state change
3. **Transparent nav bar** (`.toolbarBackground(.hidden)`) - Still has state transitions
4. **Transaction with `disablesAnimations`** - Doesn't fix the underlying mode mismatch
5. **Disabling hero zoom transition** - Not the cause (animation persisted without zoom)

## Key Learnings

✅ **Always set consistent `navigationBarTitleDisplayMode` across navigation hierarchy**
✅ **Mode mismatch (`.large` → `.inline`) triggers SwiftUI animation bugs**
✅ **This is more critical than transaction-based animation disabling**
✅ **Applies to any NavigationStack with custom toolbar titles**

## Additional Changes (Also Implemented)

**File: `/Users/billinghamdaniel/Documents/Windsurf/DanDart/DanDart/Services/Router.swift`**

Updated `pop()` and `pop(count:)` methods to use `Transaction` with `disablesAnimations = true`:

```swift
func pop() {
    guard !path.isEmpty else { return }
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) {
        path.removeLast()
    }
}
```

While this didn't fix the title animation on its own, it's still good practice for controlling NavigationStack animations.

## Result

✅ **Navigation titles now appear instantly without fly-in animation**
✅ **Hero zoom transition preserved**
✅ **Custom toolbar titles work correctly**
✅ **All tabs maintain proper navigation behavior**

## Files Modified

1. **MainTabView.swift** - Added `.navigationBarTitleDisplayMode(.inline)` in 3 places
2. **Router.swift** - Added `Transaction` with `disablesAnimations` to `pop()` methods

## Testing Verified

- ✅ Navigate to GameSetupView from Games tab
- ✅ Custom parallax UI visible with transparent nav bar
- ✅ Navigate back using X button
- ✅ "Games" title appears **instantly without fly-in animation**
- ✅ Repeat for RemoteGameSetupView from Remote tab
- ✅ All tabs maintain titles correctly
- ✅ Hero zoom transition still works beautifully

---

**Implementation Date:** February 27, 2026
**Bug Type:** SwiftUI NavigationStack title display mode mismatch
**Solution:** Consistent `.navigationBarTitleDisplayMode(.inline)` throughout hierarchy
**Status:** ✅ FIXED
