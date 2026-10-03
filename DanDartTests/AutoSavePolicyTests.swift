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
