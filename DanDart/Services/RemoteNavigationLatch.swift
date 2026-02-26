//
//  RemoteNavigationLatch.swift
//  DanDart
//
//  Global navigation guard to prevent duplicate navigation per match
//

import Foundation

@MainActor
class RemoteNavigationLatch {
    static let shared = RemoteNavigationLatch()
    
    private var navigatedMatches = Set<UUID>()
    
    private init() {}
    
    /// Try to navigate to gameplay for a match. Returns true if navigation is allowed, false if already navigated.
    func tryNavigateToGameplay(matchId: UUID) -> Bool {
        guard !navigatedMatches.contains(matchId) else {
            print("🚫 [NavigationLatch] Already navigated to gameplay for match \(matchId)")
            return false
        }
        navigatedMatches.insert(matchId)
        print("✅ [NavigationLatch] Allowing navigation to gameplay for match \(matchId)")
        return true
    }
    
    /// Clear navigation state for a specific match
    func clearNavigation(matchId: UUID) {
        navigatedMatches.remove(matchId)
        print("🔄 [NavigationLatch] Cleared navigation for match \(matchId)")
    }
    
    /// Reset all navigation state
    func reset() {
        navigatedMatches.removeAll()
        print("🔄 [NavigationLatch] Reset all navigation state")
    }
}
