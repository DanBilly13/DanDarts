//
//  ClubAnalytics.swift
//  Dart Freak
//
//  The club analytics events as plain data, so their names and parameters can be checked in
//  unit tests. Android logs the same names and parameters (see the clubs spec).
//  Nothing the person typed is ever sent: no search text, no club names, no codes.
//

import Foundation

/// Where a join came from.
enum ClubJoinSource: String {
    case search
    case code
    case link
    case signup
}

enum ClubAnalyticsEvent: Equatable {
    case created(visibility: ClubVisibility)
    /// `visibility` is nil when the app did not know it (a code typed without a preview).
    case joined(source: ClubJoinSource, visibility: ClubVisibility?)
    case left
    case shared
    case suggestionsViewed(count: Int)
    case suggestionAdded
    case suggestionDismissed
    case reported(target: ClubsService.ReportTarget)

    var name: String {
        switch self {
        case .created: return "club_created"
        case .joined: return "club_joined"
        case .left: return "club_left"
        case .shared: return "club_shared"
        case .suggestionsViewed: return "club_suggestions_viewed"
        case .suggestionAdded: return "club_suggestion_added"
        case .suggestionDismissed: return "club_suggestion_dismissed"
        case .reported: return "club_reported"
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .created(let visibility):
            return ["visibility": visibility.rawValue]
        case .joined(let source, let visibility):
            return ["source": source.rawValue, "visibility": visibility?.rawValue ?? "unknown"]
        case .suggestionsViewed(let count):
            return ["count": count]
        case .reported(let target):
            return ["target_type": target.rawValue]
        case .left, .shared, .suggestionAdded, .suggestionDismissed:
            return nil
        }
    }
}
