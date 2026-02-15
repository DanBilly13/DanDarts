//
//  FriendsService.swift
//  Dart Freak
//
//  Service for managing friend relationships and searching users
//

import Foundation
import Supabase

@MainActor
class FriendsService: ObservableObject {
    private let supabaseService = SupabaseService.shared
    private let analytics = AnalyticsService.shared
    
    // MARK: - Realtime Subscription
    
    private var realtimeChannel: RealtimeChannelV2?
    @Published var friendshipChanged: Bool = false
    // Debug: retain broadcast subscription token so the callback stays alive
    private var pingSubscription: RealtimeSubscription?
    
    // Retain Postgres-change subscriptions (otherwise callbacks may be dropped)
    private var insertSubscription: RealtimeSubscription?
    private var updateSubscription: RealtimeSubscription?
    private var deleteSubscription: RealtimeSubscription?
    private var statusSubscription: RealtimeSubscription?
    
    /// Setup realtime subscription for friendship changes
    func setupRealtimeSubscription(userId: UUID) async {
        print("🔵 [Realtime] ========================================")
        print("🔵 [Realtime] SETUP START for user: \(userId)")
        print("🔵 [Realtime] Current channel exists: \(realtimeChannel != nil)")
        
        // Remove existing subscription first
        await removeRealtimeSubscription()
        print("🔵 [Realtime] Old subscription removed")
        
        // Create channel for friendships table
        // Use shared channel name so all users receive broadcasts
        let channelName = "public:friendships"
        print("🔵 [Realtime] Creating channel: \(channelName)")
        let channel = supabaseService.client.realtimeV2.channel(channelName) {
            $0.broadcast.receiveOwnBroadcasts = true
        }
        print("🔵 [Realtime] Channel created")
        
        // Listen for INSERT events (no server-side filter - client-side filtering is more reliable)
        print("🔵 [Realtime] Registering INSERT callback (client-side filtering)")
        insertSubscription = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "friendships"
        ) { [weak self] action in
            // CRITICAL: Log INSIDE callback to prove events are arriving
            print("🚨🚨🚨 [Realtime] ========================================")
            print("🚨🚨🚨 [Realtime] INSERT CALLBACK FIRED!!!")
            print("🚨🚨🚨 [Realtime] Payload: \(action.record)")
            print("🚨🚨🚨 [Realtime] Thread: \(Thread.current)")
            print("🚨🚨🚨 [Realtime] Timestamp: \(Date())")
            print("🚨🚨🚨 [Realtime] ========================================")

            // Client-side filter: only process if user is requester or addressee
            let record = action.record
            guard
                let requesterIdString = record["requester_id"]?.stringValue,
                let addresseeIdString = record["addressee_id"]?.stringValue,
                let requesterId = UUID(uuidString: requesterIdString),
                let addresseeId = UUID(uuidString: addresseeIdString),
                requesterId == userId || addresseeId == userId
            else {
                print("🚨 [Realtime] Skipping - not for user \(userId)")
                return
            }

            print("🚨 [Realtime] Processing - event is for current user!")
            Task { @MainActor in
                self?.handleFriendshipInsert(action, userId: userId)
            }
        }
        
