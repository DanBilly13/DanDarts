//
//  AccessPolicy.swift
//  DanDart
//
//  Decides what a user can use. Pure, so it's fully unit-tested;
//  EntitlementStore gathers the inputs from StoreKit and Supabase.
//

import Foundation

enum UnlockReason: Equatable {
    case purchased       // bought DartFreak Pro on this Apple ID
    case legacyPaidApp   // first downloaded DartFreak when it was a paid app
    case otherPlatform   // unlocked on Android (or granted by hand) — user_entitlements row
}

enum AccessState: Equatable {
    case unlocked(UnlockReason)
    case trial(daysLeft: Int)
    case free

    var hasFullAccess: Bool {
        if case .free = self { return false }
        return true
    }
}

struct AccessInputs: Equatable {
    var hasPurchasedUnlock = false
    var isLegacyPaidCustomer = false
    var hasServerEntitlement = false
    /// nil while the user row is still loading — treated as a brand-new account so locks don't flash.
    var accountCreatedAt: Date?
    var now = Date()
}

enum AccessPolicy {
    static let trialDays = 28

    static func evaluate(_ inputs: AccessInputs) -> AccessState {
        if inputs.hasPurchasedUnlock { return .unlocked(.purchased) }
        if inputs.isLegacyPaidCustomer { return .unlocked(.legacyPaidApp) }
        if inputs.hasServerEntitlement { return .unlocked(.otherPlatform) }

        guard let createdAt = inputs.accountCreatedAt else { return .trial(daysLeft: trialDays) }

        let trialEnd = createdAt.addingTimeInterval(TimeInterval(trialDays) * 86_400)
        let remaining = trialEnd.timeIntervalSince(inputs.now)
        guard remaining > 0 else { return .free }
        return .trial(daysLeft: Int((remaining / 86_400).rounded(.up)))
    }
}
