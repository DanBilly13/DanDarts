# Auto-Save Score Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After a visit is complete, the Save Score button fills left to right over 2 seconds and saves when full; any change to the visit cancels it. Optional, off by default, local games only, never on a winning throw.

**Architecture:** A pure `AutoSavePolicy` decides when to arm, a tiny `AutoSaveTimer` waits and fires once, and `GameplaySettings` stores the toggle. `AppButton` gains a `fillProgress` so the fill is drawn *behind* the label. A shared `AutoSaveButton` combines these and replaces the Save Score `AppButton` in the five local game screens. Spec: `docs/superpowers/specs/2026-10-03-auto-save-score-design.md`.

**Tech Stack:** SwiftUI (iOS 26 target), Swift Testing (`@Test`, `#expect`), `UserDefaults`, Xcode 26.5, scheme `DanDart`.

---

## Ground rules

- Work on branch `feature/auto-save-score` (already created from `test-flight`, spec committed).
- The working tree has three unrelated uncommitted items: `DanDart.xcodeproj/project.pbxproj`, `supabase/.temp/`, `supabase_migrations/091_pin_save_remote_visit_search_path.sql`. **Never `git add -A` / `git add .`.** Always `git add` the exact paths named in a task.
- New files under `DanDart/` and `DanDartTests/` are picked up automatically (`PBXFileSystemSynchronizedRootGroup`): no `project.pbxproj` edit.
- Test command (substitute the suite name):
  `xcodebuild test -scheme DanDart -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DanDartTests/<Suite> 2>&1 | grep -E "error:|TEST SUCCEEDED|TEST FAILED"`
- Build-only command:
  `xcodebuild build -scheme DanDart -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`

## File structure

| File | Action | Responsibility |
|---|---|---|
| `DanDart/Utilities/AutoSavePolicy.swift` | Create | When to arm (pure) + duration + `[ScoredThrow].autoSaveKey` |
| `DanDart/Utilities/AutoSaveTimer.swift` | Create | Wait, then fire once unless cancelled |
| `DanDart/Services/GameplaySettings.swift` | Create | `autoSaveEnabled`, persisted, injectable `UserDefaults` |
| `DanDart/Views/Components/AppButtons.swift` | Modify | `AppButton(fillProgress:)`: darker fill behind the label |
| `DanDart/Views/Components/AutoSaveButton.swift` | Create | The button: arming, fill animation, one-shot save |
| `DanDart/Views/Profile/SettingsView.swift` | Modify | Auto-Save row under Sound Effects |
| `DanDart/Views/Components/GameplayMenuButton.swift` | Modify | Auto-Save toggle (only when `showsAutoSave`) |
| 5 game views | Modify | Swap the Save Score `AppButton` for `AutoSaveButton`; pass `showsAutoSave: true` |
| `DanDartTests/AutoSavePolicyTests.swift`, `AutoSaveTimerTests.swift`, `GameplaySettingsTests.swift` | Create | Unit tests |
| `docs/superpowers/specs/2026-10-03-auto-save-score-design.md` | Modify | Record deviations (Task 10) |

---

### Task 1: AutoSavePolicy (pure)

**Files:**
- Create: `DanDart/Utilities/AutoSavePolicy.swift`
- Test: `DanDartTests/AutoSavePolicyTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DanDartTests/AutoSavePolicyTests.swift`:

