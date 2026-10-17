//
//  AnalyticsService.swift
//  Dart Freak
//
//  Created by Billingham Daniel on 2026-01-09.
//

import Foundation
import SwiftUI
import FirebaseAnalytics

class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - Game Events
    
    func logGameStarted(gameType: String, playerCount: Int, hasGuests: Bool, matchFormat: Int = 1) {
        Analytics.logEvent("game_started", parameters: [
            "game_type": gameType,
            "player_count": playerCount,
            "has_guests": hasGuests,
            "match_format": matchFormat
        ])
    }
    
    /// `durationSeconds` and `totalThrows` are omitted when unknown (e.g. remote matches have no client-side start time).
    /// `isRemote` is always sent so remote and local matches can be told apart; Android logs the same parameters.
    func logGameCompleted(gameType: String, winnerType: String, durationSeconds: Int? = nil, totalThrows: Int? = nil, matchFormat: Int = 1, isRemote: Bool = false) {
        var parameters: [String: Any] = [
            "game_type": gameType,
            "winner_type": winnerType,
            "match_format": matchFormat,
            "is_remote": isRemote
        ]
        if let durationSeconds { parameters["duration_seconds"] = durationSeconds }
        if let totalThrows { parameters["total_throws"] = totalThrows }
        Analytics.logEvent("game_completed", parameters: parameters)
    }
    
    /// The player left a match through the menu before it finished. Android logs the same event and parameters.
    func logGameAbandoned(gameType: String, playerCount: Int, reason: String = "quit") {
        Analytics.logEvent("game_abandoned", parameters: [
            "game_type": gameType,
            "player_count": playerCount,
            "reason": reason
        ])
    }
    
    func logPerfectCheckout(gameType: String, checkoutScore: Int, dartsUsed: Int) {
        Analytics.logEvent("perfect_checkout", parameters: [
            "game_type": gameType,
            "checkout_score": checkoutScore,
            "darts_used": dartsUsed
        ])
    }
    
    // MARK: - Social Events
    
    func logFriendRequestSent() {
        Analytics.logEvent("friend_request_sent", parameters: nil)
    }
    
    func logFriendRequestAccepted() {
        Analytics.logEvent("friend_request_accepted", parameters: nil)
    }
    
    func logMatchVsFriend(gameType: String) {
        Analytics.logEvent("match_vs_friend", parameters: [
            "game_type": gameType
        ])
    }
    
    func logFriendSearched() {
        Analytics.logEvent("friend_searched", parameters: nil)
    }
    
    // MARK: - Engagement Events
    
    func logMatchHistoryViewed(totalMatches: Int) {
        Analytics.logEvent("match_history_viewed", parameters: [
            "total_matches": totalMatches
        ])
    }
    
    func logProfileViewed(isOwnProfile: Bool) {
        Analytics.logEvent("profile_viewed", parameters: [
            "is_own_profile": isOwnProfile
        ])
    }
    
    func logSettingsChanged(settingName: String, enabled: Bool) {
        Analytics.logEvent("settings_changed", parameters: [
            "setting_name": settingName,
            "enabled": enabled
        ])
    }
    
    /// The cross-device history refresh failed (the user sees "Couldn't sync with cloud").
    func logHistoryRemoteRefreshFailed() {
        Analytics.logEvent("history_remote_refresh_failed", parameters: nil)
    }
    
    /// Result of the OS notification prompt; `source` is where it was shown ("onboarding" or "settings").
    func logNotificationPermission(granted: Bool, source: String) {
        Analytics.logEvent("notification_permission", parameters: [
            "granted": granted,
            "source": source
        ])
    }
    
    func logAccountDeleted() {
        Analytics.logEvent("account_deleted", parameters: nil)
    }
    
    // MARK: - Remote Match Events
    
    /// Remote challenges are named "Remote 301"/"Remote 501" in places; Android and the game_* events use "301"/"501".
    func logRemoteChallengeSent(gameType: String, matchFormat: Int, isRematch: Bool) {
        Analytics.logEvent("remote_challenge_sent", parameters: [
            "game_type": gameType.replacingOccurrences(of: "Remote ", with: ""),
            "match_format": matchFormat,
            "is_rematch": isRematch
        ])
    }
    
    func logRemoteChallengeAccepted() {
        Analytics.logEvent("remote_challenge_accepted", parameters: nil)
    }
    
    /// The receiver turning down a pending challenge.
    func logRemoteChallengeDeclined() {
        Analytics.logEvent("remote_challenge_declined", parameters: nil)
    }
    
    /// The sender withdrawing a challenge that hasn't started.
    func logRemoteChallengeCancelled() {
        Analytics.logEvent("remote_challenge_cancelled", parameters: nil)
    }
    
    // MARK: - Onboarding Events
    
    func logProfileSetupCompleted(hasAvatar: Bool, signupMethod: String) {
        Analytics.logEvent("profile_setup_completed", parameters: [
            "has_avatar": hasAvatar,
            "signup_method": signupMethod
        ])
    }
    
    func logFirstGamePlayed(gameType: String, timeSinceSignupHours: Int) {
        Analytics.logEvent("first_game_played", parameters: [
            "game_type": gameType,
            "time_since_signup_hours": timeSinceSignupHours
        ])
    }
    
    // MARK: - Screen View Events
    
    /// Screen names match Android's route names (GamesList, FriendsList, RemoteTab, History, Settings, ...) so both platforms chart together.
    func logScreenView(screenName: String, screenClass: String = "SwiftUI") {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass
        ])
    }
}

extension View {
    /// Logs a `screen_view` each time this view appears. Firebase's automatic screen reporting is turned off in Info.plist
    /// because SwiftUI reports every screen as the same hosting controller.
    func trackScreen(_ name: String) -> some View {
        onAppear { AnalyticsService.shared.logScreenView(screenName: name) }
    }
}
