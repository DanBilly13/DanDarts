//
//  TrialEndedNoticeTests.swift
//  DanDartTests
//
//  The "your 4 weeks are up" screen shows once per account, only on the free tier,
//  and only when every input loaded (a failed check falls back to "locked").
//

import Testing
@testable import DanDart

struct TrialEndedNoticeTests {

    @Test func showsOnTheFreeTierWhenEverythingLoaded() {
        #expect(TrialEndedNotice.shouldShow(state: .free, alreadyShown: false, inputsLoaded: true))
    }

    @Test func showsOnlyOnce() {
        #expect(!TrialEndedNotice.shouldShow(state: .free, alreadyShown: true, inputsLoaded: true))
    }

    @Test func waitsWhenAnInputFailedToLoad() {
        #expect(!TrialEndedNotice.shouldShow(state: .free, alreadyShown: false, inputsLoaded: false))
    }

    @Test func neverShowsDuringTheTrialOrWhenUnlocked() {
        let states: [AccessState] = [.trial(daysLeft: 1), .unlocked(.purchased), .unlocked(.legacyPaidApp), .unlocked(.otherPlatform)]
        for state in states {
            #expect(!TrialEndedNotice.shouldShow(state: state, alreadyShown: false, inputsLoaded: true), "\(state)")
        }
    }
}