```swift
//
//  AutoSavePolicyTests.swift
//  DanDartTests
//
//  When the Save Score button arms for auto-save, and what counts as "the visit changed".
//

import Foundation
import Testing
@testable import DanDart

struct AutoSavePolicyTests {

    /// Everything favourable by default; each test breaks exactly one condition.
    private func shouldArm(
        enabled: Bool = true,
        visitComplete: Bool = true,
        isWinningThrow: Bool = false,
        menuOpen: Bool = false,
        scoreboardExpanded: Bool = false,
        appActive: Bool = true,
        voiceOverRunning: Bool = false
    ) -> Bool {
        AutoSavePolicy.shouldArm(
            enabled: enabled,
            visitComplete: visitComplete,
            isWinningThrow: isWinningThrow,
            menuOpen: menuOpen,
            scoreboardExpanded: scoreboardExpanded,
            appActive: appActive,
            voiceOverRunning: voiceOverRunning
        )
    }

    @Test func armsWhenEverythingIsFavourable() {
        #expect(shouldArm())
    }

    @Test func doesNotArmWhenTheSettingIsOff() {
        #expect(shouldArm(enabled: false) == false)
    }

    @Test func doesNotArmUntilTheVisitIsComplete() {
        #expect(shouldArm(visitComplete: false) == false)
    }

    @Test func neverArmsOnAWinningThrow() {
        #expect(shouldArm(isWinningThrow: true) == false)
    }

    @Test func doesNotArmWhileAMenuIsOpen() {
        #expect(shouldArm(menuOpen: true) == false)
    }

    @Test func doesNotArmWhileTheScoreboardIsExpanded() {
        #expect(shouldArm(scoreboardExpanded: true) == false)
    }

    @Test func doesNotArmWhenTheAppIsNotActive() {
        #expect(shouldArm(appActive: false) == false)
    }

    @Test func doesNotArmWithVoiceOverRunning() {
        #expect(shouldArm(voiceOverRunning: true) == false)
    }

    @Test func theFillTakesTwoSeconds() {
        #expect(AutoSavePolicy.duration == 2.0)
    }

    // MARK: - autoSaveKey

    private func dart(_ base: Int, _ type: ScoreType = .single) -> ScoredThrow {
        ScoredThrow(baseValue: base, scoreType: type)
    }

    @Test func theKeyIsTheSameForTheSameDarts() {
        #expect([dart(20), dart(19, .triple)].autoSaveKey == [dart(20), dart(19, .triple)].autoSaveKey)
    }

    @Test func replacingADartChangesTheKey() {
        let before = [dart(20), dart(19), dart(18)]
        let after = [dart(20), dart(19), dart(17)]

        #expect(before.autoSaveKey != after.autoSaveKey)
    }

    @Test func changingOnlyTheMultiplierChangesTheKey() {
        #expect([dart(20, .single)].autoSaveKey != [dart(20, .double)].autoSaveKey)
    }

    @Test func removingADartChangesTheKey() {
        #expect([dart(20), dart(19)].autoSaveKey != [dart(20)].autoSaveKey)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme DanDart -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DanDartTests/AutoSavePolicyTests 2>&1 | grep -E "error:|TEST SUCCEEDED|TEST FAILED"`
Expected: `error: cannot find 'AutoSavePolicy' in scope` (compile failure, then `TEST FAILED`).

- [ ] **Step 3: Write minimal implementation**

Create `DanDart/Utilities/AutoSavePolicy.swift`:

```swift
//
//  AutoSavePolicy.swift
//  Dart Freak
//
//  Pure rules for auto-saving a visit. No SwiftUI, no state.
//

import Foundation

enum AutoSavePolicy {
    /// How long the button takes to fill, and so how long the player has to change their mind.
    static let duration: TimeInterval = 2.0

    /// Whether the Save Score button should be counting down to an automatic save.
    /// A winning throw never auto-saves: it ends the match, so it always needs a tap.
    static func shouldArm(
        enabled: Bool,
        visitComplete: Bool,
        isWinningThrow: Bool,
        menuOpen: Bool,
        scoreboardExpanded: Bool,
        appActive: Bool,
        voiceOverRunning: Bool
    ) -> Bool {
        enabled
            && visitComplete
            && !isWinningThrow
            && !menuOpen
            && !scoreboardExpanded
            && appActive
            && !voiceOverRunning
    }
}

extension Array where Element == ScoredThrow {
    /// Changes whenever any dart in the visit changes. Replacing a dart keeps the visit
    /// "complete", so the completeness flag alone would not restart the fill.
    var autoSaveKey: [[Int]] {
        map { [$0.baseValue, $0.scoreType.multiplier] }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the same command. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DanDart/Utilities/AutoSavePolicy.swift DanDartTests/AutoSavePolicyTests.swift
git commit -m "feat(autosave): add AutoSavePolicy"
```

---

### Task 2: AutoSaveTimer

