//
//  RemoteScoreAnimationHandler.swift
//  DanDart
//
//  Manages score update animations and local score overrides for remote matches
//  Handles temporary score display during animations
//

import SwiftUI
import Foundation

@MainActor
class RemoteScoreAnimationHandler: ObservableObject {
    // MARK: - Published State
    
    @Published var localScoreOverride: [UUID: Int]?
    @Published var showOpponentScoreAnimation: Bool = false
    
    // MARK: - Private State
    
    private var observers: [NSObjectProtocol] = []
    
    // MARK: - Lifecycle
    
    func cleanup() {
        // Remove notification observers
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }
    
    // MARK: - Score Override Methods
    
    /// Set local score override for a player during animation
    func setLocalScoreOverride(playerId: UUID, score: Int, serverScores: [UUID: Int]?, vmScores: [UUID: Int]) {
        var override = serverScores ?? vmScores
        override[playerId] = score
        localScoreOverride = override
        print("🎬 [ScoreAnimation] Override set: player=\(playerId.uuidString.prefix(8)) score=\(score)")
    }
    
    /// Clear local score override (server scores will take over)
    func clearLocalScoreOverride() {
        localScoreOverride = nil
        print("🎬 [ScoreAnimation] Override cleared")
    }
    
    /// Get scores for UI: prefer local override, then server, then VM
    func renderScores(serverScores: [UUID: Int]?, vmScores: [UUID: Int]) -> [UUID: Int] {
        return localScoreOverride ?? serverScores ?? vmScores
    }
    
    // MARK: - Notification Observers
    
    func setupNotificationObservers(
        preTurnRevealIsActive: @escaping () -> Bool,
        onScoreUpdate: @escaping (UUID, Int) -> Void,
        onClearOverride: @escaping () -> Void
    ) {
        // Listen for score updates during animation
        let scoreUpdateObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RemoteMatchScoreUpdated"),
            object: nil,
            queue: .main
        ) { notification in
            if let playerId = notification.userInfo?["playerId"] as? UUID,
               let score = notification.userInfo?["score"] as? Int {
                onScoreUpdate(playerId, score)
            }
        }
        observers.append(scoreUpdateObserver)
        
        // Listen for animation completion
        let animationCompleteObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RemoteMatchScoreAnimationComplete"),
            object: nil,
            queue: .main
        ) { _ in
            // Only clear if not during opponent reveal (opponent manages its own override)
            if !preTurnRevealIsActive() {
                onClearOverride()
            }
        }
        observers.append(animationCompleteObserver)
        
        print("🎬 [ScoreAnimation] Notification observers setup")
    }
}
