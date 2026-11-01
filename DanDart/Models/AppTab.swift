//
//  AppTab.swift
//  Dart Freak
//
//  The tabs of the main tab bar. Replaces the bare integers MainTabView used to tag tabs with,
//  so adding a tab (Clubs) can't silently shift the others.
//

import Foundation

enum AppTab: Hashable {
    case games
    case friends
    case remote
    case history

    /// Large title shown top-left on the tab's root screen.
    var title: String {
        switch self {
        case .games: return "Games"
        case .friends: return "Friends"
        case .remote: return "Remote matches"
        case .history: return "History"
        }
    }

    /// Same screen names as Android's routes, so both platforms chart together.
    var analyticsScreenName: String {
        switch self {
        case .games: return "GamesList"
        case .friends: return "FriendsList"
        case .remote: return "RemoteTab"
        case .history: return "History"
        }
    }
}
