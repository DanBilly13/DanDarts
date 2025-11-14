# Hero Navigation & Game Card Artwork

## Overview

This document describes how the App Store–style hero transition from the Games tab to the shared `GameSetupView` is implemented, and how game artwork is shared between the games list and setup screens.

- **Platform:** iOS 18+ for hero animation
- **Fallback:** iOS 17 and below use the standard push transition
- **Scope:** Only applies when navigating from the **Games tab**

---

## Key Files

- `Views/MainTabView.swift`
  - `GamesTabView` with `NavigationStack(path:)`
  - `@Namespace private var gameHeroNamespace`
  - `GameHeroSourceModifier` for hero source views
  - `.navigationDestination(for: Route.self)` special-casing `.gameSetup`

- `Views/Components/GameCard.swift`
  - Visual presentation of each game in the Games tab
  - Displays game artwork header + text + Play button
  - Entire card is tappable (calls `onPlayTapped()`)

- `Views/GameSetup/GameSetupView.swift`
  - Shared setup screen for all game types (Countdown, Halve-It, Knockout, etc.)
  - Uses game cover artwork as a hero-style header
  - Custom X close button using `Router.pop()`

- `Models/Game.swift`
  - Game definition loaded from `darts_games.json`
  - Provides `coverImageCandidates` helper for artwork asset naming

---

## How the Hero Transition Works (iOS 18+)

### 1. Hero Source in `GamesTabView`

`GamesTabView` defines a namespace used for hero transitions:

```swift
@Namespace private var gameHeroNamespace
```

Each `GameCard` is marked as a hero source view:

```swift
ForEach(games) { game in
    GameCard(game: game) {
        router.push(.gameSetup(game: game))
    }
    .modifier(GameHeroSourceModifier(game: game,
                                     namespace: gameHeroNamespace))
}
```

The modifier is defined in `MainTabView.swift`:

```swift
private struct GameHeroSourceModifier: ViewModifier {
    let game: Game
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .matchedTransitionSource(id: game.id,
                                         in: namespace)
        } else {
            content
        }
    }
}
```

### 2. Hero Destination in `GamesTabView`

The navigation destination for `.gameSetup` is wrapped in a hero transition:

```swift
.navigationDestination(for: Route.self) { route in
    switch route.destination {
    case .gameSetup(let game):
        let view = GameSetupView(game: game)
        if #available(iOS 18.0, *) {
            view
                .navigationTransition(
                    .zoom(sourceID: game.id,
                          in: gameHeroNamespace)
                )
                .background(Color.black)
        } else {
            view
                .background(Color.black)
        }

    default:
        router.view(for: route)
            .background(Color.black)
    }
}
```

- On **iOS 18+**, tapping a `GameCard` triggers a `.zoom` hero animation into `GameSetupView`.
- On **older iOS versions**, the same route uses the standard push animation.

### 3. Close Behavior in `GameSetupView`

`GameSetupView` hides the navigation bar and uses a custom X close button that pops the Router's path:

```swift
VStack {
    HStack {
        Button(action: {
            router.pop()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(12)
                .background(Color.black.opacity(0.3))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2),
                        radius: 4, x: 0, y: 2)
        }

        Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)

    Spacer()
}
```

`GameSetupView` still uses the Router for forward navigation (e.g. pushing `.preGameHype` when Start Game is tapped).

---

## Artwork Sharing Between Card and Setup

### Game Artwork Candidates

`Game` exposes a list of candidate asset names for cover artwork:

```swift
var coverImageCandidates: [String] {
    let titleKey = title
    return [
        "game-cover/\(titleKey)",
        titleKey,
        titleKey.lowercased()
    ]
}
```

Views can try these names in order and pick the first one that exists.

> **Note:** If we add more complex naming needs (e.g. hyphen vs. space variants like "Halve-It" vs. "Halve It"), extend this list rather than re-implementing lookup logic in each view.

### GameCard Header Artwork

`GameCard` uses the candidates to resolve an image name:

```swift
private var resolvedCoverImageName: String? {
    for candidate in game.coverImageCandidates {
        if UIImage(named: candidate) != nil {
            return candidate
        }
    }
    return nil
}
```

The header uses that image (or a gradient fallback):

```swift
ZStack(alignment: .bottomLeading) {
    Group {
        if let imageName = resolvedCoverImageName {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 140)
                .clipped()
        } else {
            LinearGradient(
                colors: [
                    Color("AccentPrimary").opacity(0.6),
                    Color("AccentPrimary").opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 140)
        }
    }

    VStack(alignment: .leading, spacing: 4) {
        Text(game.title)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)

        Text(game.subtitle)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.85))
            .lineLimit(2)
            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 1)
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 12)
}
```

### GameSetupView Header Artwork

`GameSetupView` currently implements its own lookup based on `config.game.title`. In the future, this should be refactored to also use `coverImageCandidates` so card and setup header always resolve artwork the same way.

---

## UX Notes

- The **entire GameCard** is tappable, not just the Play button:
  - The card uses `.contentShape(Rectangle())` and `.onTapGesture { onPlayTapped() }`.
  - The Play button still calls `onPlayTapped()` for an obvious affordance.
- Hero animation is scoped to the **Games tab** only. Other routes that push `GameSetupView` will use a normal push.
- The hero effect is purely a **presentation detail**; the Router remains the single source of truth for game flow (setup → hype → gameplay → end).

---

## Extending / Modifying

- **To adjust the animation:**
  - Tweak the `.navigationTransition` behavior in `GamesTabView`.
  - Adjust the `GameCard` and `GameSetupView` header layouts so the zoom feels more or less dramatic.

- **To add new games:**
  - Add a cover artwork asset using one of the names in `coverImageCandidates`.
  - Update `darts_games.json` and any relevant setup config.

- **To improve Halve-It / naming robustness:**
  - Extend `coverImageCandidates` to include variants like `"Halve-It"`, `"Halve It"`, `"HalveIt"` (and lowercase versions) so both GameCard and GameSetupView find the same asset regardless of hyphen/space differences.
