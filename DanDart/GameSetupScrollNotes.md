# GameSetupView Scroll Animation – Current Status & Issues

_Last updated: after commit `67c66b3` rollback of `GameSetupView.swift`_

## Goal

Add a sticky hero header with parallax + fade to `GameSetupView`:

- Hero cover image + large title at the top.
- Content (options, players, instructions) scrolls **under** the hero.
- As you scroll:
  - Hero fades to black.
  - Compact title fades into a sticky top bar, matching gameplay views.

All of this must preserve the existing flow:

- Add players → Done → players visible in setup → Start game with same players.

---

## Scroll Tracking Approaches

### 1. PreferenceKey / GeometryReader (abandoned)

Initial attempts used a `PreferenceKey` + `GeometryReader` to track scroll offset inside a SwiftUI `ScrollView`.

Patterns tried:

- Measuring in `.global` and named coordinate spaces.
- Zero-height and 1-pt-tall `GeometryReader` at top of content.

**Issues:**

- `scrollOffset` stayed at `0` in `GameSetupView`.
- Debug overlays never updated.
- Layout/safe-area interactions made the readings unreliable.

**Conclusion:** This pattern was too flaky in this view and is no longer used for `GameSetupView`.

### 2. `TrackingScrollView` (working in isolation)

Implemented `TrackingScrollView` as a reusable UIKit-backed scroll view:

- Wraps `UIScrollView` + `UIHostingController`.
- Exposes vertical `contentOffset.y` via a `@Binding` (`offset`).
- Uses `scrollViewDidScroll(_:)` in a coordinator.
- Sets `contentInsetAdjustmentBehavior = .never` so content is flush with the top.

This component lives in:

- `Utilities/TrackingScrollView.swift`

#### `ScrollOffsetTestView`

`ScrollOffsetTestView` demonstrates the desired behaviour:

- Fixed header (`headerHeight`) pinned at the top inside a `ZStack`.
- `TrackingScrollView(offset: $offset)` below it.
- Scroll content starts with:

  ```swift
  .padding(.top, headerHeight + 16)
  ```

- `collapseProgress = clamp(offset / headerHeight)` drives:
  - A black overlay on the header to fade it out.
  - Debug overlay with `offset` and `collapse`.

**Result:**

- Offset changes smoothly as you scroll.
- Header stays fixed; content scrolls under it.
- Fade-to-black and debug overlays behave correctly.

This view is the **reference implementation** for the animation pattern.

---

## Problems Integrating Into `GameSetupView`

When we ported the `ScrollOffsetTestView` pattern to `GameSetupView`:

1. **Good:**
   - `scrollOffset` updated correctly using `TrackingScrollView`.
   - Hero header faded and parallaxed as intended.
   - Sticky top bar + compact title fade worked.

2. **Bad:** Player list in the setup screen stopped updating after dismissing `SearchPlayerSheet`.

### Observed behaviour

- Inside `SearchPlayerSheet`, selection behaved correctly:

  - The summary label updated (`"N of 10 players added"`).
  - The binding back to `GameSetupView` fired logs like:

    ```text
    [GameSetupView] selectedPlayers changed, count = 4
    ```

- After tapping **Done** and returning to `GameSetupView`:

  - No additional `onAppear` or `selectedPlayers changed` logs.
  - A debug label added to the body showed:

    ```text
    DEBUG players: 0
    ```

  - No players were visible in the setup UI (no list, no "Players" header).

- However, starting a game still used the correct players.

### Interpretation

This strongly suggests a **view identity / lifecycle** issue rather than a binding problem:

- `SearchPlayerSheet` mutates the `@Binding selectedPlayers` correctly on the instance of `GameSetupView` that presented the sheet.
- After the sheet dismisses, SwiftUI (and/or the routing layer) is rendering a **new instance** of `GameSetupView` whose `@State selectedPlayers` has reset to `[]`.
- The navigation to the gameplay screen still uses the original instance with the correct players, which is why games start with the right participants.

Changing from a SwiftUI `ScrollView` to the UIKit-backed `TrackingScrollView` (even **without** moving the hero header) was enough to re-trigger this behaviour.

**Conclusion:** In the current navigation/router setup, `GameSetupView` is sensitive to structural changes around its scroll view; replacing the scroll container appears to change the view’s identity in a way that causes SwiftUI to recreate it and lose its local `@State`.

---

## Current Safe Baseline

Because of the above, we reverted `GameSetupView.swift` to the last known-good commit (`67c66b3`):

- Uses a plain SwiftUI `ScrollView`.
- Original hero image + title as part of the scroll content (no parallax yet).
- Player selection section uses a `List` with fixed height inside the scroll view.
- Bottom action bar via `safeAreaInset(edge: .bottom)` with Add/Start buttons.

With this version:

- **Add players → Done → players visible in Game Setup** (works).
- **Start game** uses the selected players (works).
- No `scrollOffset`/collapse logic is active on this screen.

We deliberately kept:

- `TrackingScrollView.swift` (utility).
- `ScrollOffsetTestView.swift` (working demo).

So the project is stable, and the scroll tooling exists for future use.

---

## Plan for a Future, Safe Integration

To reintroduce the scroll animation without breaking selection, the likely safe approach is:

1. **Extract state into an `ObservableObject`:**
   - Create `GameSetupState: ObservableObject` that owns:
     - `@Published var selectedPlayers: [Player]`
     - `@Published var selectedOption: Int`
   - Provide it via `@StateObject` in the parent or router, and inject it into `GameSetupView` + `SearchPlayerSheet` as `@ObservedObject`.
   - This makes the player state independent of `GameSetupView`’s struct identity.

2. **Re-apply `TrackingScrollView` in small steps:**
   - First, just wrap the existing content in `TrackingScrollView(offset:)` and verify selection still works (state now lives in the object).
   - Then move the hero header into a fixed layer and pad the scroll content (`.padding(.top, heroHeight + spacing)`) as in `ScrollOffsetTestView`.
   - Finally, wire up `collapseProgress` for fade/parallax and the sticky top bar.

3. **Keep testing after each step**:
   - Always re-check: Add players → Done → players visible → Start game.

Until that refactor is done, `GameSetupView` should stay on the safe baseline version from commit `67c66b3`.
