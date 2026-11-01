//
//  AppTabTests.swift
//  DanDartTests
//
//  The names tabs report to analytics must stay the same as Android's route names, so both
//  platforms chart together; titles are what the user sees at the top of each tab.
//

import Testing
@testable import DanDart

struct AppTabTests {

    @Test func analyticsScreenNamesMatchAndroid() {
        #expect(AppTab.games.analyticsScreenName == "GamesList")
        #expect(AppTab.friends.analyticsScreenName == "FriendsList")
        #expect(AppTab.clubs.analyticsScreenName == "ClubsList")
        #expect(AppTab.remote.analyticsScreenName == "RemoteTab")
        #expect(AppTab.history.analyticsScreenName == "History")
    }

    @Test func titlesAreWhatTheUserSees() {
        #expect(AppTab.games.title == "Games")
        #expect(AppTab.friends.title == "Friends")
        #expect(AppTab.clubs.title == "Clubs")
        #expect(AppTab.remote.title == "Remote matches")
        #expect(AppTab.history.title == "History")
    }

    @Test func clubsSitsBetweenFriendsAndRemote() {
        #expect(AppTab.allCases == [.games, .friends, .clubs, .remote, .history])
    }

    @Test func everyTabHasADistinctScreenName() {
        let names = AppTab.allCases.map(\.analyticsScreenName)
        #expect(Set(names).count == AppTab.allCases.count)
    }
}
