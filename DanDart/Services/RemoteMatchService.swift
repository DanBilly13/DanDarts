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
    private let voiceChatService = VoiceChatService.shared
    
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
    
    // MARK: - Pending Enter Flow Latch (UI smoothing)
    
    @Published private(set) var pendingEnterFlowMatchIds: Set<UUID> = []
    private var enterFlowClearTasks: [UUID: Task<Void, Never>] = [:]
    
    // MARK: - Navigation In-Flight Guard (prevents multi-frame navigation)
    
    @Published var navInFlightMatchId: UUID? = nil
    @Published var navToken: UUID = UUID()
    
    // MARK: - Processing State (centralized enter-flow tracking)
    
    @Published var processingMatchId: UUID? = nil
    
    var isEnteringFlow: Bool { processingMatchId != nil }
    
    // MARK: - In-Flight Fetch Guard (prevents duplicate network calls)
    
    private var inFlightFetch: Task<RemoteMatch?, Error>?
    private var inFlightMatchId: UUID?
    
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
    
    // MARK: - Accept Presentation Freeze (UI Override)
    
    private(set) var acceptPresentationFrozenMatchIds: Set<UUID> = []
    
    func beginAcceptPresentationFreeze(matchId: UUID) {
        acceptPresentationFrozenMatchIds.insert(matchId)
        FlowDebug.log("ACCEPT_UI_FREEZE: BEGIN", matchId: matchId)
    }
    
    func clearAcceptPresentationFreeze(matchId: UUID) {
        let wasPresent = acceptPresentationFrozenMatchIds.remove(matchId) != nil
        if wasPresent {
            FlowDebug.log("ACCEPT_UI_FREEZE: CLEAR", matchId: matchId)
        }
    }
    
    func isAcceptPresentationFrozen(matchId: UUID) -> Bool {
        return acceptPresentationFrozenMatchIds.contains(matchId)
    }
    
    // MARK: - Debug Instrumentation
    
    private var loadMatchesRunCounter = 0
    
    /// Dump complete state snapshot for debugging
    @MainActor
    func dumpStateSnapshot(reason: String, matchId: UUID?) {
        let flowMatchIdStr = flowMatchId?.uuidString.prefix(8) ?? "none"
        let flowMatchStatus = flowMatch?.status?.rawValue ?? "nil"
        let pendingIds = pendingChallenges.map { String($0.match.id.uuidString.prefix(8)) }.joined(separator: ",")
        let readyIds = readyMatches.map { String($0.match.id.uuidString.prefix(8)) }.joined(separator: ",")
        let sentIds = sentChallenges.map { String($0.match.id.uuidString.prefix(8)) }.joined(separator: ",")
        let activeId = activeMatch.map { String($0.match.id.uuidString.prefix(8)) } ?? "none"
        let navInFlightId = navInFlightMatchId?.uuidString.prefix(8) ?? "none"
        let processingId = processingMatchId?.uuidString.prefix(8) ?? "none"
        
        FlowDebug.log("SNAPSHOT: reason=\(reason)", matchId: matchId)
        FlowDebug.log("SNAPSHOT: flowMatch id=\(flowMatchIdStr) status=\(flowMatchStatus)", matchId: matchId)
        FlowDebug.log("SNAPSHOT: pending=[\(pendingIds)] ready=[\(readyIds)] sent=[\(sentIds)] active=\(activeId)", matchId: matchId)
        FlowDebug.log("SNAPSHOT: isEnteringFlow=\(isEnteringFlow) isInRemoteFlow=\(isInRemoteFlow)", matchId: matchId)
        FlowDebug.log("SNAPSHOT: navInFlight=\(navInFlightId) processing=\(processingId)", matchId: matchId)
    }
    
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
            let oldStatus = flowMatch?.status?.rawValue ?? "nil"
            let newStatus = initialMatch.status?.rawValue ?? "nil"
            FlowDebug.log("FLOW_MATCH: SET reason=enterRemoteFlow old.status=\(oldStatus) new.status=\(newStatus)", matchId: matchId)
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
            let oldMatchId = flowMatchId
            let oldStatus = flowMatch?.status?.rawValue ?? "nil"
            FlowDebug.log("FLOW_MATCH: CLEAR reason=exitRemoteFlow old.status=\(oldStatus)", matchId: oldMatchId)
            isInRemoteFlow = false
            flowMatchId = nil
            flowMatch = nil
            print("🚦 [FlowGate] isInRemoteFlow = false (depth=0)")
            
            // End voice session on true flow exit
            Task {
                await voiceChatService.endSession()
                print("✅ [FlowGate] Voice session ended on flow exit")
            }
            
            // Refresh match lists to filter out completed/cancelled matches
            // Add delay to allow database replication to complete
            Task {
                guard let userId = await authService.currentUser?.id else { return }
                let startTime = Date()
                print("🔄 [FlowGate] Refreshing match lists after flow exit (with 500ms delay) at \(startTime)")
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
                let executeTime = Date()
                let delay = executeTime.timeIntervalSince(startTime)
                print("🔄 [FlowGate] Executing delayed loadMatches() at \(executeTime) (actual delay: \(String(format: "%.3f", delay))s)")
                try? await loadMatches(userId: userId)
                print("🔄 [FlowGate] Delayed loadMatches() complete")
            }
        }
    }
    
    // MARK: - Pending Enter Flow Latch Methods
    
    @MainActor
    func beginPendingEnterFlow(matchId: UUID) {
        FlowDebug.log("EnterFlowLatch BEGIN", matchId: matchId)
        
        pendingEnterFlowMatchIds.insert(matchId)
        
        // Cancel any existing auto-clear task
        enterFlowClearTasks[matchId]?.cancel()
        
        // Longer TTL to cover accept + join + fetch + push (10s)
        enterFlowClearTasks[matchId] = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10s
                FlowDebug.log("EnterFlowLatch AUTO-CLEAR (TTL)", matchId: matchId)
                pendingEnterFlowMatchIds.remove(matchId)
                enterFlowClearTasks[matchId] = nil
            } catch {
                // cancelled
            }
        }
    }
    
    @MainActor
    func clearPendingEnterFlow(matchId: UUID) {
        FlowDebug.log("EnterFlowLatch CLEAR", matchId: matchId)
        pendingEnterFlowMatchIds.remove(matchId)
        enterFlowClearTasks[matchId]?.cancel()
        enterFlowClearTasks[matchId] = nil
    }
    
    @MainActor
    func refreshPendingEnterFlow(matchId: UUID) {
        FlowDebug.log("EnterFlowLatch REFRESH", matchId: matchId)
        beginPendingEnterFlow(matchId: matchId)
    }
    
    @MainActor
    func isPendingEnterFlow(matchId: UUID) -> Bool {
        pendingEnterFlowMatchIds.contains(matchId)
    }
    
    @MainActor
    func debugPresentationStatus(_ match: RemoteMatch) -> RemoteMatchStatus {
        let entering = isPendingEnterFlow(matchId: match.id)
        let raw = match.status ?? .pending
        let pres: RemoteMatchStatus = entering ? .pending : raw
        if entering && raw != .pending {
            FlowDebug.log("LIST FREEZE active raw=\(raw.rawValue) -> pres=\(pres.rawValue)", matchId: match.id)
        }
        return pres
    }
    
    @MainActor
    func setNavInFlight(_ matchId: UUID) {
        navInFlightMatchId = matchId
        navToken = UUID()
        FlowDebug.log("NAV IN-FLIGHT SET", matchId: matchId)
    }
    
    @MainActor
    func clearNavInFlight(matchId: UUID) {
        if navInFlightMatchId == matchId {
            navInFlightMatchId = nil
            FlowDebug.log("NAV IN-FLIGHT CLEAR", matchId: matchId)
        }
    }
    
    @MainActor
    func beginEnterFlow(matchId: UUID) {
        FlowDebug.log("BEGIN ENTER FLOW (all state)", matchId: matchId)
        processingMatchId = matchId
        beginPendingEnterFlow(matchId: matchId)
        setNavInFlight(matchId)
    }
    
    @MainActor
    func endEnterFlow(matchId: UUID) {
        FlowDebug.log("END ENTER FLOW (clear all)", matchId: matchId)
        clearPendingEnterFlow(matchId: matchId)
        clearNavInFlight(matchId: matchId)
        if processingMatchId == matchId {
            processingMatchId = nil
        }
        // Defensive: Clear accept UI freeze if still set
        clearAcceptPresentationFreeze(matchId: matchId)
    }
    
    // MARK: - Realtime Subscription
    
    private var realtimeChannel: RealtimeChannelV2?
    
    // MARK: - Load Matches
    
    /// Load all remote matches for the current user
    func loadMatches(userId: UUID) async throws {
        // Increment run counter
        await MainActor.run {
            loadMatchesRunCounter += 1
        }
        let runNumber = await MainActor.run { loadMatchesRunCounter }
        
        // CRITICAL: Skip loadMatches while entering flow to prevent list rebuild flash
        let shouldSkip = await MainActor.run { isEnteringFlow }
        if shouldSkip {
            let processingId = await MainActor.run { processingMatchId }
            FlowDebug.log("LOAD: RUN \(runNumber) SKIP reason=enteringFlow", matchId: processingId)
            return
        }
        
        let inRemoteFlow = await MainActor.run { isInRemoteFlow }
        FlowDebug.log("LOAD: RUN \(runNumber) BEGIN inRemoteFlow=\(inRemoteFlow) enteringFlow=false", matchId: nil)
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Query matches where user is challenger or receiver
            let matches: [RemoteMatch] = try await supabaseService.client
                .from("matches")
                .select()
                .eq("match_mode", value: "remote")
                .or("challenger_id.eq.\(userId.uuidString),receiver_id.eq.\(userId.uuidString)")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            FlowDebug.log("LOAD: RUN \(runNumber) QUERY returned \(matches.count) matches", matchId: nil)
            for match in matches {
                let statusStr = match.status?.rawValue ?? "nil"
                let updatedStr = ISO8601DateFormatter().string(from: match.updatedAt)
                FlowDebug.log("LOAD: RUN \(runNumber) RAW match=\(match.id.uuidString.prefix(8)) status=\(statusStr) updated=\(updatedStr)", matchId: match.id)
            }
            
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
                guard let _ = match.status else { continue }
                
                // Use presentation status to freeze list grouping during enter flow
                let status = await MainActor.run { debugPresentationStatus(match) }
                let rawStatus = match.status?.rawValue ?? "nil"
                let presStatus = status.rawValue
                let freezeActive = await MainActor.run { pendingEnterFlowMatchIds.contains(match.id) }
                FlowDebug.log("LOAD: RUN \(runNumber) MAP match=\(match.id.uuidString.prefix(8)) raw=\(rawStatus) -> presented=\(presStatus) freeze=\(freezeActive)", matchId: match.id)
                
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
                    FlowDebug.log("LOAD: RUN \(runNumber) FILTER OUT match=\(match.id.uuidString.prefix(8)) status=\(status.rawValue)", matchId: match.id)
                    break
                }
            }
            
            // Publish arrays with detailed logging
            let pendingIds = pending.map { String($0.match.id.uuidString.prefix(8)) }.joined(separator: ",")
            let readyIds = ready.map { String($0.match.id.uuidString.prefix(8)) }.joined(separator: ",")
            let sentIds = sent.map { String($0.match.id.uuidString.prefix(8)) }.joined(separator: ",")
            let activeId = active.map { String($0.match.id.uuidString.prefix(8)) } ?? "none"
            
            FlowDebug.log("LOAD: RUN \(runNumber) PUBLISH pending=[\(pendingIds)] ready=[\(readyIds)] sent=[\(sentIds)] active=\(activeId)", matchId: nil)
            
            self.pendingChallenges = pending
            self.sentChallenges = sent
            self.readyMatches = ready
            self.activeMatch = active
            
        } catch {
            FlowDebug.log("LOAD: RUN \(runNumber) ERROR \(error.localizedDescription)", matchId: nil)
            // Clear lists to prevent stale UI state from persisting
            await MainActor.run {
                self.pendingChallenges = []
                self.sentChallenges = []
                self.readyMatches = []
                self.activeMatch = nil
            }
            throw error
        }
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
        // If already fetching this exact match, join the in-flight task
        if let inFlightMatchId = inFlightMatchId,
           inFlightMatchId == matchId,
           let inFlightFetch = inFlightFetch {
            print("🔗 [fetchMatch] JOIN (reused in-flight) match=\(matchId.uuidString.prefix(8))...")
            return try await inFlightFetch.value
        }
        
        // Create new fetch task
        let task = Task<RemoteMatch?, Error> {
            try await _fetchMatchImpl(matchId: matchId)
        }
        
        inFlightFetch = task
        inFlightMatchId = matchId
        
        do {
            let result = try await task.value
            // Clear in-flight state on completion
            if inFlightMatchId == matchId {
                inFlightFetch = nil
                inFlightMatchId = nil
            }
            return result
        } catch {
            // Clear in-flight state on error
            if inFlightMatchId == matchId {
                inFlightFetch = nil
                inFlightMatchId = nil
            }
            throw error
        }
    }
    
    /// Internal implementation of fetchMatch (called by public wrapper)
    private func _fetchMatchImpl(matchId: UUID) async throws -> RemoteMatch? {
        struct MatchResponse: Decodable {
            let id: UUID
            let match_mode: String
            let game_type: String
            let match_format: Int?
            let remote_status: String?
            let challenger_id: UUID
            let receiver_id: UUID
            let current_player_id: UUID?
            let player_scores: [String: Int]?  // 🆕 STEP 1: Server-authoritative scores
            let turn_index_in_leg: Int?  // 🆕 Server-authoritative turn counter
            let challenge_expires_at: String?
            let join_window_expires_at: String?
            let challenger_lobby_joined_at: String?  // 🆕 Lobby presence tracking
            let receiver_lobby_joined_at: String?  // 🆕 Lobby presence tracking
            let lobby_countdown_started_at: String?  // 🆕 Lobby countdown tracking
            let lobby_countdown_seconds: Int?  // 🆕 Lobby countdown duration
            let created_at: String
            let updated_at: String
            let ended_by: UUID?
            let ended_reason: String?
            let winner_id: UUID?
            let debug_counter: Int?
            let last_visit_payload: LastVisitPayload?  // 🎯 Pre-Turn Reveal: opponent's last 3 darts
        }
        
        print("🔍 [fetchMatch] START (new request) match=\(matchId.uuidString.prefix(8))...")
        
        // Execute query and decode
        let response: [MatchResponse] = try await supabaseService.client
            .from("matches")
            .select()
            .eq("id", value: matchId.uuidString)
            .execute()
            .value
        
        // 🧪 DEBUG STEP 1: Log response array
        print("🧪 [fetchMatch] Response count: \(response.count)")
        if let first = response.first {
            print("🧪 [fetchMatch] First match id: \(first.id.uuidString.prefix(8))...")
        }
        
        guard let matchData = response.first else {
            print("❌ Match not found: \(matchId.uuidString.prefix(8))...")
            return nil
        }
        
        // 🧪 DEBUG STEP 3: Log last_visit_payload decode
        print("🧪 [fetchMatch DECODED] last_visit_payload=\(matchData.last_visit_payload != nil ? "present" : "nil")")
        if let lvp = matchData.last_visit_payload {
            print("🧪 [fetchMatch DECODED] lvp.timestamp=\(lvp.timestamp)")
            print("🧪 [fetchMatch DECODED] lvp.darts=\(lvp.darts)")
            print("🧪 [fetchMatch DECODED] lvp.playerId=\(lvp.playerId.uuidString.prefix(8))...")
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // 🧪 DEBUG STEP 2: Log decoded fields
        print("🧪 [fetchMatch DECODED] id=\(matchData.id.uuidString.prefix(8))...")
        print("🧪 [fetchMatch DECODED] status=\(matchData.remote_status ?? "nil")")
        print("🧪 [fetchMatch DECODED] current_player_id=\(matchData.current_player_id?.uuidString.prefix(8) ?? "nil")...")
        print("🧪 [fetchMatch DECODED] challenger_id=\(matchData.challenger_id.uuidString.prefix(8))...")
        print("🧪 [fetchMatch DECODED] receiver_id=\(matchData.receiver_id.uuidString.prefix(8))...")
        print("🧪 [fetchMatch DECODED] player_scores=\(matchData.player_scores?.description ?? "nil")")
        print("🧪 [fetchMatch DECODED] turn_index_in_leg=\(matchData.turn_index_in_leg?.description ?? "nil")")
        print("🧪 [fetchMatch DECODED] challenger_lobby_joined_at=\(matchData.challenger_lobby_joined_at ?? "nil")")
        print("🧪 [fetchMatch DECODED] receiver_lobby_joined_at=\(matchData.receiver_lobby_joined_at ?? "nil")")
        print("🧪 [fetchMatch DECODED] lobby_countdown_started_at=\(matchData.lobby_countdown_started_at ?? "nil")")
        print("🧪 [fetchMatch DECODED] lobby_countdown_seconds=\(matchData.lobby_countdown_seconds?.description ?? "nil")")
        
        // Convert player_scores from [String: Int] to [UUID: Int]
        var playerScores: [UUID: Int]? = nil
        if let scoresDict = matchData.player_scores {
            playerScores = Dictionary(uniqueKeysWithValues: scoresDict.compactMap { key, value in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, value)
            })
        }
        
        let match = RemoteMatch(
            id: matchData.id,
            matchMode: matchData.match_mode,
            gameType: matchData.game_type,
            gameName: matchData.game_type.replacingOccurrences(of: "_", with: " ").capitalized,
            matchFormat: matchData.match_format ?? 1,
            challengerId: matchData.challenger_id,
            receiverId: matchData.receiver_id,
            status: RemoteMatchStatus(rawValue: matchData.remote_status ?? ""),
            currentPlayerId: matchData.current_player_id,
            challengeExpiresAt: matchData.challenge_expires_at.flatMap { formatter.date(from: $0) },
            joinWindowExpiresAt: matchData.join_window_expires_at.flatMap { formatter.date(from: $0) },
            lastVisitPayload: matchData.last_visit_payload,  // 🎯 Pre-Turn Reveal: pass through decoded payload
            playerScores: playerScores,  // 🆕 STEP 1: Server-authoritative scores
            turnIndexInLeg: matchData.turn_index_in_leg,  // 🆕 Server-authoritative turn counter
            createdAt: formatter.date(from: matchData.created_at) ?? Date(),
            updatedAt: formatter.date(from: matchData.updated_at) ?? Date(),
            endedBy: matchData.ended_by,
            endedReason: matchData.ended_reason,
            winnerId: matchData.winner_id,
            debugCounter: matchData.debug_counter,
            challengerLobbyJoinedAt: matchData.challenger_lobby_joined_at.flatMap { formatter.date(from: $0) },
            receiverLobbyJoinedAt: matchData.receiver_lobby_joined_at.flatMap { formatter.date(from: $0) },
            lobbyCountdownStartedAt: matchData.lobby_countdown_started_at.flatMap { formatter.date(from: $0) },
            lobbyCountdownSeconds: matchData.lobby_countdown_seconds
        )
        
        print("✅ [fetchMatch] status=\(match.status?.rawValue ?? "nil") currentPlayerId=\(match.currentPlayerId?.uuidString.prefix(8) ?? "nil")...")
        
        // Update flowMatch if this is the flow match (KEY FIX for Lobby UI)
        await MainActor.run {
            if self.flowMatchId == matchId {
                // Only update if data actually changed (prevents SwiftUI churn)
                if self.flowMatch != match {
                    let oldStatus = self.flowMatch?.status?.rawValue ?? "nil"
                    let newStatus = match.status?.rawValue ?? "nil"
                    let oldCp = self.flowMatch?.currentPlayerId?.uuidString.prefix(8) ?? "nil"
                    let newCp = match.currentPlayerId?.uuidString.prefix(8) ?? "nil"
                    let oldChallengerJoined = self.flowMatch?.challengerLobbyJoinedAt != nil
                    let newChallengerJoined = match.challengerLobbyJoinedAt != nil
                    let oldReceiverJoined = self.flowMatch?.receiverLobbyJoinedAt != nil
                    let newReceiverJoined = match.receiverLobbyJoinedAt != nil
                    let oldChallengerViewEntered = self.flowMatch?.challengerLobbyViewEnteredAt != nil
                    let newChallengerViewEntered = match.challengerLobbyViewEnteredAt != nil
                    let oldReceiverViewEntered = self.flowMatch?.receiverLobbyViewEnteredAt != nil
                    let newReceiverViewEntered = match.receiverLobbyViewEnteredAt != nil
                    let oldCountdown = self.flowMatch?.lobbyCountdownStartedAt != nil
                    let newCountdown = match.lobbyCountdownStartedAt != nil
                    
                    FlowDebug.log("FLOW_MATCH: UPDATE reason=fetchMatch old.status=\(oldStatus) new.status=\(newStatus)", matchId: matchId)
                    FlowDebug.log("FLOW_MATCH: UPDATE old.cp=\(oldCp) new.cp=\(newCp)", matchId: matchId)
                    FlowDebug.log("FLOW_MATCH: UPDATE old.challenger_joined=\(oldChallengerJoined) new=\(newChallengerJoined)", matchId: matchId)
                    FlowDebug.log("FLOW_MATCH: UPDATE old.receiver_joined=\(oldReceiverJoined) new=\(newReceiverJoined)", matchId: matchId)
                    FlowDebug.log("FLOW_MATCH: UPDATE old.challenger_view_entered=\(oldChallengerViewEntered) new=\(newChallengerViewEntered)", matchId: matchId)
                    FlowDebug.log("FLOW_MATCH: UPDATE old.receiver_view_entered=\(oldReceiverViewEntered) new=\(newReceiverViewEntered)", matchId: matchId)
                    FlowDebug.log("FLOW_MATCH: UPDATE old.countdown=\(oldCountdown) new=\(newCountdown)", matchId: matchId)
                    
                    self.flowMatch = match
                } else {
                    FlowDebug.log("FLOW_MATCH: SKIP UPDATE reason=unchanged", matchId: matchId)
                }
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
    
    // MARK: - Enter Lobby
    
    /// Enter the lobby and set lobby presence timestamp (calls Edge Function)
    func enterLobby(matchId: UUID) async throws {
        struct EnterLobbyRequest: Encodable {
            let match_id: String
        }
        
        let request = EnterLobbyRequest(match_id: matchId.uuidString)
        let headers = try await getEdgeFunctionHeaders()
        
        print("🚪 [EnterLobby] Calling enter-lobby with match_id: \(matchId)")
        
        let _: EmptyResponse = try await supabaseService.client.functions
            .invoke("enter-lobby", options: FunctionInvokeOptions(
                headers: headers,
                body: request
            ))
        
        print("✅ [EnterLobby] Entered lobby: \(matchId)")
    }
    
    // MARK: - Confirm Lobby View Entered
    
    /// Confirm lobby view entered and potentially start countdown (calls Edge Function)
    func confirmLobbyViewEntered(matchId: UUID) async throws {
        struct ConfirmRequest: Encodable {
            let match_id: String
        }
        
        let request = ConfirmRequest(match_id: matchId.uuidString)
        let headers = try await getEdgeFunctionHeaders()
        
        print("🧩 [ConfirmLobbyView] Calling confirm-lobby-view-entered with match_id: \(matchId)")
        
        let _: EmptyResponse = try await supabaseService.client.functions
            .invoke("confirm-lobby-view-entered", options: FunctionInvokeOptions(
                headers: headers,
                body: request
            ))
        
        print("✅ [ConfirmLobbyView] Lobby view entered confirmed: \(matchId)")
    }
    
    // MARK: - Start Match If Ready
    
    /// Attempt to start match if countdown has elapsed (calls Edge Function)
    func startMatchIfReady(matchId: UUID) async throws {
        struct StartMatchRequest: Encodable {
            let match_id: String
        }
        
        let request = StartMatchRequest(match_id: matchId.uuidString)
        let headers = try await getEdgeFunctionHeaders()
        
        print("🎮 [StartMatch] Calling start-match-if-ready with match_id: \(matchId)")
        
        do {
            let _: EmptyResponse = try await supabaseService.client.functions
                .invoke("start-match-if-ready", options: FunctionInvokeOptions(
                    headers: headers,
                    body: request
                ))
            
            print("✅ [StartMatch] Match started: \(matchId)")
        } catch let error as FunctionsError {
            // Check if countdown not elapsed yet (425 status)
            if case .httpError(let code, let data) = error, code == 425 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("⏳ [StartMatch] Countdown not elapsed yet: \(responseString)")
                }
                throw RemoteMatchError.edgeFunctionError("Countdown not elapsed yet")
            }
            throw error
        }
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
    
    /// Complete a match that has finished naturally with a winner (calls Edge Function)
    func completeMatch(matchId: UUID, winnerId: UUID) async throws {
        struct CompleteRequest: Encodable {
            let match_id: String
            let winner_id: String
        }
        
        let request = CompleteRequest(match_id: matchId.uuidString, winner_id: winnerId.uuidString)
        let headers = try await getEdgeFunctionHeaders()
        
        // Log request details
        print("🏆 [CompleteMatch] ========================================")
        print("🏆 [CompleteMatch] Calling complete-match Edge Function")
        print("🏆 [CompleteMatch] Match ID: \(matchId)")
        print("🏆 [CompleteMatch] Winner ID: \(winnerId)")
        print("🏆 [CompleteMatch] Request payload: match_id=\(request.match_id), winner_id=\(request.winner_id)")
        print("🏆 [CompleteMatch] Headers: apikey=\(headers["apikey"]?.prefix(20) ?? "nil")...")
        print("🏆 [CompleteMatch] Auth token: \(headers["Authorization"]?.prefix(30) ?? "nil")...")
        
        do {
            let _: EmptyResponse = try await supabaseService.client.functions
                .invoke("complete-match", options: FunctionInvokeOptions(
                    headers: headers,
                    body: request
                ))
            
            print("✅ [CompleteMatch] Match completed successfully: \(matchId), winner: \(winnerId)")
            print("🏆 [CompleteMatch] ========================================")
        } catch let error as FunctionsError {
            // Detailed error logging
            print("❌ [CompleteMatch] Edge Function error:")
            print("❌ [CompleteMatch] Error type: \(error)")
            
            // Try to extract response body
            if case .httpError(let code, let data) = error {
                print("❌ [CompleteMatch] HTTP Code: \(code)")
                print("❌ [CompleteMatch] Response data size: \(data.count) bytes")
                
                // Decode response body as string
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ [CompleteMatch] Response body: \(responseString)")
                } else {
                    print("❌ [CompleteMatch] Response body (hex): \(data.map { String(format: "%02x", $0) }.joined())")
                }
            }
            
            print("🏆 [CompleteMatch] ========================================")
            throw error
        } catch {
            print("❌ [CompleteMatch] Unexpected error: \(error)")
            print("🏆 [CompleteMatch] ========================================")
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
            
            // 🧪 DEBUG STEP 5: Log current_player_id from realtime payload
            if let currentPlayerIdString = record["current_player_id"]?.stringValue {
                print("🧪 [Realtime UPDATE] current_player_id in payload: \(String(currentPlayerIdString.prefix(8)))...")
            } else {
                print("🧪 [Realtime UPDATE] current_player_id is NIL in payload")
            }
            
            // Extract matchId for targeted updates
            guard let matchIdString = record["id"]?.stringValue,
                  let matchId = UUID(uuidString: matchIdString) else {
                print("🚨 [RemoteMatch Realtime] No valid matchId in payload")
                return
            }
            
            Task { @MainActor in
                // Fetch updated match state (includes all fields decoded correctly)
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
                // print("📡 [RemoteMatch Realtime] broadcast ping received:", message)  // Disabled for Phase 8 testing
            }
            
            // Use the newer subscribe API that throws errors
            try await channel.subscribeWithError()
            
            // 🔎 Debug: prove the socket can receive *anything*
            struct PingMessage: Codable { let hello: String }
            try? await channel.broadcast(event: "ping", message: PingMessage(hello: "world"))
            // print("📡 [RemoteMatch Realtime] broadcast ping sent")  // Disabled for Phase 8 testing
            
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
    
    // MARK: - Save Visit (Gameplay)
    
    /// Save a visit (3 darts) to the server
    /// - Parameters:
    ///   - matchId: Match ID
    ///   - darts: Array of 3 dart scores
    ///   - scoreBefore: Player's score before this visit
    ///   - scoreAfter: Player's score after this visit
    /// - Returns: Updated match state from server
    func saveVisit(matchId: UUID, darts: [Int], scoreBefore: Int, scoreAfter: Int) async throws -> RemoteMatch {
        print("💾 [SaveVisit] Starting - matchId: \(matchId.uuidString.prefix(8))...")
        print("💾 [SaveVisit] Darts: \(darts), Before: \(scoreBefore), After: \(scoreAfter)")
        
        // Get headers with auth token
        let headers = try await getEdgeFunctionHeaders()
        
        // Build payload as encodable struct
        struct SaveVisitPayload: Encodable {
            let match_id: String
            let darts: [Int]
            let score_before: Int
            let score_after: Int
        }
        
        let payload = SaveVisitPayload(
            match_id: matchId.uuidString,
            darts: darts,
            score_before: scoreBefore,
            score_after: scoreAfter
        )
        
        // Call save-visit edge function
        let _: EmptyResponse = try await supabaseService.client.functions.invoke(
            "save-visit",
            options: FunctionInvokeOptions(
                headers: headers,
                body: payload
            )
        )
        
        print("✅ [SaveVisit] RPC succeeded")
        
        // Fetch authoritative match state from server
        print("🔄 [SaveVisit] Fetching authoritative match state...")
        let match = try await fetchMatch(matchId: matchId)
        
        print("✅ [SaveVisit] Complete - currentPlayerId: \(match?.currentPlayerId?.uuidString.prefix(8) ?? "nil")")
        
        guard let match = match else {
            throw RemoteMatchError.databaseError("Match not found after save")
        }
        
        return match
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

// MARK: - Preview Support

#if DEBUG
extension RemoteMatchService {
    static var preview: RemoteMatchService {
        let service = RemoteMatchService()
        // Set up mock flow match for preview
        service.flowMatch = RemoteMatch.mockLobbyWithCountdown
        service.flowMatchId = service.flowMatch?.id
        return service
    }
}
#endif
