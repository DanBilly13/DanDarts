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
    
    /// Send a friend request (Task 301)
    /// - Parameters:
    ///   - userId: Current user's ID (requester)
    ///   - friendId: Friend's user ID (addressee)
    func sendFriendRequest(userId: UUID, friendId: UUID) async throws {
        // Check if any relationship already exists (in either direction)
        let existing: [Friendship] = try await supabaseService.client
            .from("friendships")
            .select()
            .or("and(requester_id.eq.\(userId.uuidString),addressee_id.eq.\(friendId.uuidString)),and(requester_id.eq.\(friendId.uuidString),addressee_id.eq.\(userId.uuidString))")
            .execute()
            .value
        
        // Check for existing relationships
        if let existingRelationship = existing.first {
            switch existingRelationship.status {
            case "accepted":
                throw FriendsError.alreadyFriends
            case "pending":
                throw FriendsError.requestPending
            case "blocked":
                throw FriendsError.userBlocked
            default:
                break
            }
        }
        
        // Create new friend request with pending status
        let friendship = Friendship(
            userId: userId, // Legacy field
            friendId: friendId, // Legacy field
            requesterId: userId,
            addresseeId: friendId,
            status: "pending",
            createdAt: Date()
        )
        
        try await supabaseService.client
            .from("friendships")
            .insert(friendship)
            .execute()
    }
    
    /// Add a friend (legacy method - now calls sendFriendRequest)
    /// - Parameters:
    ///   - userId: Current user's ID
    ///   - friendId: Friend's user ID
    @available(*, deprecated, message: "Use sendFriendRequest instead")
    func addFriend(userId: UUID, friendId: UUID) async throws {
        try await sendFriendRequest(userId: userId, friendId: friendId)
    }
    
    /// Load all friends for a user
    /// - Parameter userId: User's ID
    /// - Returns: Array of friend User objects
    func loadFriends(userId: UUID) async throws -> [User] {
        // Query friendships where user is EITHER requester OR addressee, and status is accepted
        // This handles bidirectional friendships
        let friendships: [Friendship] = try await supabaseService.client
            .from("friendships")
            .select()
            .or("requester_id.eq.\(userId.uuidString),addressee_id.eq.\(userId.uuidString)")
            .eq("status", value: "accepted")
            .execute()
            .value
        
        // Extract friend IDs (the OTHER person in each friendship)
        let friendIds = friendships.map { friendship -> UUID in
            // If current user is requester, friend is addressee (and vice versa)
            if friendship.requesterId == userId {
                return friendship.addresseeId
            } else {
                return friendship.requesterId
            }
        }
        
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
        // Delete friendship where users are in EITHER direction (bidirectional)
        try await supabaseService.client
            .from("friendships")
            .delete()
            .or("and(requester_id.eq.\(userId.uuidString),addressee_id.eq.\(friendId.uuidString)),and(requester_id.eq.\(friendId.uuidString),addressee_id.eq.\(userId.uuidString))")
            .execute()
    }
    
    // MARK: - Friend Requests (Task 302)
    
    /// Load received friend requests (where current user is addressee)
    /// - Parameter userId: Current user's ID
    /// - Returns: Array of FriendRequest objects with requester user data
    func loadReceivedRequests(userId: UUID) async throws -> [FriendRequest] {
        // Query friendships where user is addressee and status is pending
        let friendships: [Friendship] = try await supabaseService.client
            .from("friendships")
            .select()
            .eq("addressee_id", value: userId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
        
        guard !friendships.isEmpty else {
            return []
        }
        
        // Get requester IDs
        let requesterIds = friendships.map { $0.requesterId }
        
        // Fetch requester user data
        let users: [User] = try await supabaseService.client
            .from("users")
            .select()
            .in("id", values: requesterIds.map { $0.uuidString })
            .execute()
            .value
        
        // Create dictionary for quick lookup
        let userDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        
        // Map to FriendRequest objects
        return friendships.compactMap { friendship in
            guard let user = userDict[friendship.requesterId] else { return nil }
            return FriendRequest(
                id: friendship.id,
                user: user,
                createdAt: friendship.createdAt,
                type: .received
            )
        }
    }
    
    /// Load sent friend requests (where current user is requester)
    /// - Parameter userId: Current user's ID
    /// - Returns: Array of FriendRequest objects with addressee user data
    func loadSentRequests(userId: UUID) async throws -> [FriendRequest] {
        // Query friendships where user is requester and status is pending
        let friendships: [Friendship] = try await supabaseService.client
            .from("friendships")
            .select()
            .eq("requester_id", value: userId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
        
        guard !friendships.isEmpty else {
            return []
        }
        
        // Get addressee IDs
        let addresseeIds = friendships.map { $0.addresseeId }
        
        // Fetch addressee user data
        let users: [User] = try await supabaseService.client
            .from("users")
            .select()
            .in("id", values: addresseeIds.map { $0.uuidString })
            .execute()
            .value
        
        // Create dictionary for quick lookup
        let userDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        
        // Map to FriendRequest objects
        return friendships.compactMap { friendship in
            guard let user = userDict[friendship.addresseeId] else { return nil }
            return FriendRequest(
                id: friendship.id,
                user: user,
                createdAt: friendship.createdAt,
                type: .sent
            )
        }
    }
    
    // MARK: - Friend Request Actions (Task 303-305)
    
    /// Accept a friend request (Task 303)
    /// - Parameter requestId: Friendship ID to accept
    func acceptFriendRequest(requestId: UUID) async throws {
        // Update friendship status from 'pending' to 'accepted'
        try await supabaseService.client
            .from("friendships")
            .update(["status": "accepted"])
            .eq("id", value: requestId)
            .execute()
    }
    
    /// Deny a friend request (Task 304)
    /// - Parameter requestId: Friendship ID to deny
    func denyFriendRequest(requestId: UUID) async throws {
        // Delete the friendship record
        try await supabaseService.client
            .from("friendships")
            .delete()
            .eq("id", value: requestId)
            .execute()
    }
    
    /// Withdraw a sent friend request (Task 305)
    /// - Parameter requestId: Friendship ID to withdraw
    func withdrawFriendRequest(requestId: UUID) async throws {
        // Delete the friendship record
        try await supabaseService.client
            .from("friendships")
            .delete()
            .eq("id", value: requestId)
            .execute()
    }
    
    // MARK: - Block User (Task 306-307)
    
    /// Block a user (Task 306)
    /// - Parameters:
    ///   - userId: Current user's ID
    ///   - blockedUserId: User ID to block
    func blockUser(userId: UUID, blockedUserId: UUID) async throws {
        // Check if friendship already exists (in either direction)
        let existing: [Friendship] = try await supabaseService.client
            .from("friendships")
            .select()
            .or("and(requester_id.eq.\(userId.uuidString),addressee_id.eq.\(blockedUserId.uuidString)),and(requester_id.eq.\(blockedUserId.uuidString),addressee_id.eq.\(userId.uuidString))")
            .execute()
            .value
        
        if let existingFriendship = existing.first {
            // Update existing friendship to 'blocked'
            try await supabaseService.client
                .from("friendships")
                .update(["status": "blocked"])
                .eq("id", value: existingFriendship.id)
                .execute()
        } else {
            // Create new friendship record with 'blocked' status
            let friendship = Friendship(
                userId: userId, // Legacy field
                friendId: blockedUserId, // Legacy field
                requesterId: userId,
                addresseeId: blockedUserId,
                status: "blocked",
                createdAt: Date()
            )
            
            try await supabaseService.client
                .from("friendships")
                .insert(friendship)
                .execute()
        }
    }
    
    /// Load blocked users (Task 307)
    /// - Parameter userId: Current user's ID
    /// - Returns: Array of blocked User objects
    func loadBlockedUsers(userId: UUID) async throws -> [User] {
        // Query friendships where user is requester and status is blocked
        let friendships: [Friendship] = try await supabaseService.client
            .from("friendships")
            .select()
            .eq("requester_id", value: userId)
            .eq("status", value: "blocked")
            .order("created_at", ascending: false)
            .execute()
            .value
        
        guard !friendships.isEmpty else {
            return []
        }
        
        // Get blocked user IDs
        let blockedUserIds = friendships.map { $0.addresseeId }
        
        // Fetch blocked user data
        let users: [User] = try await supabaseService.client
            .from("users")
            .select()
            .in("id", values: blockedUserIds.map { $0.uuidString })
            .execute()
            .value
        
        return users
    }
    
    /// Unblock a user (Task 307)
    /// - Parameters:
    ///   - userId: Current user's ID
    ///   - blockedUserId: User ID to unblock
    func unblockUser(userId: UUID, blockedUserId: UUID) async throws {
        // Delete the block record
        try await supabaseService.client
            .from("friendships")
            .delete()
            .or("and(requester_id.eq.\(userId.uuidString),addressee_id.eq.\(blockedUserId.uuidString)),and(requester_id.eq.\(blockedUserId.uuidString),addressee_id.eq.\(userId.uuidString))")
            .execute()
    }
    
    // MARK: - Badge Count (Task 308)
    
    /// Get count of pending received friend requests (Task 308)
    /// - Parameter userId: Current user's ID
    /// - Returns: Count of pending received requests
    func getPendingRequestCount(userId: UUID) async throws -> Int {
        // Query friendships where user is addressee and status is pending
        let friendships: [Friendship] = try await supabaseService.client
            .from("friendships")
            .select()
            .eq("addressee_id", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value
        
        return friendships.count
    }
}

// MARK: - Models

/// Friendship relationship model
struct Friendship: Codable, Identifiable {
    let id: UUID
    let userId: UUID // Legacy field
    let friendId: UUID // Legacy field
    let requesterId: UUID // Who sent the request
    let addresseeId: UUID // Who received the request
    let status: String // "pending", "accepted", "rejected", "blocked"
    let createdAt: Date
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID = UUID(), userId: UUID, friendId: UUID, requesterId: UUID, addresseeId: UUID, status: String, createdAt: Date, updatedAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.friendId = friendId
        self.requesterId = requesterId
        self.addresseeId = addresseeId
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Friend request model for displaying pending requests
struct FriendRequest: Identifiable {
    let id: UUID // Friendship ID
    let user: User // The other user (requester or addressee)
    let createdAt: Date
    let type: RequestType
    
    enum RequestType {
        case received // Current user is addressee
        case sent     // Current user is requester
    }
    
    /// Format the date as relative time (e.g., "2 days ago")
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - Errors

enum FriendsError: LocalizedError {
    case alreadyFriends
    case requestPending
    case userBlocked
    case userNotFound
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .alreadyFriends:
            return "You are already friends with this user"
        case .requestPending:
            return "Friend request already sent"
        case .userBlocked:
            return "Cannot send friend request to this user"
        case .userNotFound:
            return "User not found"
        case .networkError:
            return "Network error. Please try again"
        }
    }
}
