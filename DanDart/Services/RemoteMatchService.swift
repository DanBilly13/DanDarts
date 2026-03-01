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
    
    // MARK: - Flow Gate (Depth-based)
    
    @Published private(set) var isInRemoteFlow: Bool = false
    @Published private(set) var flowMatchId: UUID? = nil
    @Published private(set) var flowMatch: RemoteMatch? = nil
    private var remoteFlowDepth: Int = 0
    
    // MARK: - Realtime Subscription Tokens
    
    // Retain subscription tokens so callbacks stay alive (critical!)
    private var insertSubscription: RealtimeSubscription?
    private var updateSubscription: RealtimeSubscription?
    private var statusSubscription: RealtimeSubscription?
    private var pingSubscription: RealtimeSubscription?
    
    // MARK: - Throttling
    
    private var pendingReloads: [UUID: Task<Void, Never>] = [:]
    private var pendingFlowFetches: [UUID: Task<Void, Never>] = [:]
    private let reloadThrottleMs = 400
    private let flowFetchThrottleMs = 250
    
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
    
    // MARK: - Flow Gate Methods
    
    @MainActor
    func enterRemoteFlow(matchId: UUID, initialMatch: RemoteMatch? = nil) {
        remoteFlowDepth += 1
        flowMatchId = matchId
        if let initialMatch {
            flowMatch = initialMatch
        }
        if isInRemoteFlow == false {
            isInRemoteFlow = true
            print("🚦 [FlowGate] ENTER depth=\(remoteFlowDepth) match=\(matchId.uuidString.prefix(8))")
        } else {
            print("🚦 [FlowGate] ENTER depth=\(remoteFlowDepth) match=\(matchId.uuidString.prefix(8))")
        }
    }
    
    @MainActor
    func exitRemoteFlow() {
        remoteFlowDepth = max(0, remoteFlowDepth - 1)
        print("🚦 [FlowGate] EXIT depth=\(remoteFlowDepth)")
        if remoteFlowDepth == 0 {
            isInRemoteFlow = false
            flowMatchId = nil
            flowMatch = nil
            print("🚦 [FlowGate] isInRemoteFlow = false (depth=0)")
        }
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
            case .lobby:
                // For lobby state, check if current user has joined
                // If not joined → show as ready (challenger waiting to join)
                // If joined → show as active (user is in lobby)
                // Check synchronously to ensure activeMatch is set before loadMatches returns
                let hasJoined = await checkIfUserJoinedMatch(matchId: match.id, userId: userId)
                await MainActor.run {
                    if hasJoined {
                        active = matchWithPlayers
                    } else {
                        ready.append(matchWithPlayers)
                    }
                }
            case .inProgress:
                active = matchWithPlayers
            case .cancelled, .completed, .expired:
                // Terminal states - don't show in any list
                // Cancelled: receiver declined it, or user cancelled their own challenge
                // Completed/Expired: match is finished
                // Either way, exclude from active lists
                break
            }
        }
        
        // Debug logging to confirm filtering
        print("🧹 Filtered lists - Pending: \(pending.count), Sent: \(sent.count), Ready: \(ready.count)")
        print("🧹 Sent challenges:", sent.map { "\($0.match.id.uuidString.prefix(8))... status=\($0.match.status?.rawValue ?? "nil")" })
        
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
    
    // MARK: - Fetch Match
    
    /// Fetch a single match from the database with fresh data
    func fetchMatch(matchId: UUID) async throws -> RemoteMatch? {
        struct MatchResponse: Decodable {
            let id: UUID
            let match_mode: String
            let game_type: String
            let match_format: Int?
            let remote_status: String?
            let challenger_id: UUID
            let receiver_id: UUID
            let challenge_expires_at: String?
            let join_window_expires_at: String?
            let created_at: String
            let updated_at: String
            let ended_by: UUID?
            let ended_reason: String?
            let debug_counter: Int?
        }
        
        print("🔍 fetchMatch(matchId=\(matchId.uuidString.prefix(8))...)")
        
        let response: [MatchResponse] = try await supabaseService.client
            .from("matches")
            .select()
            .eq("id", value: matchId.uuidString)
            .execute()
            .value
        
        guard let matchData = response.first else {
            print("❌ Match not found: \(matchId.uuidString.prefix(8))...")
            return nil
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let match = RemoteMatch(
            id: matchData.id,
            matchMode: matchData.match_mode,
            gameType: matchData.game_type,
            gameName: matchData.game_type.replacingOccurrences(of: "_", with: " ").capitalized,
            matchFormat: matchData.match_format ?? 1,
            challengerId: matchData.challenger_id,
            receiverId: matchData.receiver_id,
            status: RemoteMatchStatus(rawValue: matchData.remote_status ?? ""),
            currentPlayerId: nil,
            challengeExpiresAt: matchData.challenge_expires_at.flatMap { formatter.date(from: $0) },
            joinWindowExpiresAt: matchData.join_window_expires_at.flatMap { formatter.date(from: $0) },
            lastVisitPayload: nil,
            createdAt: formatter.date(from: matchData.created_at) ?? Date(),
            updatedAt: formatter.date(from: matchData.updated_at) ?? Date(),
            endedBy: matchData.ended_by,
            endedReason: matchData.ended_reason,
            debugCounter: matchData.debug_counter
        )
        
        print("✅ fetched status=\(match.status?.rawValue ?? "nil")")
        
        // Update flowMatch if this is the flow match (KEY FIX for Lobby UI)
        await MainActor.run {
            if self.flowMatchId == matchId {
                self.flowMatch = match
                print("🎯 [Flow] flowMatch updated status=\(match.status?.rawValue ?? "nil")")
            }
        }
        
        // Update activeMatch if this is the active match
        if let activeMatch = self.activeMatch, activeMatch.match.id == matchId {
            // Reuse existing User data to avoid unnecessary fetches
            let updatedMatch = RemoteMatchWithPlayers(
                match: match,
                challenger: activeMatch.challenger,
                receiver: activeMatch.receiver,
                currentUserId: activeMatch.currentUserId
            )
            
            await MainActor.run {
                self.activeMatch = updatedMatch
                print("🔄 activeMatch updated with fresh data")
            }
        }
        
        return match
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
        
        // Log request details
        print("🔍 [CancelChallenge] ========================================")
        print("🔍 [CancelChallenge] Calling cancel-match Edge Function")
        print("🔍 [CancelChallenge] Match ID: \(matchId)")
        print("🔍 [CancelChallenge] Request payload: match_id=\(request.match_id)")
        print("🔍 [CancelChallenge] Headers: apikey=\(headers["apikey"]?.prefix(20) ?? "nil")...")
        print("🔍 [CancelChallenge] Auth token: \(headers["Authorization"]?.prefix(30) ?? "nil")...")
        
        do {
            let _: EmptyResponse = try await supabaseService.client.functions
                .invoke("cancel-match", options: FunctionInvokeOptions(
                    headers: headers,
                    body: request
                ))
            
            print("✅ [CancelChallenge] Challenge cancelled: \(matchId)")
            print("🔍 [CancelChallenge] ========================================")
        } catch let error as FunctionsError {
            // Detailed error logging
            print("❌ [CancelChallenge] Edge Function error:")
            print("❌ [CancelChallenge] Error type: \(error)")
            
            // Try to extract response body
            if case .httpError(let code, let data) = error {
                print("❌ [CancelChallenge] HTTP Code: \(code)")
                print("❌ [CancelChallenge] Response data size: \(data.count) bytes")
                
                // Decode response body as string
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ [CancelChallenge] Response body: \(responseString)")
                } else {
                    print("❌ [CancelChallenge] Response body (hex): \(data.map { String(format: "%02x", $0) }.joined())")
                }
            }
            
            print("🔍 [CancelChallenge] ========================================")
            throw error
        } catch {
            print("❌ [CancelChallenge] Unexpected error: \(error)")
            throw error
        }
    }
    
    /// Abort a match in lobby or in_progress state (calls Edge Function)
    func abortMatch(matchId: UUID) async throws {
        struct AbortRequest: Encodable {
            let match_id: String
        }
        
        let request = AbortRequest(match_id: matchId.uuidString)
        let headers = try await getEdgeFunctionHeaders()
        
        // Log request details
        print("🟠 [AbortMatch] ========================================")
        print("🟠 [AbortMatch] Calling abort-match Edge Function")
        print("🟠 [AbortMatch] Match ID: \(matchId)")
        print("🟠 [AbortMatch] Request payload: match_id=\(request.match_id)")
        print("🟠 [AbortMatch] Headers: apikey=\(headers["apikey"]?.prefix(20) ?? "nil")...")
        print("🟠 [AbortMatch] Auth token: \(headers["Authorization"]?.prefix(30) ?? "nil")...")
        
        do {
            let _: EmptyResponse = try await supabaseService.client.functions
                .invoke("abort-match", options: FunctionInvokeOptions(
                    headers: headers,
                    body: request
                ))
            
            print("✅ [AbortMatch] Match aborted: \(matchId)")
            print("🟠 [AbortMatch] ========================================")
        } catch let error as FunctionsError {
            // Detailed error logging
            print("❌ [AbortMatch] Edge Function error:")
            print("❌ [AbortMatch] Error type: \(error)")
            
            // Try to extract response body
            if case .httpError(let code, let data) = error {
                print("❌ [AbortMatch] HTTP Code: \(code)")
                print("❌ [AbortMatch] Response data size: \(data.count) bytes")
                
                // Decode response body as string
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ [AbortMatch] Response body: \(responseString)")
                } else {
                    print("❌ [AbortMatch] Response body (hex): \(data.map { String(format: "%02x", $0) }.joined())")
                }
            }
            
            print("🟠 [AbortMatch] ========================================")
            throw error
        } catch {
            print("❌ [AbortMatch] Unexpected error: \(error)")
            print("🟠 [AbortMatch] ========================================")
            throw error
        }
    }
    
    /// Delete an expired match from the database
    func deleteExpiredMatch(matchId: UUID) async throws {
        try await supabaseService.client
            .from("matches")
            .delete()
            .eq("id", value: matchId.uuidString)
            .execute()
        
        print("🗑️ Deleted expired match from database: \(matchId)")
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
    
    // MARK: - Expire Match
    
    /// Expire a match (calls Edge Function for client-triggered expiration)
    func expireMatch(matchId: UUID) async throws {
        let headers = try await getEdgeFunctionHeaders()
        
        struct ExpireRequest: Encodable {
            let match_id: String
        }
        
        let request = ExpireRequest(match_id: matchId.uuidString)
        let data = try JSONEncoder().encode(request)
        
        struct EmptyResponse: Decodable {}
        
        let _: EmptyResponse = try await supabaseService.client.functions
            .invoke("expire-match", options: FunctionInvokeOptions(
                headers: headers,
                body: data
            ))
        
        print("✅ Match expired via client: \(matchId)")
    }
    
    // MARK: - Join Match
    
    /// Join a ready match (calls Edge Function)
    func joinMatch(matchId: UUID, currentUserId: UUID) async throws {
        struct JoinRequest: Encodable {
            let match_id: String
        }
        
        let request = JoinRequest(match_id: matchId.uuidString)
        
        print("🔍 Getting headers for join-match...")
        let headers = try await getEdgeFunctionHeaders()
        print("📋 Headers to send:")
        print("   - apikey: \(String(headers["apikey"]?.prefix(20) ?? "MISSING"))...")
        print("   - Authorization: \(String(headers["Authorization"]?.prefix(30) ?? "MISSING"))...")
        
        print("🚀 Calling join-match with match_id: \(matchId), currentUserId: \(currentUserId)")
        
        do {
            let _: EmptyResponse = try await supabaseService.client.functions
                .invoke("join-match", options: FunctionInvokeOptions(
                    headers: headers,
                    body: request
                ))
            
            print("✅ Match joined: \(matchId)")
        } catch {
            print("❌ join-match Edge Function failed:")
            print("   - Error: \(error)")
            print("   - Error type: \(type(of: error))")
            print("   - Localized description: \(error.localizedDescription)")
            
            // Try to extract more details from the error
            if let functionError = error as? FunctionsError {
                print("   - FunctionsError details: \(functionError)")
                
                // Extract response body if available
                switch functionError {
                case .httpError(let code, let data):
                    print("   - HTTP Status Code: \(code)")
                    if let bodyString = String(data: data, encoding: .utf8) {
                        print("   - Response Body: \(bodyString)")
                    } else {
                        print("   - Response Body: <non-utf8 data>")
                    }
                default:
                    break
                }
            }
            
            throw error
        }
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
    
    private func checkIfUserJoinedMatch(matchId: UUID, userId: UUID) async -> Bool {
        do {
            struct MatchPlayer: Decodable {
                let player_user_id: UUID?
            }
            
            let players: [MatchPlayer] = try await supabaseService.client
                .from("match_players")
                .select("player_user_id")
                .eq("match_id", value: matchId.uuidString)
                .eq("player_user_id", value: userId.uuidString)
                .execute()
                .value
            
            return !players.isEmpty
        } catch {
            print("❌ Error checking if user joined match: \(error)")
            return false
        }
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
    
    // MARK: - Throttling Methods
    
    @MainActor
    private func scheduleListReload(userId: UUID) {
        pendingReloads[userId]?.cancel()
        let task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(reloadThrottleMs))
            guard !Task.isCancelled, let self else { return }
            guard self.isInRemoteFlow == false else {
                print("⏭️ [Realtime] Skipping loadMatches (in remote flow)")
                return
            }
            print("🔄 [Realtime] loadMatches (throttled) user=\(userId.uuidString.prefix(8))")
            try? await self.loadMatches(userId: userId)
            print("✅ [Realtime] loadMatches complete")
            self.pendingReloads.removeValue(forKey: userId)
        }
        pendingReloads[userId] = task
    }
    
    @MainActor
    private func scheduleFlowMatchFetch(matchId: UUID) {
        pendingFlowFetches[matchId]?.cancel()
        let task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(flowFetchThrottleMs))
            guard !Task.isCancelled, let self else { return }
            
            // Only fetch if we are in remote flow AND this signal is for the flow match
            guard self.isInRemoteFlow, self.flowMatchId == matchId else {
                self.pendingFlowFetches.removeValue(forKey: matchId)
                return
            }
            
            print("🔄 [Realtime] fetchMatch(flow) match=\(matchId.uuidString.prefix(8))")
            _ = try? await self.fetchMatch(matchId: matchId)
            print("✅ [Realtime] fetchMatch(flow) complete")
            self.pendingFlowFetches.removeValue(forKey: matchId)
        }
        pendingFlowFetches[matchId] = task
    }
    
    // MARK: - Realtime Subscription
    
    func setupRealtimeSubscription(userId: UUID) async {
        print("🔵 [RemoteMatch Realtime] ========================================")
        print("🔵 [RemoteMatch Realtime] SETUP START for user: \(userId)")
        print("🔵 [RemoteMatch Realtime] Current channel exists: \(realtimeChannel != nil)")
        
        // Remove existing subscription first
        await removeRealtimeSubscription()
        print("🔵 [RemoteMatch Realtime] Old subscription removed")
        
        // Create channel - use simple format like FriendsService
        let channelName = "public:matches"
        print("🔵 [RemoteMatch Realtime] Creating channel: \(channelName)")
        let channel = supabaseService.client.realtimeV2.channel(channelName) {
            $0.broadcast.receiveOwnBroadcasts = true
        }
        print("🔵 [RemoteMatch Realtime] Channel created")
        
        // Listen for INSERT events (NO server-side filter - client-side filtering is more reliable)
        print("🔵 [RemoteMatch Realtime] Registering INSERT callback (client-side filtering)")
        insertSubscription = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "matches"
        ) { [weak self] action in
            // CRITICAL: Log INSIDE callback to prove events are arriving
            print("🟢🟢🟢 [RemoteMatch Realtime] ========================================")
            print("🟢🟢🟢 [RemoteMatch Realtime] INSERT CALLBACK FIRED!!!")
            print("🟢🟢🟢 [RemoteMatch Realtime] Payload: \(action.record)")
            print("🟢🟢🟢 [RemoteMatch Realtime] Thread: \(Thread.current)")
            print("🟢🟢🟢 [RemoteMatch Realtime] Timestamp: \(Date())")
            print("🟢🟢🟢 [RemoteMatch Realtime] ========================================")
            
            // Client-side filter: only process remote matches for this user
            let record = action.record
            guard
                let matchMode = record["match_mode"]?.stringValue,
                matchMode == "remote",
                let challengerIdString = record["challenger_id"]?.stringValue,
                let receiverIdString = record["receiver_id"]?.stringValue,
                let challengerId = UUID(uuidString: challengerIdString),
                let receiverId = UUID(uuidString: receiverIdString),
                challengerId == userId || receiverId == userId
            else {
                print("🟢 [RemoteMatch Realtime] Skipping - not for user \(userId)")
                return
            }
            
            print("🟢 [RemoteMatch Realtime] Processing - event is for current user!")
            
            // Extract matchId for targeted updates
            guard let matchIdString = record["id"]?.stringValue,
                  let matchId = UUID(uuidString: matchIdString) else {
                print("🟢 [RemoteMatch Realtime] No valid matchId in payload")
                return
            }
            
            Task { @MainActor in
                // Safe in flow even if activeMatch is nil (uses flowMatchId)
                self?.scheduleFlowMatchFetch(matchId: matchId)
                
                // Will no-op if in remote flow
                self?.scheduleListReload(userId: userId)
                
                // Keep badge notification
                NotificationCenter.default.post(
                    name: NSNotification.Name("RemoteChallengesChanged"),
                    object: nil
                )
                print("🟢 [RemoteMatch Realtime] RemoteChallengesChanged notification posted")
            }
        }
        
        // Listen for UPDATE events (client-side filtering)
        print("🔵 [RemoteMatch Realtime] Registering UPDATE callback (client-side filtering)")
        updateSubscription = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "matches"
        ) { [weak self] action in
            // CRITICAL: Log INSIDE callback to prove events are arriving
            print("🚨🚨🚨 [RemoteMatch Realtime] ========================================")
            print("🚨🚨🚨 [RemoteMatch Realtime] UPDATE CALLBACK FIRED!!!")
            print("🚨🚨🚨 [RemoteMatch Realtime] Payload: \(action.record)")
            print("🚨🚨🚨 [RemoteMatch Realtime] Thread: \(Thread.current)")
            print("🚨🚨🚨 [RemoteMatch Realtime] Timestamp: \(Date())")
            print("🚨🚨🚨 [RemoteMatch Realtime] ========================================")
            
            // Client-side filter: only process remote matches for this user
            let record = action.record
            guard
                let matchMode = record["match_mode"]?.stringValue,
                matchMode == "remote",
                let challengerIdString = record["challenger_id"]?.stringValue,
                let receiverIdString = record["receiver_id"]?.stringValue,
                let challengerId = UUID(uuidString: challengerIdString),
                let receiverId = UUID(uuidString: receiverIdString),
                challengerId == userId || receiverId == userId
            else {
                print("🚨 [RemoteMatch Realtime] Skipping - not for user \(userId)")
                return
            }
            
            print("🚨 [RemoteMatch Realtime] Processing - event is for current user!")
            
            // Extract matchId for targeted updates
            guard let matchIdString = record["id"]?.stringValue,
                  let matchId = UUID(uuidString: matchIdString) else {
                print("🚨 [RemoteMatch Realtime] No valid matchId in payload")
                return
            }
            
            Task { @MainActor in
                // Safe in flow even if activeMatch is nil (uses flowMatchId)
                self?.scheduleFlowMatchFetch(matchId: matchId)
                
                // Will no-op if in remote flow
                self?.scheduleListReload(userId: userId)
                
                // Keep badge notification
                NotificationCenter.default.post(
                    name: NSNotification.Name("RemoteChallengesChanged"),
                    object: nil
                )
                print("🚨 [RemoteMatch Realtime] RemoteChallengesChanged notification posted")
            }
        }
        
        // Monitor channel status changes
        print("🔵 [RemoteMatch Realtime] Setting up status change monitoring...")
        statusSubscription = channel.onStatusChange { status in
            print("🔔 [RemoteMatch Realtime] ========================================")
            print("🔔 [RemoteMatch Realtime] CHANNEL STATUS CHANGED: \(status)")
            print("🔔 [RemoteMatch Realtime] Timestamp: \(Date())")
            print("🔔 [RemoteMatch Realtime] ========================================")
        }
        
        print("🔵 [RemoteMatch Realtime] All callbacks registered, calling subscribe()...")
        
        // Retain the channel before subscribing (prevents accidental deallocation during async subscribe)
        realtimeChannel = channel
        print("🔵 [RemoteMatch Realtime] Channel stored in realtimeChannel property (pre-subscribe)")
        
        // Subscribe to the channel
        do {
            // Register broadcast handler BEFORE subscribing, and retain the subscription token
            pingSubscription = channel.onBroadcast(event: "ping") { message in
                print("📡 [RemoteMatch Realtime] broadcast ping received:", message)
            }
            
            // Use the newer subscribe API that throws errors
            try await channel.subscribeWithError()
            
            // 🔎 Debug: prove the socket can receive *anything*
            struct PingMessage: Codable { let hello: String }
            try? await channel.broadcast(event: "ping", message: PingMessage(hello: "world"))
            print("📡 [RemoteMatch Realtime] broadcast ping sent")
            
            print("✅ [RemoteMatch Realtime] SUBSCRIPTION ACTIVE")
            print("✅ [RemoteMatch Realtime] Channel status: \(channel.status)")
            print("✅ [RemoteMatch Realtime] ========================================")
        } catch {
            print("❌ [RemoteMatch Realtime] Subscribe failed: \(error)")
            print("❌ [RemoteMatch Realtime] ========================================")
        }
    }
    
    func removeRealtimeSubscription() async {
        // Cancel all pending throttled tasks
        await MainActor.run {
            print("🧹 [Realtime] Cancelling \(pendingReloads.count) pending reloads")
            for (_, task) in pendingReloads { task.cancel() }
            pendingReloads.removeAll()
            
            print("🧹 [Realtime] Cancelling \(pendingFlowFetches.count) pending flow fetches")
            for (_, task) in pendingFlowFetches { task.cancel() }
            pendingFlowFetches.removeAll()
        }
        
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            self.realtimeChannel = nil
            print("🔵 [RemoteMatch Realtime] Subscription removed")
        }
    }
    
    // MARK: - Badge Count
    
    /// Get count of pending incoming challenges
    /// - Parameter userId: Current user's ID
    /// - Returns: Count of pending incoming challenges
    func getPendingChallengeCount(userId: UUID) async throws -> Int {
        // Query matches where user is receiver and status is pending
        let matches: [RemoteMatch] = try await supabaseService.client
            .from("matches")
            .select()
            .eq("match_mode", value: "remote")
            .eq("receiver_id", value: userId.uuidString)
            .eq("remote_status", value: "pending")
            .execute()
            .value
        
        return matches.count
    }
    
    // MARK: - Debug Counter (Phase 2 Testing)
    
    #if DEBUG
    /// Increment the debug counter for a match (Phase 2 testing only)
    func bumpDebugCounter(matchId: UUID) async throws {
        print("🔧 [DEBUG] Bumping debug counter - matchId: \(matchId.uuidString.prefix(8))...")
        
        // Use Postgres function to atomically increment the counter
        // This ensures we don't have race conditions if both devices bump simultaneously
        try await supabaseService.client
            .rpc("increment_debug_counter", params: ["match_id": matchId.uuidString])
            .execute()
        
        print("✅ [DEBUG] Debug counter bumped successfully")
    }
    #endif
}
