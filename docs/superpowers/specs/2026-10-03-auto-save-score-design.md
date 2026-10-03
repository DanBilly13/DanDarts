# Auto-Save Score — Design

**Date:** 2026-10-03
**Status:** Draft for review (iOS first; Android later if it works out)

## Goal

After a visit is complete, the Save Score button fills left to right, like the
Apple TV progress button, and saves the score when it reaches the right edge.
Until then the player can still change the visit. The feature is optional and
off by default.

## Decisions (agreed in discussion)

| Decision | Choice | Why |
|---|---|---|
| Winning throw | **Never auto-saves.** "Game Over" keeps its plain tap button. | A misread final dart ends the match; it is the costliest mistake. |
| Fill duration | **Fixed 2.0 s**, linear. | Long enough to notice a wrong dart, short enough to keep rounds flowing. No duration setting for now. |
| Games | **Local games only:** 301/501, Knockout, Halve-It, Killer, Sudden Death. | Remote saves go over the network to the opponent and have their own turn-lock states; revisit after trying this. |
| Setting | Toggle in **Settings** and in the **in-game menu**, one shared value, **off by default**. | Players can switch it on mid-game without leaving. |
| Tap during fill | Saves immediately. | Same as today's button. |

## Behaviour

- A visit is *complete* when the game says so (see per-game wiring). The button
  is then **armed** and the fill starts from empty.
- **Reaching the right edge** calls the same `saveScore()` a tap calls, so
  sounds, animations and saving are unchanged. A light haptic marks the moment.
- **Any change to the visit cancels the fill:** deleting a dart, replacing a
  dart, adding a dart. The fill resets to empty without animation, and starts
  again once the visit is complete again.
- **Paused / cancelled while:** the scoring grid's multiplier menu is open
  (`MenuCoordinator.activeMenuId != nil`), the scoreboard is expanded, or the app
  is not active (`scenePhase != .active`). It restarts from empty when the
  condition clears and the visit is still complete.
