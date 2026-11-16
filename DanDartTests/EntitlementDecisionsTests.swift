//
//  EntitlementDecisionsTests.swift
//  DanDartTests
//
//  The paid-download cache and what a waiting club link should do.
//

import Testing
@testable import DanDart

struct LegacyResolutionTests {

    @Test func verifiedPaidDownloadIsRememberedForOfflineLaunches() {
        let r = LegacyResolution.resolve(live: true, cached: false)
        #expect(r == LegacyResolution(isLegacy: true, isKnown: true, cache: true))
    }

    @Test func verifiedFreeDownloadClearsAStaleCache() {
        let r = LegacyResolution.resolve(live: false, cached: true)
        #expect(r == LegacyResolution(isLegacy: false, isKnown: true, cache: false))
    }

    @Test func offlinePaidCustomerFallsBackToTheCache() {
        let r = LegacyResolution.resolve(live: nil, cached: true)
        #expect(r == LegacyResolution(isLegacy: true, isKnown: true, cache: true))
    }

    /// Unknown, not "not legacy": nothing surprising (the trial-ended notice) should follow.
    @Test func offlineWithNoCacheIsUnknown() {
        let r = LegacyResolution.resolve(live: nil, cached: false)
        #expect(r == LegacyResolution(isLegacy: false, isKnown: false, cache: false))
    }
}

struct ClubLinkDecisionTests {

    @Test func waitsUntilTheAccountsEntitlementLoaded() {
        // Before loading, state is the optimistic trial: joining then would let anyone in.
        #expect(ClubLinkDecision.decide(entitlementLoaded: false, canUseClubs: true,
                                        paywallOpenForCode: false, otherPaywallShowing: false) == .wait)
    }

    @Test func unlockedJoinsStraightAway() {
        #expect(ClubLinkDecision.decide(entitlementLoaded: true, canUseClubs: true,
                                        paywallOpenForCode: false, otherPaywallShowing: false) == .presentJoin)
        // Unlocked while the clubs paywall was open: go on to join.
        #expect(ClubLinkDecision.decide(entitlementLoaded: true, canUseClubs: true,
                                        paywallOpenForCode: true, otherPaywallShowing: false) == .presentJoin)
    }

    @Test func lockedShowsTheUnlockScreenOnce() {
        #expect(ClubLinkDecision.decide(entitlementLoaded: true, canUseClubs: false,
                                        paywallOpenForCode: false, otherPaywallShowing: false) == .showPaywall)
        #expect(ClubLinkDecision.decide(entitlementLoaded: true, canUseClubs: false,
                                        paywallOpenForCode: true, otherPaywallShowing: false) == .wait)
    }

    @Test func lockedWaitsBehindAnotherUnlockScreen() {
        #expect(ClubLinkDecision.decide(entitlementLoaded: true, canUseClubs: false,
                                        paywallOpenForCode: false, otherPaywallShowing: true) == .wait)
    }
}