**Files:**
- Create: `DanDart/Utilities/AutoSaveTimer.swift`
- Test: `DanDartTests/AutoSaveTimerTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DanDartTests/AutoSaveTimerTests.swift`:

```swift
//
//  AutoSaveTimerTests.swift
//  DanDartTests
//
//  The wait-then-fire part of auto-save, run with very short durations.
//

import Foundation
import Testing
@testable import DanDart

@MainActor
struct AutoSaveTimerTests {

    private final class Counter { var count = 0 }

    @Test func firesOnceAfterTheDuration() async {
        let counter = Counter()

        await AutoSaveTimer.run(after: 0.02) { counter.count += 1 }

        #expect(counter.count == 1)
    }

    @Test func doesNotFireBeforeTheDuration() async {
        let counter = Counter()
        let task = Task { @MainActor in
            await AutoSaveTimer.run(after: 0.4) { counter.count += 1 }
        }

        try? await Task.sleep(for: .milliseconds(50))
        #expect(counter.count == 0)

        task.cancel()
        await task.value
    }

    @Test func doesNotFireWhenCancelledFirst() async {
        let counter = Counter()
        let task = Task { @MainActor in
            await AutoSaveTimer.run(after: 0.3) { counter.count += 1 }
        }

        task.cancel()
        await task.value

        #expect(counter.count == 0)
    }

    @Test func canFireAgainAfterAnEarlierRunWasCancelled() async {
        let counter = Counter()
        let cancelled = Task { @MainActor in
            await AutoSaveTimer.run(after: 0.3) { counter.count += 1 }
        }
        cancelled.cancel()
        await cancelled.value

        await AutoSaveTimer.run(after: 0.02) { counter.count += 1 }

        #expect(counter.count == 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme DanDart -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DanDartTests/AutoSaveTimerTests 2>&1 | grep -E "error:|TEST SUCCEEDED|TEST FAILED"`
Expected: `error: cannot find 'AutoSaveTimer' in scope`, then `TEST FAILED`.

- [ ] **Step 3: Write minimal implementation**

Create `DanDart/Utilities/AutoSaveTimer.swift`:

```swift
//
//  AutoSaveTimer.swift
//  Dart Freak
//
//  Waits, then fires once, unless the surrounding task is cancelled first.
//

import Foundation

enum AutoSaveTimer {
    /// Suspends for `duration`, then runs `action`. If the task is cancelled while waiting
    /// (the visit changed, the menu opened, ...) `action` never runs.
    @MainActor
    static func run(after duration: TimeInterval, action: @MainActor () -> Void) async {
        do {
            try await Task.sleep(for: .seconds(duration))
        } catch {
            return // cancelled
        }
        guard !Task.isCancelled else { return }
        action()
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the same command. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DanDart/Utilities/AutoSaveTimer.swift DanDartTests/AutoSaveTimerTests.swift
git commit -m "feat(autosave): add AutoSaveTimer"
```

---

### Task 3: GameplaySettings

**Files:**
- Create: `DanDart/Services/GameplaySettings.swift`
- Test: `DanDartTests/GameplaySettingsTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DanDartTests/GameplaySettingsTests.swift`:

```swift
//
//  GameplaySettingsTests.swift
//  DanDartTests
//
//  The Auto-Save toggle: off by default and remembered.
//

import Foundation
import Testing
@testable import DanDart

struct GameplaySettingsTests {

    /// A throwaway store so tests never touch the real app settings.
    private func freshDefaults() -> UserDefaults {
        let name = "GameplaySettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func autoSaveIsOffByDefault() {
        #expect(GameplaySettings(defaults: freshDefaults()).autoSaveEnabled == false)
    }

    @Test func turningAutoSaveOnIsRemembered() {
        let defaults = freshDefaults()
        GameplaySettings(defaults: defaults).autoSaveEnabled = true

        #expect(GameplaySettings(defaults: defaults).autoSaveEnabled)
    }

    @Test func turningAutoSaveBackOffIsRemembered() {
        let defaults = freshDefaults()
        let settings = GameplaySettings(defaults: defaults)
        settings.autoSaveEnabled = true
        settings.autoSaveEnabled = false

        #expect(GameplaySettings(defaults: defaults).autoSaveEnabled == false)
    }

    @Test func theSettingIsStoredUnderAStableKey() {
        let defaults = freshDefaults()
        GameplaySettings(defaults: defaults).autoSaveEnabled = true

        #expect(defaults.bool(forKey: "autoSaveEnabled"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme DanDart -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DanDartTests/GameplaySettingsTests 2>&1 | grep -E "error:|TEST SUCCEEDED|TEST FAILED"`
