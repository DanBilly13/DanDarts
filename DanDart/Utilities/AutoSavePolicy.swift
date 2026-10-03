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
