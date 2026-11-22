//
//  LegacyPurchaseTests.swift
//  DanDartTests
//
//  Anyone whose first download was a build before the app went free paid for it,
//  and keeps everything.
//

import Testing
@testable import DanDart

struct LegacyPurchaseTests {

    @Test func earlierBuildsPaid() {
        #expect(LegacyPurchase.isLegacyPaidCustomer(originalAppVersion: "54", firstFreeBuild: 55))
        #expect(LegacyPurchase.isLegacyPaidCustomer(originalAppVersion: "1", firstFreeBuild: 55))
    }

    @Test func freeBuildsDidNotPay() {
        #expect(!LegacyPurchase.isLegacyPaidCustomer(originalAppVersion: "55", firstFreeBuild: 55))
        #expect(!LegacyPurchase.isLegacyPaidCustomer(originalAppVersion: "60", firstFreeBuild: 55))
    }

    /// The sandbox (Xcode / TestFlight) reports "1.0", which must not unlock anything.
    @Test func nonNumericVersionsAreNotLegacy() {
        #expect(!LegacyPurchase.isLegacyPaidCustomer(originalAppVersion: "1.0", firstFreeBuild: 55))
        #expect(!LegacyPurchase.isLegacyPaidCustomer(originalAppVersion: "", firstFreeBuild: 55))
    }
}
