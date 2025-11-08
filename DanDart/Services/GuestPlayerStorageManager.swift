//
//  GuestPlayerStorageManager.swift
//  DanDart
//
//  Local storage manager for guest players
//

import Foundation
import UIKit

class GuestPlayerStorageManager {
    static let shared = GuestPlayerStorageManager()
    
    private let storageKey = "savedGuestPlayers"
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Avatar Image Storage
    
    /// Save a custom avatar image for a guest player
    /// - Parameters:
    ///   - image: The UIImage to save
    ///   - playerId: The UUID of the player
    /// - Returns: The file path to the saved image (to be stored in Player.avatarURL)
    func saveCustomAvatar(image: UIImage, for playerId: UUID) -> String? {
        // Resize and compress image
        let resizedImage = image.resized(toMaxDimension: 512)
        guard let jpegData = resizedImage.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert image to JPEG")
            return nil
        }
        
        // Get documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Failed to get documents directory")
            return nil
        }
        
        // Create avatars subdirectory if needed
        let avatarsDirectory = documentsDirectory.appendingPathComponent("guest_avatars", isDirectory: true)
        if !FileManager.default.fileExists(atPath: avatarsDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: avatarsDirectory, withIntermediateDirectories: true)
            } catch {
                print("❌ Failed to create avatars directory: \(error)")
                return nil
            }
        }
        
        // Save image with player ID as filename
        let filename = "\(playerId.uuidString).jpg"
        let fileURL = avatarsDirectory.appendingPathComponent(filename)
        
        do {
            try jpegData.write(to: fileURL)
            print("✅ Saved custom avatar to: \(fileURL.path)")
            return fileURL.path
        } catch {
            print("❌ Failed to save avatar image: \(error)")
            return nil
        }
    }
    
    /// Delete a custom avatar image for a guest player
    /// - Parameter avatarPath: The file path to the avatar image
    func deleteCustomAvatar(at avatarPath: String) {
        let fileURL = URL(fileURLWithPath: avatarPath)
        if FileManager.default.fileExists(atPath: avatarPath) {
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("✅ Deleted custom avatar at: \(avatarPath)")
            } catch {
                print("❌ Failed to delete avatar: \(error)")
            }
        }
    }
    
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
        
        // Find player to check for custom avatar
        if let player = guests.first(where: { $0.id == id }),
           let avatarPath = player.avatarURL,
           avatarPath.hasPrefix("/") { // Custom avatar (file path)
            deleteCustomAvatar(at: avatarPath)
        }
        
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
