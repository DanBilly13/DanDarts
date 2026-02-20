//
//  RemoteMatchService.swift
//  DanDart
//
//  Service for managing remote matches (live multiplayer)
//

import Foundation
import Supabase

@MainActor
class RemoteMatchService: ObservableObject {
    private let supabaseService = SupabaseService.shared
    private let authService = AuthService.shared
    
    // MARK: - Configuration Constants
    
    private let challengeExpirySeconds: TimeInterval = 86400 // 24 hours
    private let joinWindowSeconds: TimeInterval = 30 // 30 seconds (DEBUG: was 300/5min)
    
    // MARK: - Published State
    
    @Published var pendingChallenges: [RemoteMatchWithPlayers] = []
    @Published var sentChallenges: [RemoteMatchWithPlayers] = []
    @Published var readyMatches: [RemoteMatchWithPlayers] = []
    @Published var activeMatch: RemoteMatchWithPlayers?
    @Published var isLoading = false
    @Published var error: RemoteMatchError?
    
    // MARK: - Helper Methods
    
    /// Get headers required for Edge Function calls (apikey + auth token)
    private func getEdgeFunctionHeaders() async throws -> [String: String] {
        // Get current session
        guard let session = try? await supabaseService.client.auth.session else {
            print("❌ No session found")
            throw RemoteMatchError.notAuthenticated
        }
        
        // Debug log
        print("🔑 Session token: \(session.accessToken.prefix(12))...")
        
        return [
            "apikey": supabaseService.supabaseAnonKey,
            "Authorization": "Bearer \(session.accessToken)"
        ]
    }
    
    // MARK: - Realtime Subscription
    
    private var realtimeChannel: RealtimeChannelV2?
    
    // MARK: - Load Matches
    
    /// Load all remote matches for the current user
    func loadMatches(userId: UUID) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Query matches where user is challenger or receiver
        let matches: [RemoteMatch] = try await supabaseService.client
            .from("matches")
            .select()
            .eq("match_mode", value: "remote")
            .or("challenger_id.eq.\(userId.uuidString),receiver_id.eq.\(userId.uuidString)")
            .order("created_at", ascending: false)
            .execute()
            .value
        
        // Load user data for all unique user IDs
        var userIds = Set<UUID>()
        for match in matches {
            userIds.insert(match.challengerId)
            userIds.insert(match.receiverId)
        }
        
        let users: [User] = try await supabaseService.client
            .from("users")
            .select()
            .in("id", values: Array(userIds).map { $0.uuidString })
            .execute()
            .value
        
        let userDict = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        
        // Build RemoteMatchWithPlayers objects
        var pending: [RemoteMatchWithPlayers] = []
        var sent: [RemoteMatchWithPlayers] = []
        var ready: [RemoteMatchWithPlayers] = []
        var active: RemoteMatchWithPlayers?
        
        for match in matches {
            guard let challenger = userDict[match.challengerId],
                  let receiver = userDict[match.receiverId] else {
                continue
            }
            
            let matchWithPlayers = RemoteMatchWithPlayers(
                match: match,
                challenger: challenger,
                receiver: receiver,
                currentUserId: userId
            )
            
            // Handle optional status
            guard let status = match.status else { continue }
            
            switch status {
            case .pending:
                if match.receiverId == userId {
                    pending.append(matchWithPlayers)
                } else {
                    sent.append(matchWithPlayers)
                }
            case .sent:
                // This should never come from database, but handle it for completeness
                // .sent is UI-only state, database always uses .pending
                sent.append(matchWithPlayers)
            case .ready:
                ready.append(matchWithPlayers)
            case .lobby, .inProgress:
                active = matchWithPlayers
            case .completed, .expired, .cancelled:
                // Don't show finished matches in active lists
                break
            }
        }
        
