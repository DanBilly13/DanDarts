//
//  TrialEndedNoticeTests.swift
//  DanDartTests
//
//  The "your 4 weeks are up" screen: once per account, only after day 28, never for someone
//  who has paid, and never while the inputs are uncertain or something else is on screen.
//

import Foundation
import Testing
@testable import DanDart

struct TrialEndedNoticeTests {

    private let day: TimeInterval = 86_400
    private let created = Date(timeIntervalSince1970: 1_800_000_000)

    private func shows(daysAfterCreation days: Double,
                       purchased: Bool = false,
                       legacy: Bool = false,
                       server: Bool = false,
                       alreadyShown: Bool = false,
                       inputsLoaded: Bool = true,
                       screenBusy: Bool = false) -> Bool {
        TrialEndedNotice.shouldShow(
            inputs: AccessInputs(
                hasPurchasedUnlock: purchased,
                isLegacyPaidCustomer: legacy,
                hasServerEntitlement: server,
                accountCreatedAt: created,
                now: created.addingTimeInterval(days * day)
            ),
            alreadyShown: alreadyShown,
            inputsLoaded: inputsLoaded,
            screenBusy: screenBusy
        )
    }

    @Test func showsTheDayTheTrialEnds() {
        #expect(!shows(daysAfterCreation: 27.9))
        #expect(shows(daysAfterCreation: 28))
        #expect(shows(daysAfterCreation: 200))
    }

    @Test func neverForSomeoneWhoPaid() {
        #expect(!shows(daysAfterCreation: 60, purchased: true))
        #expect(!shows(daysAfterCreation: 60, legacy: true))
        #expect(!shows(daysAfterCreation: 60, server: true))
    }

    /// A paid-app customer offline at launch, or a failed server check, reads as "free".
    @Test func waitsWhenAnInputFailedToLoad() {
        #expect(!shows(daysAfterCreation: 60, inputsLoaded: false))
    }

    @Test func onlyOncePerAccount() {
        #expect(!shows(daysAfterCreation: 60, alreadyShown: true))
    }

    @Test func notOnTopOfSomethingElse() {
        #expect(!shows(daysAfterCreation: 60, screenBusy: true))
    }
}
