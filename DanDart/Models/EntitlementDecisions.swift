//
//  EntitlementDecisions.swift
//  DanDart
//
//  Small pure decisions used by EntitlementStore and MainTabView, kept here so they're
//  unit-tested: the paid-download cache, the trial-ended notice and a waiting club link.
//

import Foundation

/// Combines the live AppTransaction answer with the cached one.
struct LegacyResolution: Equatable {
    var isLegacy: Bool
    /// False when we couldn't tell (offline, nothing cached): treat as "inputs not loaded".
    var isKnown: Bool
    /// The value to keep in UserDefaults (false means remove the key).
    var cache: Bool

    /// - Parameters:
    ///   - live: the verified AppTransaction answer, or nil when it couldn't be read.
    ///   - cached: a paid download verified on an earlier launch.
    static func resolve(live: Bool?, cached: Bool) -> LegacyResolution {
        switch live {
        case .some(let isLegacy):
            return LegacyResolution(isLegacy: isLegacy, isKnown: true, cache: isLegacy)
        case .none:
            // A cached "yes" keeps an offline paid customer unlocked. Without it, we don't know.
            return LegacyResolution(isLegacy: cached, isKnown: cached, cache: cached)
        }
    }
}

/// Whether to open the "your 4 weeks are up" screen. Once per account, only on the free
/// tier, only when every input loaded (a failed check counts as "locked", and telling a
/// paying customer their trial is over would be wrong), and not on top of something else.
enum TrialEndedNotice {
    static func shouldShow(inputs: AccessInputs, alreadyShown: Bool, inputsLoaded: Bool, screenBusy: Bool) -> Bool {
        AccessPolicy.evaluate(inputs) == .free && inputsLoaded && !alreadyShown && !screenBusy
    }
}

/// What to do with a club link that's waiting (PendingClubCodeStore has a code).
enum ClubLinkDecision: Equatable {
    /// Leave the code where it is and decide later.
    case wait
    /// Open the join sheet (and forget the code).
    case presentJoin
    /// Clubs are locked: open the unlock screen. The code is kept while it's open and
    /// forgotten if it's closed without unlocking.
    case showPaywall

    static func decide(entitlementLoaded: Bool, canUseClubs: Bool,
                       paywallOpenForCode: Bool, otherPaywallShowing: Bool) -> ClubLinkDecision {
        // Until this account's entitlement has loaded, state is the optimistic "new account"
        // trial, which would let anyone join.
        guard entitlementLoaded else { return .wait }
        if canUseClubs { return .presentJoin }
        if paywallOpenForCode || otherPaywallShowing { return .wait }
        return .showPaywall
    }
}
