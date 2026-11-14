//
//  ClubAnalyticsEventTests.swift
//  DanDartTests
//
//  The club analytics schema. Android logs the same names and parameters, so changing one
//  here means changing the other.
//

import Foundation
import Testing
@testable import DanDart

struct ClubAnalyticsEventTests {

    private let samples: [ClubAnalyticsEvent] = [
        .created(visibility: .open),
        .created(visibility: .invite),
        .joined(source: .search, visibility: .open),
        .joined(source: .code, visibility: nil),
        .joined(source: .link, visibility: .invite),
        .joined(source: .signup, visibility: .open),
        .left,
        .shared,
        .suggestionsViewed(count: 4),
        .suggestionAdded,
        .suggestionDismissed,
        .reported(target: .club),
        .reported(target: .user)
    ]

    @Test func namesMatchTheSpec() {
        #expect(ClubAnalyticsEvent.created(visibility: .open).name == "club_created")
        #expect(ClubAnalyticsEvent.joined(source: .link, visibility: nil).name == "club_joined")
        #expect(ClubAnalyticsEvent.left.name == "club_left")
        #expect(ClubAnalyticsEvent.shared.name == "club_shared")
        #expect(ClubAnalyticsEvent.suggestionsViewed(count: 1).name == "club_suggestions_viewed")
        #expect(ClubAnalyticsEvent.suggestionAdded.name == "club_suggestion_added")
        #expect(ClubAnalyticsEvent.suggestionDismissed.name == "club_suggestion_dismissed")
        #expect(ClubAnalyticsEvent.reported(target: .user).name == "club_reported")
    }

    @Test func createdCarriesTheVisibility() {
        #expect(ClubAnalyticsEvent.created(visibility: .open).parameters?["visibility"] as? String == "open")
        #expect(ClubAnalyticsEvent.created(visibility: .invite).parameters?["visibility"] as? String == "invite")
    }

    @Test func joinedCarriesTheSourceAndVisibilityOrUnknown() {
        let link = ClubAnalyticsEvent.joined(source: .link, visibility: .invite).parameters
        #expect(link?["source"] as? String == "link")
        #expect(link?["visibility"] as? String == "invite")

        let typed = ClubAnalyticsEvent.joined(source: .code, visibility: nil).parameters
        #expect(typed?["source"] as? String == "code")
        #expect(typed?["visibility"] as? String == "unknown")
    }

    @Test func everyJoinSourceIsInTheSpecList() {
        let sources = [ClubJoinSource.search, .code, .link, .signup].map(\.rawValue)
        #expect(sources == ["search", "code", "link", "signup"])
    }

    @Test func suggestionsViewedCarriesTheCount() {
        #expect(ClubAnalyticsEvent.suggestionsViewed(count: 4).parameters?["count"] as? Int == 4)
    }

    @Test func reportedCarriesTheTargetType() {
        #expect(ClubAnalyticsEvent.reported(target: .club).parameters?["target_type"] as? String == "club")
        #expect(ClubAnalyticsEvent.reported(target: .user).parameters?["target_type"] as? String == "user")
    }

    @Test func eventsWithoutDetailsSendNoParameters() {
        #expect(ClubAnalyticsEvent.left.parameters == nil)
        #expect(ClubAnalyticsEvent.shared.parameters == nil)
        #expect(ClubAnalyticsEvent.suggestionAdded.parameters == nil)
        #expect(ClubAnalyticsEvent.suggestionDismissed.parameters == nil)
    }

    @Test func nothingTheUserTypedIsEverASentParameter() {
        let forbidden: Set<String> = ["query", "search", "search_text", "name", "club_name", "town", "code", "join_code", "reason", "user_id", "club_id"]
        for event in samples {
            let keys = Set((event.parameters ?? [:]).keys)
            #expect(keys.isDisjoint(with: forbidden), "\(event.name) sends \(keys.intersection(forbidden))")
        }
    }

    @Test func parameterValuesAreOnlyTextOrNumbers() {
        for event in samples {
            for (key, value) in event.parameters ?? [:] {
                #expect(value is String || value is Int, "\(event.name).\(key) is not a plain value")
            }
        }
    }
}
