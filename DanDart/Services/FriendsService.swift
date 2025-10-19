//
//  FriendsService.swift
//  DanDart
//
//  Service for managing friend relationships and searching users
//

import Foundation
import Supabase

@MainActor
class FriendsService: ObservableObject {
    private let supabaseService = SupabaseService.shared
    
    // MARK: - Friend Search
    
    /// Search for users by display name or nickname
    /// - Parameters:
    ///   - query: Search query string
    ///   - limit: Maximum number of results (default: 20)
    /// - Returns: Array of matching users
    func searchUsers(query: String, limit: Int = 20) async throws -> [User] {
        guard !query.isEmpty else {
            return []
        }
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Use ilike for case-insensitive search on both display_name and nickname
        let users: [User] = try await supabaseService.client
            .from("users")
            .select()
            .or("display_name.ilike.%\(trimmedQuery)%,nickname.ilike.%\(trimmedQuery)%")
            .limit(limit)
            .execute()
            .value
        
        return users
    }
    
    // MARK: - Friend Management
    
    /// Add a friend (create friendship record)
    /// - Parameters:
    ///   - userId: Current user's ID
    ///   - friendId: Friend's user ID
    func addFriend(userId: UUID, friendId: UUID) async throws {
        // Check if friendship already exists
        let existing: [Friendship] = try await supabaseService.client
            .from("friendships")
            .select()
            .eq("user_id", value: userId)
            .eq("friend_id", value: friendId)
            .execute()
            .value
        
        guard existing.isEmpty else {
            throw FriendsError.alreadyFriends
        }
        
        // Create new friendship
        let friendship = Friendship(
            userId: userId,
            friendId: friendId,
            status: "accepted", // Auto-accept for now, can add pending status later
            createdAt: Date()
        )
        
        try await supabaseService.client
            .from("friendships")
            .insert(friendship)
            .execute()
    }
    
    /// Load all friends for a user
    /// - Parameter userId: User's ID
    /// - Returns: Array of friend User objects
    func loadFriends(userId: UUID) async throws -> [User] {
        // Query friendships table and join with users table
        let friendships: [Friendship] = try await supabaseService.client
            .from("friendships")
            .select()
            .eq("user_id", value: userId)
            .eq("status", value: "accepted")
            .execute()
            .value
        
        // Get friend IDs
        let friendIds = friendships.map { $0.friendId }
        
        guard !friendIds.isEmpty else {
            return []
        }
        
        // Fetch friend user data
        let friends: [User] = try await supabaseService.client
            .from("users")
            .select()
            .in("id", values: friendIds.map { $0.uuidString })
            .execute()
            .value
        
        return friends
    }
    
    /// Remove a friend
    /// - Parameters:
    ///   - userId: Current user's ID
    ///   - friendId: Friend's user ID
    func removeFriend(userId: UUID, friendId: UUID) async throws {
        try await supabaseService.client
            .from("friendships")
            .delete()
            .eq("user_id", value: userId)
            .eq("friend_id", value: friendId)
            .execute()
    }
}

// MARK: - Models

/// Friendship relationship model
struct Friendship: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let friendId: UUID
    let status: String // "pending", "accepted", "rejected"
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
        case status
        case createdAt = "created_at"
    }
    
    init(id: UUID = UUID(), userId: UUID, friendId: UUID, status: String, createdAt: Date) {
        self.id = id
        self.userId = userId
        self.friendId = friendId
        self.status = status
        self.createdAt = createdAt
    }
}

// MARK: - Errors

enum FriendsError: LocalizedError {
    case alreadyFriends
    case userNotFound
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .alreadyFriends:
            return "You are already friends with this user"
        case .userNotFound:
            return "User not found"
        case .networkError:
            return "Network error. Please try again"
        }
    }
}
