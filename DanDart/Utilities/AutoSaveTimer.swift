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