Expected: `error: cannot find 'GameplaySettings' in scope`, then `TEST FAILED`.

- [ ] **Step 3: Write minimal implementation**

Create `DanDart/Services/GameplaySettings.swift`:

```swift
//
//  GameplaySettings.swift
//  Dart Freak
//
//  In-game preferences. Stored the same way SoundManager stores its toggle.
//

import Foundation

final class GameplaySettings: ObservableObject {
    static let shared = GameplaySettings()

    private static let autoSaveKey = "autoSaveEnabled"

    private let defaults: UserDefaults

    /// Save a complete visit automatically once the Save Score button has filled. Off by default.
    @Published var autoSaveEnabled: Bool {
        didSet { defaults.set(autoSaveEnabled, forKey: Self.autoSaveKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.autoSaveEnabled = defaults.object(forKey: Self.autoSaveKey) as? Bool ?? false
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the same command. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DanDart/Services/GameplaySettings.swift DanDartTests/GameplaySettingsTests.swift
git commit -m "feat(autosave): add GameplaySettings with a persisted Auto-Save toggle"
```

---

### Task 4: `AppButton(fillProgress:)`

The fill must sit *behind* the label so the text stays crisp, so it belongs in the button style's background. Default `0` leaves every existing button unchanged.

**Files:**
- Modify: `DanDart/Views/Components/AppButtons.swift` (struct `AppButton` ~L16-48, `AppButtonStyle` ~L73-124)

- [ ] **Step 1: Add the property and init parameter to `AppButton`**

In `AppButton`, change the stored properties and `init`:

```swift
    let controlSize: ControlSize
    let isDisabled: Bool
    let compact: Bool
    /// 0...1. Draws a darker fill from the left behind the label (auto-save countdown). 0 = none.
    let fillProgress: CGFloat
    @ViewBuilder let label: () -> Label

    init(role: AppButtonRole,
         controlSize: ControlSize = .regular,
         isDisabled: Bool = false,
         compact: Bool = false,
         fillProgress: CGFloat = 0,
         action: @escaping () -> Void,
         @ViewBuilder label: @escaping () -> Label) {
        self.role = role
        self.action = action
        self.controlSize = controlSize
        self.isDisabled = isDisabled
        self.compact = compact
        self.fillProgress = fillProgress
        self.label = label
    }
```

and pass it to the style:

```swift
        .buttonStyle(AppButtonStyle(role: role, controlSize: controlSize, compact: compact, fillProgress: fillProgress))
```

- [ ] **Step 2: Add the property to `AppButtonStyle` and draw the fill**

In `AppButtonStyle`, add after `let compact: Bool`:

```swift
    var fillProgress: CGFloat = 0
```

In `backgroundShape`, replace the `.primary, .secondary, .tertiary` case body's last line `Capsule().fill(bg)` with:

```swift
            Capsule().fill(bg)
                .overlay(alignment: .leading) { progressFill }
```

and add this member to `AppButtonStyle` (next to `strokeOverlay`):

```swift
    /// Always present, zero-width at 0, so animating `fillProgress` sweeps instead of popping in.
    private var progressFill: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.black.opacity(0.25))
                .frame(width: geometry.size.width * min(max(fillProgress, 0), 1))
        }
        .clipShape(Capsule())
        .allowsHitTesting(false)
    }
```

- [ ] **Step 3: Build**

Run the build-only command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add DanDart/Views/Components/AppButtons.swift
git commit -m "feat(autosave): AppButton can draw a progress fill behind its label"
```

---

### Task 5: `AutoSaveButton`

**Files:**
- Create: `DanDart/Views/Components/AutoSaveButton.swift`

- [ ] **Step 1: Write the view**

```swift
//
//  AutoSaveButton.swift
//  Dart Freak
//
//  The Save Score button with an optional auto-save: once a visit is complete the
//  button fills left to right and saves when full. Any change to the visit, opening a
//  menu, expanding the scoreboard or leaving the app cancels the fill. Tapping saves now.
//

