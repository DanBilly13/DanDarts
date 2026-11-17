//
//  PaidFeature.swift
//  DanDart
//
//  The parts of DartFreak that need DartFreak Pro once the 4-week trial ends.
//  Everything else (account, local 301/501, friends, history list) is free forever.
//  Locks only change what is SHOWN. Match data is always saved for everyone.
//

import Foundation

enum PaidFeature: String, CaseIterable, Identifiable {
    case partyGames
    case remoteMatches
    case clubs
    case headToHead
    case fullStats
    case fullHistory

    var id: String { rawValue }

    var lockedTitle: String {
        switch self {
        case .partyGames: return "More games"
        case .remoteMatches: return "Remote matches"
        case .clubs: return "Clubs"
        case .headToHead: return "Head-to-head"
        case .fullStats: return "Your full stats"
        case .fullHistory: return "Match details"
        }
    }

    /// Headline on the pinned Get Pro panel over a locked stats screen.
    var proHeadline: String {
        switch self {
        case .headToHead: return "Who's really winning?"
        case .fullStats: return "Every stat, saved."
        default: return lockedTitle
        }
    }

    /// The one line under that headline.
    var proBody: String {
        switch self {
        case .headToHead: return "Every match between you two, in one place."
        case .fullStats: return "Trends, scoring and personal bests since your first game."
        default: return lockedMessage
        }
    }

    var lockedMessage: String {
        switch self {
        case .partyGames: return "Cricket, Halve-It, Knockout, Sudden Death and Killer come with DartFreak Pro."
        case .remoteMatches: return "Play your mates live from anywhere, with voice chat."
        case .clubs: return "Join and run clubs with the people you play with."
        case .headToHead: return "See who's really winning between you two."
        case .fullStats: return "Your trends, scoring and personal bests have been saved since day one."
        case .fullHistory: return "Every throw of this match has been saved. Unlock to see it."
        }
    }
}

/// Why the unlock screen is showing.
enum PaywallReason: Identifiable, Equatable {
    case feature(PaidFeature)
    /// Opened from the banner in the last days of the trial.
    case trialEnding(daysLeft: Int)
    /// Shown once, the first time we notice the trial is over.
    case trialEnded

    var id: String {
        switch self {
        case .feature(let feature): return "feature-\(feature.rawValue)"
        case .trialEnding: return "trial-ending"
        case .trialEnded: return "trial-ended"
        }
    }

    var analyticsName: String {
        switch self {
        case .feature(let feature): return feature.rawValue
        case .trialEnding: return "trial_ending"
        case .trialEnded: return "trial_ended"
        }
    }

    /// The one line under "DartFreak Pro" on the unlock screen. The list of what you get
    /// does the explaining, so this stays short.
    var tagline: String {
        switch self {
        case .feature: return "Pay once. Keep it forever."
        case .trialEnding(let daysLeft):
            return daysLeft == 1 ? "1 day left of your free trial" : "\(daysLeft) days left of your free trial"
        case .trialEnded: return "Your free trial has ended"
        }
    }

    /// The feature that brought the user here, highlighted in the list.
    var feature: PaidFeature? {
        if case .feature(let feature) = self { return feature }
        return nil
    }
}

enum GameAccess {
    /// Game types that are free forever. Matched against both stored `gameType`
    /// values and local game titles, which are "301" and "501" for these two.
    /// Remote matches are saved as "Remote 301" / "Remote 501" and count too.
    static let freeGameTypes: Set<String> = ["301", "501"]

    static func isFree(gameType: String) -> Bool {
        var normalized = gameType.trimmingCharacters(in: .whitespaces).lowercased()
        if normalized.hasPrefix("remote ") {
            normalized = String(normalized.dropFirst("remote ".count))
                .trimmingCharacters(in: .whitespaces)
        }
        return freeGameTypes.contains(normalized)
    }
}

/// Thrown by service-level guards so a locked feature can't start by a side route
/// (a rematch button or a notification), even if a view forgot to check.
struct PaidFeatureLockedError: LocalizedError {
    let feature: PaidFeature

    var errorDescription: String? {
        "\(feature.lockedTitle) need DartFreak Pro."
    }
}
