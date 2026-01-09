//
//  AnalyticsService.swift
//  Dart Freak
//
//  Created by Billingham Daniel on 2026-01-09.
//

import Foundation
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
    
    func logGameCompleted(gameType: String, winnerType: String, durationSeconds: Int, totalThrows: Int, matchFormat: Int = 1) {
        Analytics.logEvent("game_completed", parameters: [
            "game_type": gameType,
            "winner_type": winnerType,
            "duration_seconds": durationSeconds,
            "total_throws": totalThrows,
            "match_format": matchFormat
        ])
    }
    
    func logGameAbandoned(gameType: String, progressPercentage: Int, reason: String) {
        Analytics.logEvent("game_abandoned", parameters: [
            "game_type": gameType,
            "progress_percentage": progressPercentage,
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
    
    func logSettingsChanged(settingName: String) {
        Analytics.logEvent("settings_changed", parameters: [
            "setting_name": settingName
        ])
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
    
    func logScreenView(screenName: String, screenClass: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass
        ])
    }
}