import SwiftUI
import UIKit

struct AutoSaveButton<Label: View>: View {
    let role: AppButtonRole
    /// The game's own "this visit can be saved" flag.
    let isVisitComplete: Bool
    /// A winning throw never auto-saves.
    var isWinningThrow: Bool = false
    var scoreboardExpanded: Bool = false
    /// Changes whenever any dart changes (`currentThrow.autoSaveKey`), so replacing a dart restarts the fill.
    let resetKey: [[Int]]
    let onSave: () -> Void
    @ViewBuilder let label: () -> Label

    @ObservedObject private var settings = GameplaySettings.shared
    @ObservedObject private var menuCoordinator = MenuCoordinator.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverRunning

    @State private var progress: CGFloat = 0
    /// Set when the fill completes so a slow-to-clear visit can't save twice.
    @State private var hasFired = false

    private struct ArmID: Hashable {
        let armed: Bool
        let key: [[Int]]
    }

    private var isArmed: Bool {
        !hasFired && AutoSavePolicy.shouldArm(
            enabled: settings.autoSaveEnabled,
            visitComplete: isVisitComplete,
            isWinningThrow: isWinningThrow,
            menuOpen: menuCoordinator.activeMenuId != nil,
            scoreboardExpanded: scoreboardExpanded,
            appActive: scenePhase == .active,
            voiceOverRunning: voiceOverRunning
        )
    }

    var body: some View {
        AppButton(
            role: role,
            controlSize: .extraLarge,
            fillProgress: progress,
            action: onSave,
            label: label
        )
        .task(id: ArmID(armed: isArmed, key: resetKey)) {
            await runFill()
        }
        .onChange(of: isVisitComplete) { _, complete in
            if !complete { hasFired = false }
        }
    }

    @MainActor
    private func runFill() async {
        // Reset to empty without animating the drain.
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { progress = 0 }

        guard isArmed else { return }

        withAnimation(.linear(duration: AutoSavePolicy.duration)) { progress = 1 }
        await AutoSaveTimer.run(after: AutoSavePolicy.duration) {
            hasFired = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSave()
        }
    }
}

