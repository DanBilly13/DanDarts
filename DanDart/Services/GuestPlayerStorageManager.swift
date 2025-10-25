//
//  GuestPlayerStorageManager.swift
//  DanDart
//
//  Local storage manager for guest players
//

import Foundation

class GuestPlayerStorageManager {
    static let shared = GuestPlayerStorageManager()
    
    private let storageKey = "savedGuestPlayers"
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Save Guest Player
    
    /// Save a new guest player to local storage
    func saveGuestPlayer(_ player: Player) {
        guard player.isGuest else {
            print("⚠️ Attempted to save non-guest player as guest")
            return
        }
        
        var guests = loadGuestPlayers()
        
        // Check if guest already exists (by nickname)
        if guests.contains(where: { $0.nickname == player.nickname }) {
            print("⚠️ Guest player with nickname '\(player.nickname)' already exists")
            return
        }
        
        guests.append(player)
        saveGuestPlayers(guests)
        print("✅ Saved guest player: \(player.displayName) (@\(player.nickname))")
    }
    
    // MARK: - Load Guest Players
    
    /// Load all saved guest players from local storage
    func loadGuestPlayers() -> [Player] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }
        
        do {
            let guests = try JSONDecoder().decode([Player].self, from: data)
            return guests
        } catch {
            print("❌ Failed to decode guest players: \(error)")
            return []
        }
    }
    
    // MARK: - Delete Guest Player
    
    /// Delete a guest player by ID
    func deleteGuestPlayer(id: UUID) {
        var guests = loadGuestPlayers()
        guests.removeAll { $0.id == id }
        saveGuestPlayers(guests)
        print("✅ Deleted guest player with ID: \(id)")
    }
    
    /// Delete a guest player by nickname
    func deleteGuestPlayer(nickname: String) {
        var guests = loadGuestPlayers()
        guests.removeAll { $0.nickname == nickname }
        saveGuestPlayers(guests)
        print("✅ Deleted guest player: @\(nickname)")
    }
    
    // MARK: - Update Guest Player
    
    /// Update an existing guest player
    func updateGuestPlayer(_ player: Player) {
        guard player.isGuest else {
            print("⚠️ Attempted to update non-guest player")
            return
        }
        
        var guests = loadGuestPlayers()
        
        if let index = guests.firstIndex(where: { $0.id == player.id }) {
            guests[index] = player
            saveGuestPlayers(guests)
            print("✅ Updated guest player: \(player.displayName)")
        } else {
            print("⚠️ Guest player not found for update")
        }
    }
    
    // MARK: - Private Helpers
    
    private func saveGuestPlayers(_ guests: [Player]) {
        do {
            let data = try JSONEncoder().encode(guests)
            userDefaults.set(data, forKey: storageKey)
            print("💾 Saved \(guests.count) guest player(s) to storage")
        } catch {
            print("❌ Failed to encode guest players: \(error)")
        }
    }
    
    // MARK: - Utility
    
    /// Clear all guest players (for testing/debugging)
    func clearAllGuestPlayers() {
        userDefaults.removeObject(forKey: storageKey)
        print("🗑️ Cleared all guest players from storage")
    }
    
    /// Check if a guest player exists by nickname
    func guestExists(nickname: String) -> Bool {
        let guests = loadGuestPlayers()
        return guests.contains(where: { $0.nickname == nickname })
    }
}