- **Bust** auto-saves like any other visit (label stays "Bust").
- **Winning throw** (Countdown's "Game Over") is never armed.
- Toggling the setting off mid-fill cancels it; toggling it on with a complete
  visit starts a fill.

## Components

### `GameplaySettings` (new, `Services/`)

`ObservableObject`, `static let shared`, with `@Published var autoSaveEnabled:
Bool` persisted to `UserDefaults` in a `didSet` (key `autoSaveEnabled`, default
`false`), exactly how `Services/SoundManager.swift` stores `soundEffectsEnabled`. Both toggles bind to it, so they always agree.

### `AutoSavePolicy` (new, pure)

```swift
enum AutoSavePolicy {
    static let duration: TimeInterval = 2.0
    static func shouldArm(enabled: Bool, visitComplete: Bool, isWinningThrow: Bool,
                          menuOpen: Bool, scoreboardExpanded: Bool, appActive: Bool) -> Bool
}
```

Returns `enabled && visitComplete && !isWinningThrow && !menuOpen &&
!scoreboardExpanded && appActive`. No SwiftUI, no state: unit tested directly.

### `AutoSaveButton` (new, `Views/Components/`)

Wraps `AppButton` and adds the fill. Inputs: `role`, `isArmed: Bool`,
`resetKey: AnyHashable`, `onSave: () -> Void`, and the label.

- **Fill:** a darker overlay clipped to the button's capsule, scaled to
  `progress` from the left. Colour is black at about 25% over the role's own
  colour, so no new colour tokens are needed and it works for any role.
- **Driver:** `.task(id: ArmID(isArmed, resetKey))`. When armed, animate
  `progress` 0→1 linearly over `duration`, then wait for the same time and, if the
  task was not cancelled, call `onSave()` once. The waiting-and-firing part lives
  in a small `AutoSaveTimer` helper (duration injected) so tests can run it with a
  few milliseconds. When the id changes,
  SwiftUI cancels the task; disarmed or changed state sets `progress = 0`
  without animation.
- **Tap:** calls `onSave()` immediately; the task is cancelled when the visit
  resets.
- **Same button, same layout:** it replaces the `AppButton` inside the existing
  `ZStack` (fixed-height container, placeholder, `popAnimation`) in each game.
  The pop-in animation and blur/opacity while a menu is open stay as they are.

### Settings and in-game menu

- `SettingsView.settingsSection`: an Auto-Save `SettingsToggleRow` under Sound
  Effects, bound to `GameplaySettings.shared.autoSaveEnabled`.
- `GameplayMenuButton`: an Auto-Save toggle under Sound Effects, same on/off
  styling (green on / red off). It already observes `SoundManager.shared`; it
  will also observe `GameplaySettings.shared`.

### As built (differences from the first draft)

- The fill is drawn by `AppButton(fillProgress:)` behind the label, not as an overlay
  on top of it, so the text stays crisp.
- Menu pause comes from `MenuCoordinator.shared`, read inside `AutoSaveButton`, so all
  five games pause without each screen passing it. Only the scoreboard flag is passed
  (Countdown and Halve-It).
- A one-shot latch (`hasFired`) stops a visit that a view model clears late (Knockout
  waits about 0.25 s) from saving twice.
- Reduce Motion: the fill is already a linear progress change with no easing, so there
  is no special case.
- `GameplayMenuButton` has `showsAutoSave` (default `false`) so Remote's menu has no
  inert toggle.
- The `?` menu entry is `Auto-Save` with a check (on) or cross (off) icon.

## Per-game wiring

Each screen replaces its Save Score `AppButton` with `AutoSaveButton`.

| Game | View | Visit complete | `resetKey` from | Winning throw |
|---|---|---|---|---|
| 301/501 | `CountdownGameplayView` | `isTurnComplete` | `currentThrow` | `isWinningThrow` (excluded) |
| Knockout | `KnockoutGameplayView` | `isTurnComplete` (3 darts) | `currentThrow` | none today |
| Halve-It | `HalveItGameplayView` | `isTurnComplete` | `currentThrow` | none today |
| Killer | `KillerGameplayView` | `canSave` (3 darts, or eliminated early) | `currentThrow` | none today |
| Sudden Death | `SuddenDeathGameplayView` | `isTurnComplete` | `currentThrow` | none today |

`resetKey` is a hash of the current darts, so replacing a dart (which keeps the
visit "complete") still restarts the fill. Remote (`RemoteGameplayView`) is not
changed.

## Known limits and open items

1. **Only Countdown can tell a winning throw.** The other four games have no
   "Game Over" state on the button, so a visit that ends the game (last life lost,
   last survivor) auto-saves like any other. Decide in review whether that is
   acceptable or whether those view models should expose "this visit ends the
   game". Not assumed here.
2. **The nav-bar `?` menu cannot be observed.** SwiftUI's `Menu` has no
   "is presented" signal, so a fill that completes while that menu is open will
   save behind it. Only the multiplier menu (via `MenuCoordinator`) pauses the
   fill. Check in the plan whether this is noticeable and, if so, find a way to
   pause (e.g. delay arming briefly after the menu is tapped).
3. **Accessibility.** With VoiceOver on, auto-save would act before the user can
   review the announced score. Proposed: do not arm when
   `UIAccessibility.isVoiceOverRunning`; with Reduce Motion, keep the timing but
   replace the sweep with a plain progress change (no easing).

## Testing

- `AutoSavePolicyTests`: arms only when every condition holds; each single
  failing condition (disabled, incomplete, winning throw, menu open, scoreboard
  expanded, inactive) prevents arming.
- `GameplaySettingsTests`: defaults to off, persists, and two readers see the
  same value.
- Timer logic (extracted so it can run with a short duration in tests): fires
  once on completion; does not fire if cancelled or reset first; resets and can
  fire again after a change; tap fires and cancels.
- Manual on the simulator, per game: fill looks right in both red (Save Score)
  and the Bust state; deleting or replacing a dart restarts it; opening the
  multiplier menu pauses it; a winning throw never fills; toggling in the
  in-game menu and in Settings stays in sync.

## Out of scope

- Remote games, Android, a duration setting, a distinct sound or animation for
  auto-save, and any change to how scores are stored.