#Preview("Auto-save armed") {
    GameplaySettings.shared.autoSaveEnabled = true
    return AutoSaveButton(
        role: .primary,
        isVisitComplete: true,
        resetKey: [[20, 1]],
        onSave: { print("saved") }
    ) {
        Label("Save Score", systemImage: "checkmark.circle.fill")
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
```

- [ ] **Step 2: Build**

Run the build-only command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add DanDart/Views/Components/AutoSaveButton.swift
git commit -m "feat(autosave): add AutoSaveButton"
```

---

### Task 6: Settings row and in-game menu toggle

**Files:**
- Modify: `DanDart/Views/Profile/SettingsView.swift` (~L19-20, ~L221-233)
- Modify: `DanDart/Views/Components/GameplayMenuButton.swift`

- [ ] **Step 1: Settings row**

In `SettingsView`, next to `@StateObject private var soundManager = SoundManager.shared` add:

```swift
    @StateObject private var gameplaySettings = GameplaySettings.shared
```

In `settingsSection`, directly after the first `Divider()...padding(.leading, 44)` that follows the Sound Effects row, and before the Notifications comment, insert:

```swift
                // Auto-Save: fill the Save Score button, then save the visit automatically
                SettingsToggleRow(
                    icon: Image(systemName: "checkmark.circle"),
                    title: "Auto-Save",
                    isOn: $gameplaySettings.autoSaveEnabled
                )
                
                Divider()
                    .background(AppColor.textSecondary.opacity(0.2))
                    .padding(.leading, 44)
                
```

- [ ] **Step 2: In-game menu toggle**

In `GameplayMenuButton`, make the first stored property (so call sites can pass it first):

```swift
struct GameplayMenuButton: View {
    /// Local games turn this on. Remote games leave it off: auto-save is local-only.
    var showsAutoSave: Bool = false
    let onInstructions: () -> Void
```

add next to the sound observer:

```swift
    @ObservedObject private var gameplaySettings = GameplaySettings.shared
```

and directly after the Sound Effects `Button { ... }` block, before the first `Divider()`, insert:

```swift
            if showsAutoSave {
                Button {
                    gameplaySettings.autoSaveEnabled.toggle()
                } label: {
                    Label {
                        Text("Auto-Save")
                    } icon: {
                        Image(systemName: gameplaySettings.autoSaveEnabled ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(gameplaySettings.autoSaveEnabled ? .green : .red)
                    }
                }
            }
```

- [ ] **Step 3: Build**

Run the build-only command. Expected: `** BUILD SUCCEEDED **`. (Remote's `GameplayMenuButton(` call still compiles because `showsAutoSave` defaults to `false`.)

- [ ] **Step 4: Commit**

```bash
git add DanDart/Views/Profile/SettingsView.swift DanDart/Views/Components/GameplayMenuButton.swift
git commit -m "feat(autosave): Auto-Save toggle in Settings and the in-game menu"
```

---

### Task 7: Wire 301/501 (Countdown)

**Files:**
- Modify: `DanDart/Views/Games/Countdown/CountdownGameplayView.swift` (~L163-167, ~L209)

- [ ] **Step 1: Swap the button**

Replace

```swift
                                AppButton(
                                    role: gameViewModel.isWinningThrow ? .secondary : .primary,
                                    controlSize: .extraLarge,
                                    action: { gameViewModel.saveScore() }
                                ) {
```

with

```swift
                                AutoSaveButton(
                                    role: gameViewModel.isWinningThrow ? .secondary : .primary,
                                    isVisitComplete: gameViewModel.isTurnComplete,
                                    isWinningThrow: gameViewModel.isWinningThrow,
                                    scoreboardExpanded: isScoreboardExpanded,
                                    resetKey: gameViewModel.currentThrow.autoSaveKey,
                                    onSave: { gameViewModel.saveScore() }
                                ) {
```

The label closure (Game Over / Bust / Save Score), `.blur`, `.opacity` and `.popAnimation` below it stay as they are.

- [ ] **Step 2: Show the menu toggle**

Change `GameplayMenuButton(` (~L209) to:

```swift
                    GameplayMenuButton(
                        showsAutoSave: true,
```

- [ ] **Step 3: Build**

Run the build-only command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add DanDart/Views/Games/Countdown/CountdownGameplayView.swift
git commit -m "feat(autosave): auto-save in 301/501"
```

---

### Task 8: Wire the other four local games

Each game: swap the `AppButton` for `AutoSaveButton` and pass `showsAutoSave: true` to the menu. Use the Edit tool with the exact strings below (indentation matters).

**Files:**
- Modify: `DanDart/Views/Games/Knockout/KnockoutGameplayView.swift`
- Modify: `DanDart/Views/Games/HalveIt/HalveItGameplayView.swift`
- Modify: `DanDart/Views/Games/Killer/KillerGameplayView.swift`
- Modify: `DanDart/Views/Games/SuddenDeath/SuddenDeathGameplayView.swift`

- [ ] **Step 1: Knockout** (button at 24-space indent)

Replace

```swift
                        AppButton(
                            role: .primary,
                            controlSize: .extraLarge,
                            action: { viewModel.completeTurn() }
                        ) {
```

with

```swift
                        AutoSaveButton(
                            role: .primary,
                            isVisitComplete: viewModel.isTurnComplete,
                            resetKey: viewModel.currentThrow.autoSaveKey,
                            onSave: { viewModel.completeTurn() }
                        ) {
```

and replace `                GameplayMenuButton(\n                    onInstructions: { showInstructions = true },` with `                GameplayMenuButton(\n                    showsAutoSave: true,\n                    onInstructions: { showInstructions = true },`.

- [ ] **Step 2: Halve-It** (button at 28-space indent; also has a scoreboard)

Replace

```swift
                            AppButton(
                                role: .primary,
                                controlSize: .extraLarge,
                                action: { viewModel.completeTurn() }
                            ) {
```

with

```swift
                            AutoSaveButton(
                                role: .primary,
                                isVisitComplete: viewModel.isTurnComplete,
                                scoreboardExpanded: isScoreboardExpanded,
                                resetKey: viewModel.currentThrow.autoSaveKey,
                                onSave: { viewModel.completeTurn() }
                            ) {
```

and add `showsAutoSave: true,` as the first argument of its `GameplayMenuButton(` (~L183, 16-space indent, same pattern as Knockout).

- [ ] **Step 3: Killer** (visit-complete flag is `canSave`)

Replace

```swift
                        AppButton(
                            role: .primary,
                            controlSize: .extraLarge,
                            action: { viewModel.completeTurn() }
                        ) {
```

with

```swift
                        AutoSaveButton(
                            role: .primary,
                            isVisitComplete: viewModel.canSave,
                            resetKey: viewModel.currentThrow.autoSaveKey,
                            onSave: { viewModel.completeTurn() }
                        ) {
```

and add `showsAutoSave: true,` as the first argument of its `GameplayMenuButton(` (~L145).

- [ ] **Step 4: Sudden Death**

Same edit as Knockout (identical 24-space block, `viewModel.isTurnComplete`, `viewModel.completeTurn()`), and add `showsAutoSave: true,` as the first argument of its `GameplayMenuButton(` (~L126).

- [ ] **Step 5: Build**

Run the build-only command. Expected: `** BUILD SUCCEEDED **`. Confirm Remote is untouched: `git diff --stat -- DanDart/Views/Games/Remote` prints nothing.

- [ ] **Step 6: Commit**

```bash
git add DanDart/Views/Games/Knockout/KnockoutGameplayView.swift DanDart/Views/Games/HalveIt/HalveItGameplayView.swift DanDart/Views/Games/Killer/KillerGameplayView.swift DanDart/Views/Games/SuddenDeath/SuddenDeathGameplayView.swift
git commit -m "feat(autosave): auto-save in Knockout, Halve-It, Killer and Sudden Death"
```

---

### Task 9: Run the tests and verify in the simulator

- [ ] **Step 1: Run all new suites together**

Run: `xcodebuild test -scheme DanDart -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DanDartTests/AutoSavePolicyTests -only-testing:DanDartTests/AutoSaveTimerTests -only-testing:DanDartTests/GameplaySettingsTests -only-testing:DanDartTests/MatchSaveRulesTests -only-testing:DanDartTests/ProfileStatsCalculatorTests -only-testing:DanDartTests/TrendYScaleTests -only-testing:DanDartTests/RemoteVisitBustTests 2>&1 | grep -E "error:|TEST SUCCEEDED|TEST FAILED"`
Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: Build and launch on the simulator**

Use the simulator `build` action for scheme `DanDart` (project `/Users/dan/Projects/DanDarts/DanDart.xcodeproj`, device iPhone 17), then `launch`. The user signs in themselves if the session expired.

- [ ] **Step 3: Check each behaviour in a solo 301 (Practice) game**

Practice saves nothing until the match ends and never touches wins or losses. Start 301 with only the signed-in player, then:

1. Open the `?` menu: an **Auto-Save** row sits under Sound Effects. Turn it on. Open **Profile → Settings**: the Auto-Save row shows on (or turn it on there and see the menu agree).
2. Tap `1` three times. The Save Score button appears and a darker fill sweeps left to right behind the label over ~2 s, then the score saves (301 → 298) and the next visit starts. Take screenshots about 0.5 s apart to confirm the sweep.
3. Tap `1` three times, then press delete before 2 s: the fill empties and nothing saves. Tap `1` again to complete the visit: the fill restarts from empty.
4. With three darts in, tap the button before it fills: it saves immediately.
5. With the setting off, three darts leave a plain button that never fills.
6. Bust and winning throw, using the hold-and-drag multiplier menu (long-press a number, drag to Triple/Double, release). From a fresh 301:
   - Visit 1: T20, T20, T20 (180), leaving 121. Let it auto-save.
   - Visit 2: T20, T20, T20 again. 180 is more than 121, so the button reads **Bust**; it also fills and auto-saves, and the score stays 121.
   - Visit 3: T20, T17, D5 (60 + 51 + 10 = 121, finishing on a double). The button reads **Game Over** and **never fills**; it waits for a tap. Quit the game instead of tapping it if you would rather not record a match.
7. With the fill running, open the multiplier menu by long-pressing a number: the fill stops and empties. Release without choosing and the fill restarts from empty once the visit is complete.
8. Repeat step 2 once each in Knockout, Halve-It, Killer and Sudden Death (two players; use a Guest for the second). Quitting a game before it ends records nothing.
9. Open a Remote game's `?` menu (or confirm in code): no Auto-Save row.

- [ ] **Step 4: Record results**

Note what was and was not checked. Anything not verified live must be said so in the PR description.

---

### Task 10: Update the spec, push and open the PR

**Files:**
- Modify: `docs/superpowers/specs/2026-10-03-auto-save-score-design.md`

- [ ] **Step 1: Record the deviations in the spec**

Under "Components", add a short "As built" list with these differences from the first draft:

- The fill is drawn by `AppButton(fillProgress:)` behind the label, not as an overlay on top of it.
- Menu pause comes from `MenuCoordinator.shared`, read inside `AutoSaveButton`, so all five games pause without each screen passing it (only the scoreboard flag is passed, by Countdown and Halve-It).
- A one-shot latch (`hasFired`) stops a visit that the view model clears late from saving twice.
- Reduce Motion: the fill stays a linear progress indicator (already easing-free), so there is no special case.
- `GameplayMenuButton` has `showsAutoSave` (default `false`) so Remote's menu has no inert toggle.

- [ ] **Step 2: Commit and push**

```bash
git add docs/superpowers/specs/2026-10-03-auto-save-score-design.md
git commit -m "docs: record as-built details in the auto-save spec"
git push -u origin feature/auto-save-score
```

- [ ] **Step 3: Open the PR against `test-flight`**

```bash
gh pr create --base test-flight --head feature/auto-save-score \
  --title "Auto-save the score after 2 seconds (optional, local games)" \
  --body-file <(cat <<'EOF'
## Summary
- Optional Auto-Save setting (off by default): once a visit is complete, the Save Score button fills left to right over 2 seconds and saves when full. Any change to the visit cancels it; tapping saves immediately.
- A winning throw never auto-saves ("Game Over" always needs a tap).
- Toggle in Settings and in the in-game `?` menu, one shared stored value.
- Local games only: 301/501, Knockout, Halve-It, Killer, Sudden Death. Remote is unchanged.

Spec: docs/superpowers/specs/2026-10-03-auto-save-score-design.md

## Known limits
- Knockout, Halve-It, Killer and Sudden Death have no "Game Over" state on the button, so a visit that ends one of those games auto-saves.
- The nav-bar `?` menu cannot be observed, so a fill that completes while it is open saves behind it.
- Auto-save is not armed while VoiceOver is running.

## Test plan
- [x] AutoSavePolicy, AutoSaveTimer, GameplaySettings unit tests
- [ ] Manual per game (results from the verification task)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)
```

Fill the Test plan checkboxes honestly from Task 9 before running this.

---

## Self-review against the spec

| Spec requirement | Task |
|---|---|
| Setting off by default, persisted, one shared value | 3, 6 |
| Toggle in Settings and in-game menu | 6 |
| 2.0 s linear fill, darker shade, left to right, behind the text | 4, 5 |
| Saves via the game's own save call; haptic | 5, 7, 8 |
| Tap saves immediately | 5 (`action: onSave`) |
| Any dart change cancels and restarts (including replacing a dart) | 1 (`autoSaveKey`), 5 (`.task(id:)`) |
| Pause for multiplier menu, scoreboard expanded, app inactive | 5 |
| Winning throw never arms | 1, 5, 7 |
| Bust auto-saves | 5, 7 (label unchanged) |
| Local games only (five) | 7, 8; Remote untouched |
| VoiceOver not armed | 1, 5 |
| Tests: policy, settings, timer | 1, 2, 3 |
| Manual verification per game | 9 |
