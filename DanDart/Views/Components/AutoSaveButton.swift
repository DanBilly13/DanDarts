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
