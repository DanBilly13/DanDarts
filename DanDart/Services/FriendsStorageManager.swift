//
//  FriendsStorageManager.swift
//  Dart Freak
//
//  Manager for saving and loading friends list to/from local JSON storage
//

import Foundation

class FriendsStorageManager {
    static let shared = FriendsStorageManager()
    
    private let fileManager = FileManager.default
    private let friendsFileName = "friends.json"
    
    private init() {
        // Ensure documents directory exists
        createDocumentsDirectoryIfNeeded()
    }
    
    // MARK: - File URLs
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var friendsFileURL: URL {
        documentsDirectory.appendingPathComponent(friendsFileName)
    }
    
    // MARK: - Directory Setup
    
    private func createDocumentsDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: documentsDirectory.path) {
            try? fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Friends Storage
    
    /// Save friends list to local storage
    func saveFriends(_ friends: [Player]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(friends)
            try data.write(to: friendsFileURL)
            print("✅ Friends saved successfully: \(friends.count) friends")
        } catch {
            print("❌ Error saving friends: \(error.localizedDescription)")
        }
    }
    
    /// Load friends list from local storage
    func loadFriends() -> [Player] {
        guard fileManager.fileExists(atPath: friendsFileURL.path) else {
            print("ℹ️ No friends file found, returning empty array")
            return []
        }
        
        do {
            let data = try Data(contentsOf: friendsFileURL)
            let decoder = JSONDecoder()
            let friends = try decoder.decode([Player].self, from: data)
            print("✅ Loaded \(friends.count) friends")
            return friends
        } catch {
            print("❌ Error loading friends: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Add a friend to the list
    func addFriend(_ friend: Player) -> Bool {
        var friends = loadFriends()
        
        // Check for duplicates
        if friends.contains(where: { $0.id == friend.id }) {
            print("⚠️ Friend already exists: \(friend.displayName)")
            return false
        }
        
        friends.append(friend)
        saveFriends(friends)
        print("✅ Friend added: \(friend.displayName)")
        return true
    }
    
    /// Remove a friend from the list
    func removeFriend(withId id: UUID) {
        var friends = loadFriends()
        friends.removeAll { $0.id == id }
        saveFriends(friends)
        print("✅ Friend removed: \(id)")
    }
    
    /// Check if a player is already a friend
    func isFriend(_ player: Player) -> Bool {
        let friends = loadFriends()
        return friends.contains(where: { $0.id == player.id })
    }
    
    /// Delete all friends (use with caution!)
    func deleteAllFriends() {
        do {
            if fileManager.fileExists(atPath: friendsFileURL.path) {
                try fileManager.removeItem(at: friendsFileURL)
                print("✅ All friends deleted")
            }
        } catch {
            print("❌ Error deleting all friends: \(error.localizedDescription)")
        }
    }
}