        self.pendingChallenges = pending
        self.sentChallenges = sent
        self.readyMatches = ready
        self.activeMatch = active
    }
    
    // MARK: - Create Challenge
    
    /// Create a new challenge (calls Edge Function)
    func createChallenge(
        receiverId: UUID,
        gameType: String,
        matchFormat: Int,
        currentUserId: UUID
    ) async throws -> UUID {
        // Validate not challenging self
        guard receiverId != currentUserId else {
            throw RemoteMatchError.notAuthorized
        }
        
        // Check if user already has an active match
        let hasActiveLock = try await checkUserHasLock(userId: currentUserId)
        if hasActiveLock {
            throw RemoteMatchError.alreadyHasActiveMatch
        }
        
        struct CreateChallengeRequest: Encodable {
            let receiver_id: String
            let game_type: String
            let match_format: Int
        }
        
        struct CreateChallengeResponse: Decodable {
            let success: Bool
            let data: MatchData
            let message: String
            
            struct MatchData: Decodable {
                let id: String
            }
        }
        
        let request = CreateChallengeRequest(
            receiver_id: receiverId.uuidString,
            game_type: gameType,
            match_format: matchFormat
        )
        
        let headers = try await getEdgeFunctionHeaders()
        
        print("🚀 Calling create-challenge Edge Function...")
        print("   - receiver_id: \(receiverId)")
        print("   - game_type: \(gameType)")
        print("   - match_format: \(matchFormat)")
        
        do {
            let response: CreateChallengeResponse = try await supabaseService.client.functions
                .invoke("create-challenge", options: FunctionInvokeOptions(
                    headers: headers,
                    body: request
                ))
            
            guard let matchId = UUID(uuidString: response.data.id) else {
                throw RemoteMatchError.databaseError("Invalid match ID returned from server")
            }
            
            print("✅ Challenge created: \(matchId)")
            
            return matchId
        } catch {
            print("❌ create-challenge Edge Function failed:")
            print("   - Error: \(error)")
            print("   - Error type: \(type(of: error))")
            print("   - Localized description: \(error.localizedDescription)")
            
            // Try to extract more details from the error
            if let functionError = error as? FunctionsError {
                print("   - FunctionsError details: \(functionError)")
            }
            
            // Re-throw as database error with details
            throw RemoteMatchError.databaseError("Edge Function error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Accept Challenge
    
    /// Accept a challenge and transition to ready (calls Edge Function)
    func acceptChallenge(matchId: UUID) async throws {
        struct AcceptRequest: Encodable {
            let match_id: String
        }
        
        let request = AcceptRequest(match_id: matchId.uuidString)
        
        print("🔍 Getting headers for accept-challenge...")
        let headers = try await getEdgeFunctionHeaders()
        print("📋 Headers to send:")
        print("   - apikey: \(String(headers["apikey"]?.prefix(20) ?? "MISSING"))...")
        print("   - Authorization: \(String(headers["Authorization"]?.prefix(30) ?? "MISSING"))...")
        
        print("🚀 Calling accept-challenge with match_id: \(matchId)")
        
        let _: EmptyResponse = try await supabaseService.client.functions
            .invoke("accept-challenge", options: FunctionInvokeOptions(
                headers: headers,
                body: request
            ))
        
        print("✅ Challenge accepted: \(matchId)")
    }
    
    // MARK: - Decline/Cancel Challenge
    
    /// Decline a received challenge or cancel a sent challenge (calls Edge Function)
    func cancelChallenge(matchId: UUID) async throws {
        struct CancelRequest: Encodable {
            let match_id: String
        }
        
        let request = CancelRequest(match_id: matchId.uuidString)
        let headers = try await getEdgeFunctionHeaders()
        
        let _: EmptyResponse = try await supabaseService.client.functions
            .invoke("cancel-match", options: FunctionInvokeOptions(
                headers: headers,
                body: request
            ))
        
        print("✅ Challenge cancelled: \(matchId)")
    }
    
    // MARK: - Join Match
    
    /// Join a ready match and start gameplay (calls Edge Function)
    func joinMatch(matchId: UUID) async throws {
        struct JoinRequest: Encodable {
            let match_id: String
        }
        
        let request = JoinRequest(match_id: matchId.uuidString)
        let headers = try await getEdgeFunctionHeaders()
        
        let _: EmptyResponse = try await supabaseService.client.functions
            .invoke("join-match", options: FunctionInvokeOptions(
                headers: headers,
                body: request
            ))
        
        print("✅ Match joined: \(matchId)")
    }
    
    // MARK: - Legacy Accept Challenge (kept for reference, use acceptChallenge instead)
    
    /// Legacy: Accept a challenge and transition to ready (direct DB access)
    private func acceptChallengeLegacy(matchId: UUID, currentUserId: UUID) async throws {
        // Check if user already has an active match
        let hasActiveLock = try await checkUserHasLock(userId: currentUserId)
        if hasActiveLock {
            throw RemoteMatchError.alreadyHasActiveMatch
        }
        
        // Load the match
        let match: RemoteMatch = try await supabaseService.client
            .from("matches")
            .select()
            .eq("id", value: matchId.uuidString)
            .single()
            .execute()
            .value
        
        // Validate user is receiver
        guard match.receiverId == currentUserId else {
            throw RemoteMatchError.notAuthorized
        }
        
        // Validate status is pending
        guard match.status == RemoteMatchStatus.pending else {
            throw RemoteMatchError.invalidStatus
        }
        
        // Check not expired
        if let expiresAt = match.challengeExpiresAt, Date() > expiresAt {
            throw RemoteMatchError.matchExpired
        }
        
        let now = Date()
        let joinWindowExpiresAt = now.addingTimeInterval(joinWindowSeconds)
        
        // Update match to ready
        struct UpdateMatchRecord: Encodable {
            let remote_status: String
            let join_window_expires_at: String
            let updated_at: String
        }
        
        let updateRecord = UpdateMatchRecord(
            remote_status: "ready",
            join_window_expires_at: ISO8601DateFormatter().string(from: joinWindowExpiresAt),
            updated_at: ISO8601DateFormatter().string(from: now)
        )
        
        try await supabaseService.client
            .from("matches")
            .update(updateRecord)
            .eq("id", value: matchId.uuidString)
            .execute()
        
        // Create locks for both users
        try await createLocks(
            matchId: matchId,
            challengerId: match.challengerId,
            receiverId: match.receiverId,
            lockStatus: "ready"
        )
        
        print("✅ Challenge accepted: \(matchId)")
        
        // TODO: Trigger push notification to challenger
    }
    
    // MARK: - Cancel Match
    
    /// Cancel a match
    func cancelMatch(matchId: UUID, currentUserId: UUID) async throws {
        // Load the match
        let match: RemoteMatch = try await supabaseService.client
            .from("matches")
            .select()
            .eq("id", value: matchId.uuidString)
            .single()
            .execute()
            .value
        
        // Validate user is challenger or receiver
        guard match.challengerId == currentUserId || match.receiverId == currentUserId else {
            throw RemoteMatchError.notAuthorized
        }
        
        // Update match to cancelled
        struct UpdateMatchRecord: Encodable {
            let remote_status: String
            let updated_at: String
        }
        
        let updateRecord = UpdateMatchRecord(
            remote_status: "cancelled",
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await supabaseService.client
            .from("matches")
            .update(updateRecord)
            .eq("id", value: matchId.uuidString)
            .execute()
        
        // Clear locks
        try await clearLocks(matchId: matchId)
        
        print("✅ Match cancelled: \(matchId)")
    }
    
    // MARK: - Join Match
    
    /// Join a ready match
    func joinMatch(matchId: UUID, currentUserId: UUID) async throws {
        // Load the match
        let match: RemoteMatch = try await supabaseService.client
            .from("matches")
            .select()
            .eq("id", value: matchId.uuidString)
            .single()
            .execute()
            .value
        
        // Validate user is challenger or receiver
        guard match.challengerId == currentUserId || match.receiverId == currentUserId else {
            throw RemoteMatchError.notAuthorized
        }
        
        // Validate status is ready
        guard match.status == RemoteMatchStatus.ready else {
            throw RemoteMatchError.invalidStatus
        }
        
        // Check not expired
        if let expiresAt = match.joinWindowExpiresAt, Date() > expiresAt {
            throw RemoteMatchError.matchExpired
        }
        
        // Transition to lobby (first player) or in_progress (second player)
        // For now, always transition to in_progress for simplicity
        let newStatus = "in_progress"
        let currentPlayerId = match.challengerId // Challenger goes first
        
        struct UpdateMatchRecord: Encodable {
            let remote_status: String
            let current_player_id: String
            let updated_at: String
        }
        
        let updateRecord = UpdateMatchRecord(
            remote_status: newStatus,
            current_player_id: currentPlayerId.uuidString,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await supabaseService.client
            .from("matches")
            .update(updateRecord)
            .eq("id", value: matchId.uuidString)
            .execute()
        
        // Update locks from 'ready' to 'in_progress'
        try await clearLocks(matchId: matchId)
        try await createLocks(
            matchId: matchId,
            challengerId: match.challengerId,
            receiverId: match.receiverId,
            lockStatus: "in_progress"
        )
        
        print("✅ Match joined: \(matchId), status: \(newStatus)")
    }
    
    // MARK: - Lock Management
    
    private func checkUserHasLock(userId: UUID) async throws -> Bool {
        // Simple approach: just check if user has any locks
        // The expired challenge cleanup should happen elsewhere
        let locks: [RemoteMatchLock] = try await supabaseService.client
            .from("remote_match_locks")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value
        
        print("🔍 Found \(locks.count) locks for user \(userId)")
        
        return !locks.isEmpty
    }
    
    private func createLocks(
        matchId: UUID,
        challengerId: UUID,
        receiverId: UUID,
        lockStatus: String
    ) async throws {
        struct LockRecord: Encodable {
            let user_id: String
            let match_id: String
            let lock_status: String
        }
        
        let locks = [
            LockRecord(
                user_id: challengerId.uuidString,
                match_id: matchId.uuidString,
                lock_status: lockStatus
            ),
            LockRecord(
                user_id: receiverId.uuidString,
                match_id: matchId.uuidString,
                lock_status: lockStatus
            )
        ]
        
        try await supabaseService.client
            .from("remote_match_locks")
            .insert(locks)
            .execute()
        
        print("🔒 Locks created for match: \(matchId)")
    }
    
    private func clearLocks(matchId: UUID) async throws {
        try await supabaseService.client
            .from("remote_match_locks")
            .delete()
            .eq("match_id", value: matchId.uuidString)
            .execute()
        
        print("🔓 Locks cleared for match: \(matchId)")
    }
    
    // MARK: - Realtime Subscription
    
    func setupRealtimeSubscription(userId: UUID) async {
        print("🔵 [RemoteMatch Realtime] Setting up subscription for user: \(userId)")
        
        // Remove existing subscription
        await removeRealtimeSubscription()
        
        let channelName = "remote_matches:\(userId.uuidString)"
        let channel = supabaseService.client.realtimeV2.channel(channelName)
        
        // Listen for changes to matches where user is involved
        _ = channel.onPostgresChange(
            AnyAction.self,
            schema: "public",
            table: "matches",
            filter: "match_mode=eq.remote"
        ) { [weak self] action in
            Task { @MainActor in
                print("🔵 [RemoteMatch Realtime] Received change: \(action)")
                // Reload matches when any change occurs
                try? await self?.loadMatches(userId: userId)
            }
        }
        
        await channel.subscribe()
        self.realtimeChannel = channel
        
        print("✅ [RemoteMatch Realtime] Subscription active")
    }
    
    func removeRealtimeSubscription() async {
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            self.realtimeChannel = nil
            print("🔵 [RemoteMatch Realtime] Subscription removed")
        }
    }
}