        // Listen for UPDATE events (client-side filtering)
        print("🔵 [Realtime] Registering UPDATE callback (client-side filtering)")
        updateSubscription = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "friendships"
        ) { [weak self] action in
            // Client-side filter: only process if user is requester or addressee
            let record = action.record
            guard
                let requesterIdString = record["requester_id"]?.stringValue,
                let addresseeIdString = record["addressee_id"]?.stringValue,
                let requesterId = UUID(uuidString: requesterIdString),
                let addresseeId = UUID(uuidString: addresseeIdString),
                requesterId == userId || addresseeId == userId
            else {
                return
            }

            Task { @MainActor in
                self?.handleFriendshipUpdate(action, userId: userId)
            }
        }
        
        // Listen for DELETE events (client-side filtering)
        print("� [Realtime] Registering DELETE callback (client-side filtering)")
        deleteSubscription = channel.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "friendships"
        ) { [weak self] action in
            // Client-side filter: only process if user is requester or addressee
            let record = action.oldRecord
            guard
                let requesterIdString = record["requester_id"]?.stringValue,
                let addresseeIdString = record["addressee_id"]?.stringValue,
                let requesterId = UUID(uuidString: requesterIdString),
                let addresseeId = UUID(uuidString: addresseeIdString),
                requesterId == userId || addresseeId == userId
            else {
                return
            }

            Task { @MainActor in
                self?.handleFriendshipDelete(action, userId: userId)
            }
        }
        
        // Monitor channel status changes
        print("🔵 [Realtime] Setting up status change monitoring...")
        statusSubscription = channel.onStatusChange { status in
            print("🔔 [Realtime] ========================================")
            print("🔔 [Realtime] CHANNEL STATUS CHANGED: \(status)")
            print("🔔 [Realtime] Timestamp: \(Date())")
            print("🔔 [Realtime] ========================================")
        }
        
        print("🔵 [Realtime] All callbacks registered, calling subscribe()...")

        // Retain the channel before subscribing (prevents accidental deallocation during async subscribe)
        realtimeChannel = channel
        print("🔵 [Realtime] Channel stored in realtimeChannel property (pre-subscribe)")

        // Subscribe to the channel
        do {
            // Register broadcast handler BEFORE subscribing, and retain the subscription token
            pingSubscription = channel.onBroadcast(event: "ping") { message in
                print("📡 [Realtime] broadcast ping received:", message)
            }

            // Use the newer subscribe API
            try await channel.subscribeWithError()

            // 🔎 Debug: prove the socket can receive *anything*
            struct PingMessage: Codable { let hello: String }
            try? await channel.broadcast(event: "ping", message: PingMessage(hello: "world"))
            print("📡 [Realtime] broadcast ping sent")

            print("✅ [Realtime] SUBSCRIPTION ACTIVE")
            print("✅ [Realtime] Channel status: \(channel.status)")
            print("✅ [Realtime] ========================================")

            await checkForPendingRequestsOnReturn(userId: userId)
        } catch {
            print("❌ [Realtime] SUBSCRIPTION FAILED")
            print("❌ [Realtime] Error: \(error)")
            print("❌ [Realtime] Error details: \(error.localizedDescription)")
            print("❌ [Realtime] ========================================")
        }
    }
    
    /// Remove realtime subscription
    func removeRealtimeSubscription() async {
        if let channel = realtimeChannel {
            print("🔵 [Realtime] Removing subscription")
            await channel.unsubscribe()
            realtimeChannel = nil
            pingSubscription = nil
            insertSubscription = nil
            updateSubscription = nil
            deleteSubscription = nil
            statusSubscription = nil
        }
    }
    
    /// Handle INSERT events (new friend request)
    private func handleFriendshipInsert(_ action: InsertAction, userId: UUID) {
        print("� [Handler] ========================================")
        print("📝 [Handler] handleFriendshipInsert CALLED")
        print("📝 [Handler] Current user: \(userId)")
        print("📝 [Handler] Thread: \(Thread.current)")
        
        // Toggle the published property to trigger view updates
        friendshipChanged.toggle()
        print("📝 [Handler] friendshipChanged toggled to: \(friendshipChanged)")
        
        // Post notification for badge updates
        NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsChanged"), object: nil)
        print("📝 [Handler] Posted FriendRequestsChanged notification")
        
        // Handle toast for new request received
        Task {
            print("📝 [Handler] Starting toast task...")
            await handleInsertToast(record: action.record, currentUserId: userId)
            print("📝 [Handler] Toast task completed")
        }
        print("📝 [Handler] ========================================")
    }
    
    /// Handle UPDATE events (request accepted)
    private func handleFriendshipUpdate(_ action: UpdateAction, userId: UUID) {
        print("🔔 [Realtime] Friendship UPDATE detected")
        
        // Toggle the published property to trigger view updates
        friendshipChanged.toggle()
        
        // Post notification for badge updates
        NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsChanged"), object: nil)
        
        // Handle toast for request accepted
        Task {
            await handleUpdateToast(record: action.record, currentUserId: userId)
        }
    }
    
    /// Handle DELETE events (request denied/withdrawn)
    private func handleFriendshipDelete(_ action: DeleteAction, userId: UUID) {
        print("🔔 [Realtime] Friendship DELETE detected")
        
        // Toggle the published property to trigger view updates
        friendshipChanged.toggle()
        
        // Post notification for badge updates
        NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsChanged"), object: nil)
        
        // Handle toast for request denied
        Task {
            await handleDeleteToast(record: action.oldRecord, currentUserId: userId)
        }
    }
    
    /// Handle toast for INSERT action (new friend request received)
    private func handleInsertToast(record: [String: AnyJSON], currentUserId: UUID) async {
        print("📝 [Toast] handleInsertToast called")
        print("📝 [Toast] Record: \(record)")
        print("📝 [Toast] Current user: \(currentUserId)")
        
        // Compare UUIDs instead of strings to avoid case-sensitivity issues
        guard let addresseeIdString = record["addressee_id"]?.stringValue,
              let addresseeId = UUID(uuidString: addresseeIdString),
              addresseeId == currentUserId else {
            print("📝 [Toast] Not for current user (addressee: \(record["addressee_id"]?.stringValue ?? "nil"), current: \(currentUserId))")
            return
        }
        print("📝 [Toast] Addressee ID matches current user: \(addresseeId)")
        
        guard let requesterIdString = record["requester_id"]?.stringValue else {
            print("❌ [Toast] Failed to get requester_id")
            return
        }
        print("📝 [Toast] Requester ID: \(requesterIdString)")
        
        guard let requesterId = UUID(uuidString: requesterIdString) else {
            print("❌ [Toast] Failed to parse requester UUID")
            return
        }
        
        guard let friendshipIdString = record["id"]?.stringValue else {
            print("❌ [Toast] Failed to get friendship id")
            return
        }
        
        guard let friendshipId = UUID(uuidString: friendshipIdString) else {
            print("❌ [Toast] Failed to parse friendship UUID")
            return
        }
        
        print("📝 [Toast] Fetching user data for requester: \(requesterId)")
        
        // Fetch requester's data
        do {
            let users: [User] = try await supabaseService.client
                .from("users")
                .select()
                .eq("id", value: requesterId.uuidString)
                .execute()
                .value
            
            guard let requester = users.first else {
                print("❌ [Toast] No user found for requester")
                return
            }
            
            print("✅ [Toast] Creating toast for: \(requester.displayName)")
            
            let toast = FriendRequestToast(
                type: .requestReceived,
                user: requester,
                message: "New friend request from \(requester.displayName)",
                friendshipId: friendshipId
            )
            
            print("✅ [Toast] Showing toast")
            await FriendRequestToastManager.shared.showToast(toast)
            print("✅ [Toast] Toast shown successfully")
        } catch {
            print("❌ [Realtime] Failed to fetch user data for toast: \(error)")
        }
    }
    
    /// Handle toast for UPDATE action (friend request accepted)
    private func handleUpdateToast(record: [String: AnyJSON], currentUserId: UUID) async {
        print("📝 [Toast] handleUpdateToast called")
        print("📝 [Toast] Record: \(record)")
        print("📝 [Toast] Current user: \(currentUserId)")
        
        guard let statusString = record["status"]?.stringValue else {
            print("❌ [Toast] Failed to get status")
            return
        }
        print("📝 [Toast] Status: \(statusString)")
        
        guard statusString == "accepted" else {
            print("📝 [Toast] Status is not 'accepted', skipping toast")
            return
        }
        
        guard let requesterIdString = record["requester_id"]?.stringValue else {
            print("❌ [Toast] Failed to get requester_id")
            return
        }
        print("📝 [Toast] Requester ID: \(requesterIdString)")
        
        guard requesterIdString == currentUserId.uuidString else {
            print("📝 [Toast] Not for current user (requester: \(requesterIdString), current: \(currentUserId.uuidString))")
            return
        }
        
        guard let addresseeIdString = record["addressee_id"]?.stringValue else {
            print("❌ [Toast] Failed to get addressee_id")
            return
        }
        
        guard let addresseeId = UUID(uuidString: addresseeIdString) else {
            print("❌ [Toast] Failed to parse addressee UUID")
            return
        }
        
        print("📝 [Toast] Fetching user data for addressee: \(addresseeId)")
        
        // Fetch addressee's data (the person who accepted)
        do {
            let users: [User] = try await supabaseService.client
                .from("users")
                .select()
                .eq("id", value: addresseeId.uuidString)
                .execute()
                .value
            
            guard let addressee = users.first else {
                print("❌ [Toast] No user found for addressee")
                return
            }
            
            print("✅ [Toast] Creating toast for: \(addressee.displayName)")
            
            let toast = FriendRequestToast(
                type: .requestAccepted,
                user: addressee,
                message: "\(addressee.displayName) accepted your friend request",
                friendshipId: nil
            )
            
            print("✅ [Toast] Showing toast")
            await FriendRequestToastManager.shared.showToast(toast)
            print("✅ [Toast] Toast shown successfully")
        } catch {
            print("❌ [Realtime] Failed to fetch user data for toast: \(error)")
        }
    }
    
    /// Handle toast for DELETE action (friend request denied)
    private func handleDeleteToast(record: [String: AnyJSON], currentUserId: UUID) async {
        guard let requesterIdString = record["requester_id"]?.stringValue,
              requesterIdString == currentUserId.uuidString,
              let addresseeIdString = record["addressee_id"]?.stringValue,
              let addresseeId = UUID(uuidString: addresseeIdString) else {
            return
        }
        
        // Fetch addressee's data (the person who denied)
        do {
            let users: [User] = try await supabaseService.client
                .from("users")
                .select()
                .eq("id", value: addresseeId.uuidString)
                .execute()
                .value
            
            guard let addressee = users.first else { return }
            
            let toast = FriendRequestToast(
                type: .requestDenied,
                user: addressee,
                message: "\(addressee.displayName) declined your friend request",
                friendshipId: nil
            )
            FriendRequestToastManager.shared.showToast(toast)
        } catch {
            print("❌ [Realtime] Failed to fetch user data for toast: \(error)")
        }
    }
    
    /// Check for pending friend requests when user returns to app
    /// Shows toast for most recent pending request if any exist
    func checkForPendingRequestsOnReturn(userId: UUID) async {
        print("🔍 [Toast] Checking for pending requests on return")
        print("🔍 [Toast] User ID: \(userId.uuidString)")
        
        do {
            // Query for pending received requests
            let friendships: [Friendship] = try await supabaseService.client
                .from("friendships")
                .select()
                .eq("addressee_id", value: userId.uuidString)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            print("📝 [Toast] Query returned \(friendships.count) pending requests")
            
            guard let mostRecent = friendships.first else {
                print("📝 [Toast] No pending requests found for user \(userId.uuidString)")
                return
            }
            
            print("📝 [Toast] Found pending request from: \(mostRecent.requesterId)")
            
            // Fetch requester's data
            let users: [User] = try await supabaseService.client
                .from("users")
                .select()
                .eq("id", value: mostRecent.requesterId.uuidString)
                .execute()
                .value
            
            guard let requester = users.first else {
                print("❌ [Toast] No user found for requester")
                return
            }
            
            print("✅ [Toast] Creating catch-up toast for: \(requester.displayName)")
            
            let toast = FriendRequestToast(
                type: .requestReceived,
                user: requester,
                message: "New friend request from \(requester.displayName)",
                friendshipId: mostRecent.id
            )
            
            // Show toast with delay for smooth app launch/return experience
            let config = FriendRequestToastManager.shared.animationConfig
            print("✅ [Toast] Showing catch-up toast with \(config.initialDelay)s delay")
            await FriendRequestToastManager.shared.showToast(toast, delay: config.initialDelay)
            print("✅ [Toast] Catch-up toast shown successfully")
        } catch {
            print("❌ [Toast] Failed to check for pending requests: \(error)")
        }
    }
    
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
        print("📤 [SendRequest] Sending friend request:")
        print("   From (requester): \(userId.uuidString)")
        print("   To (addressee): \(friendId.uuidString)")
        
        // Check if any relationship already exists (in either direction)
        let existing: [Friendship] = try await supabaseService.client
            .from("friendships")
            .select()
            .or("and(requester_id.eq.\(userId.uuidString),addressee_id.eq.\(friendId.uuidString)),and(requester_id.eq.\(friendId.uuidString),addressee_id.eq.\(userId.uuidString))")
            .execute()
            .value
        
        print("📝 [SendRequest] Found \(existing.count) existing relationship(s)")
        for (index, friendship) in existing.enumerated() {
            print("   Record \(index + 1): requester=\(friendship.requesterId), addressee=\(friendship.addresseeId), status=\(friendship.status)")
        }
        
        // Check for existing relationships
        if let existingRelationship = existing.first {
            print("⚠️ [SendRequest] Existing relationship found with status: \(existingRelationship.status)")
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
        
        print("✅ [SendRequest] No conflicts, creating new friend request")
        
        // Create new friend request with pending status
        let friendship = Friendship(
            requesterId: userId,
            addresseeId: friendId,
            status: "pending",
            createdAt: Date()
        )
        
        // Insert new friend request
        try await supabaseService.client
            .from("friendships")
            .insert(friendship)
            .execute()
        
        print("✅ [SendRequest] Friend request created successfully")
        
        // Log friend request sent event
        analytics.logFriendRequestSent()
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
        print("🗑️ [RemoveFriend] Removing friendship between users:")
        print("   User 1: \(userId.uuidString)")
        print("   User 2: \(friendId.uuidString)")
        
        // First, check what records exist before deletion
        let existing: [Friendship] = try await supabaseService.client
            .from("friendships")
            .select()
            .or("and(requester_id.eq.\(userId.uuidString),addressee_id.eq.\(friendId.uuidString)),and(requester_id.eq.\(friendId.uuidString),addressee_id.eq.\(userId.uuidString))")
            .execute()
            .value
        
        print("📝 [RemoveFriend] Found \(existing.count) existing friendship record(s)")
        for (index, friendship) in existing.enumerated() {
            print("   Record \(index + 1): requester=\(friendship.requesterId), addressee=\(friendship.addresseeId), status=\(friendship.status)")
        }
        
        // Delete friendship where users are in EITHER direction (bidirectional)
        try await supabaseService.client
            .from("friendships")
            .delete()
            .or("and(requester_id.eq.\(userId.uuidString),addressee_id.eq.\(friendId.uuidString)),and(requester_id.eq.\(friendId.uuidString),addressee_id.eq.\(userId.uuidString))")
            .execute()
        
        print("✅ [RemoveFriend] Deletion complete")
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
        
        // Log friend request accepted event
        analytics.logFriendRequestAccepted()
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
    let requesterId: UUID // Who sent the request
    let addresseeId: UUID // Who received the request
    let status: String // "pending", "accepted", "rejected", "blocked"
    let createdAt: Date
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case addresseeId = "addressee_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID = UUID(), requesterId: UUID, addresseeId: UUID, status: String, createdAt: Date, updatedAt: Date? = nil) {
        self.id = id
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
