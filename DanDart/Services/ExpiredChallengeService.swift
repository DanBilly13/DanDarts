//
//  ExpiredChallengeService.swift
//  DanDart
//
//  Service for managing expired unseen challenges storage
//

import Foundation

@MainActor
class ExpiredChallengeService: ObservableObject {
    static let shared = ExpiredChallengeService()
    
    private let storageKey = "expired_challenges"
    @Published private(set) var expiredChallenges: [ExpiredChallenge] = []
    
    private init() {
        loadExpiredChallenges()
    }
    
    // MARK: - Storage Operations
    
    /// Store an expired challenge if it meets all preservation conditions
    func storeExpiredChallenge(
        matchWithPlayers: RemoteMatchWithPlayers,
        isReplayOrRematch: Bool,
        isUserOnRemoteTab: Bool,
        isIncomingChallenge: Bool
    ) {
        // Preservation conditions check
        guard !isReplayOrRematch else {
            print("=== EXPIRED CHALLENGE STORAGE: SKIPPED (replay/rematch) ===")
            return
        }
        
        guard !isUserOnRemoteTab else {
            print("=== EXPIRED CHALLENGE STORAGE: SKIPPED (user on Remote tab) ===")
            return
        }
        
        guard isIncomingChallenge else {
            print("=== EXPIRED CHALLENGE STORAGE: SKIPPED (not incoming challenge) ===")
            return
        }
        
        // Prevent duplicate storage
        guard !expiredChallenges.contains(where: { $0.matchId == matchWithPlayers.match.id }) else {
            print("=== EXPIRED CHALLENGE STORAGE: SKIPPED (already stored) ===")
            return
        }
        
        // Create expired challenge snapshot
        let expiredChallenge = ExpiredChallenge.from(
            matchWithPlayers: matchWithPlayers,
            expiredAt: Date()
        )
        
        // Store it
        expiredChallenges.append(expiredChallenge)
        saveExpiredChallenges()
        
        print("=== EXPIRED CHALLENGE STORED ===")
        print("matchId: \(expiredChallenge.matchId)")
        print("challenger: \(expiredChallenge.challengerDisplayName)")
        print("gameType: \(expiredChallenge.gameType)")
        print("expiredAt: \(expiredChallenge.expiredAt)")
        print("=== END STORAGE LOG ===")
    }
    
    // MARK: - Persistence
    
    private func saveExpiredChallenges() {
        do {
            let data = try JSONEncoder().encode(expiredChallenges)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("Saved \(expiredChallenges.count) expired challenges to storage")
        } catch {
            print("Failed to save expired challenges: \(error)")
        }
    }
    
    private func loadExpiredChallenges() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("No stored expired challenges found")
            return
        }
        
        do {
            expiredChallenges = try JSONDecoder().decode([ExpiredChallenge].self, from: data)
            print("Loaded \(expiredChallenges.count) expired challenges from storage")
        } catch {
            print("Failed to load expired challenges: \(error)")
            expiredChallenges = []
        }
    }
    
    // MARK: - Debug/Testing
    
    /// Clear all stored expired challenges (for testing)
    func clearAllExpiredChallenges() {
        expiredChallenges.removeAll()
        saveExpiredChallenges()
        print("Cleared all expired challenges from storage")
    }
    
    /// Get count of stored expired challenges
    var count: Int {
        expiredChallenges.count
    }
}
