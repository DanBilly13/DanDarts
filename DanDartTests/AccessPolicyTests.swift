//
//  AccessPolicyTests.swift
//  DanDartTests
//
//  4 weeks of everything from account creation, then the free tier,
//  unless they bought DartFreak Full, bought the paid app, or unlocked on Android.
//

import Foundation
import Testing
@testable import DanDart

struct AccessPolicyTests {

    private let day: TimeInterval = 86_400
    private let created = Date(timeIntervalSince1970: 1_800_000_000)

    private func state(daysAfterCreation days: Double,
                       purchased: Bool = false,
                       legacy: Bool = false,
                       server: Bool = false) -> AccessState {
        AccessPolicy.evaluate(AccessInputs(
            hasPurchasedUnlock: purchased,
            isLegacyPaidCustomer: legacy,
            hasServerEntitlement: server,
            accountCreatedAt: created,
            now: created.addingTimeInterval(days * day)
        ))
    }

    @Test func newAccountGetsTheFullTrial() {
        #expect(state(daysAfterCreation: 0) == .trial(daysLeft: 28))
    }

    @Test func daysLeftRoundsUp() {
        #expect(state(daysAfterCreation: 27.5) == .trial(daysLeft: 1))
        #expect(state(daysAfterCreation: 1) == .trial(daysLeft: 27))
    }

    @Test func trialEndsAfterTwentyEightDays() {
        #expect(state(daysAfterCreation: 28) == .free)
        #expect(state(daysAfterCreation: 90) == .free)
    }

    @Test func purchaseUnlocksForever() {
        #expect(state(daysAfterCreation: 90, purchased: true) == .unlocked(.purchased))
        #expect(state(daysAfterCreation: 1, purchased: true) == .unlocked(.purchased))
    }

    @Test func paidAppBuyersAreUnlocked() {
        #expect(state(daysAfterCreation: 400, legacy: true) == .unlocked(.legacyPaidApp))
    }

    @Test func otherPlatformPurchaseUnlocks() {
        #expect(state(daysAfterCreation: 400, server: true) == .unlocked(.otherPlatform))
    }

    @Test func unknownAccountDateDoesNotFlashLocks() {
        let s = AccessPolicy.evaluate(AccessInputs(accountCreatedAt: nil, now: created))
        #expect(s == .trial(daysLeft: 28))
    }

    @Test func fullAccessFlag() {
        #expect(AccessState.trial(daysLeft: 3).hasFullAccess)
        #expect(AccessState.unlocked(.purchased).hasFullAccess)
        #expect(!AccessState.free.hasFullAccess)
    }
}
