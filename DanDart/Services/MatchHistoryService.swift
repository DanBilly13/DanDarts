//
//  MatchHistoryService.swift
//  Dart Freak
//
//  Centralized match history management with smart preloading and background updates
//

import Foundation
import Combine

@MainActor
class MatchHistoryService: ObservableObject {
    static let shared = MatchHistoryService()
    
    // MARK: - Published Properties
    
    @Published var summaries: [MatchSummary] = []  // NEW: Lightweight summaries for list
    @Published var matches: [MatchResult] = []      // DEPRECATED: Will be removed
    @Published var isLoading: Bool = false
    @Published var lastLoadedTime: Date?
    @Published var loadError: String?
    
    // MARK: - Private Properties
    
    private let matchesService = MatchesService()
    private let storageManager = MatchStorageManager.shared
    private let remoteMatchAdapter = RemoteMatchAdapter()
    private let supabaseService = SupabaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Detail cache for lazy loading
    private var detailCache: [UUID: MatchResult] = [:]
    
    // MARK: - Computed Properties
    
    /// Check if cached data is stale (older than 30 seconds)
    var isStale: Bool {
        guard let lastLoaded = lastLoadedTime else { return true }
        return Date().timeIntervalSince(lastLoaded) > 30
    }
    
    // MARK: - Initialization
    
    private init() {
        setupNotificationListeners()
    }
    
    // MARK: - Setup
    
    private func setupNotificationListeners() {
        // Listen for match completed notifications
        NotificationCenter.default.publisher(for: NSNotification.Name("MatchCompleted"))
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                // Invalidate cache for new match
                if let matchId = notification.userInfo?["matchId"] as? UUID {
                    self.invalidateDetailCache(matchId: matchId)
                }
                
                Task {
                    await self.refreshSummariesInBackground()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Preload last 20 matches in background (called on sign-in)
    func preloadMatches(userId: UUID) async {
        print("📥 Preloading match history in background...")
        
        // Don't show loading indicator for background preload
        do {
            // Load from Supabase (local matches)
            let supabaseMatches = try await matchesService.loadMatches(userId: userId)
            
            // Load local matches
            let localMatches = storageManager.loadMatches()
            
            // Load remote matches
            let remoteMatches = (try? await loadRemoteMatches(userId: userId)) ?? []
            
            // Merge and deduplicate
            let allMatches = mergeMatches(local: localMatches, supabase: supabaseMatches, remote: remoteMatches)
            
            // Update state
            matches = allMatches.sorted { $0.timestamp > $1.timestamp }
            lastLoadedTime = Date()
            
            print("✅ Preloaded \(matches.count) matches in background (local: \(localMatches.count), supabase: \(supabaseMatches.count), remote: \(remoteMatches.count))")
        } catch {
            print("⚠️ Background preload failed: \(error)")
            // Don't show error for background preload, just use local data
            let localMatches = storageManager.loadMatches()
            matches = localMatches.sorted { $0.timestamp > $1.timestamp }
        }
    }
    
    /// Refresh matches from Supabase (called on pull-to-refresh or when stale)
    func refreshMatches(userId: UUID) async {
        isLoading = true
        loadError = nil
        
        do {
            // Load from Supabase (local matches)
            let supabaseMatches = try await matchesService.loadMatches(userId: userId)
            
            // Load local matches
            let localMatches = storageManager.loadMatches()
            
            // Load remote matches
            let remoteMatches = (try? await loadRemoteMatches(userId: userId)) ?? []
            
            // Merge and deduplicate
            let allMatches = mergeMatches(local: localMatches, supabase: supabaseMatches, remote: remoteMatches)
            
            // Update state
            matches = allMatches.sorted { $0.timestamp > $1.timestamp }
            lastLoadedTime = Date()
            isLoading = false
            
            print("✅ Refreshed \(matches.count) matches (local: \(localMatches.count), supabase: \(supabaseMatches.count), remote: \(remoteMatches.count))")
            print("📊 [RefreshMatches] Match details:")
            for (index, match) in matches.prefix(3).enumerated() {
                let turnCount = match.players.first?.turns.count ?? 0
                let isRemote = match.metadata?["isRemote"] == "true"
                print("   [\(index)] \(match.gameName) - \(isRemote ? "REMOTE" : "LOCAL") - \(turnCount) turns")
            }
        } catch {
            isLoading = false
            loadError = "Couldn't sync with cloud"
            print("❌ Refresh error: \(error)")
            
            // Fall back to local matches on error
            let localMatches = storageManager.loadMatches()
            matches = localMatches.sorted { $0.timestamp > $1.timestamp }
        }
    }
    
    /// Refresh matches in background (called on match completed notification)
    private func refreshMatchesInBackground() async {
        guard !isLoading else {
            print("⏭️ Skipping background refresh - already loading")
            return
        }
        
        print("🔔 Match completed - refreshing history in background")
        
        // Get current user ID from AuthService
        guard let userId = AuthService.shared.currentUser?.id else {
            print("⚠️ No current user for background refresh")
            return
        }
        
        // Refresh without showing loading indicator
        do {
            let supabaseMatches = try await matchesService.loadMatches(userId: userId)
            let localMatches = storageManager.loadMatches()
            let remoteMatches = (try? await loadRemoteMatches(userId: userId)) ?? []
            let allMatches = mergeMatches(local: localMatches, supabase: supabaseMatches, remote: remoteMatches)
            
            matches = allMatches.sorted { $0.timestamp > $1.timestamp }
            lastLoadedTime = Date()
            
            print("✅ Background refresh complete: \(matches.count) matches")
        } catch {
            print("⚠️ Background refresh failed: \(error)")
        }
    }
    
    /// Load matches from local storage only (instant, for initial display)
    func loadLocalMatches() {
        let localMatches = storageManager.loadMatches()
        matches = localMatches.sorted { $0.timestamp > $1.timestamp }
        print("📱 Loaded \(matches.count) matches from local storage")
    }
    
    // MARK: - Private Methods
    
    /// Load completed remote matches from Supabase and convert to MatchResult
    private func loadRemoteMatches(userId: UUID) async throws -> [MatchResult] {
        print("📡 Loading remote matches for user \(userId.uuidString.prefix(8))...")
        
        // Define response structure for remote matches
        struct RemoteMatchResponse: Decodable {
            let id: UUID
            let match_mode: String
            let game_type: String
            let game_name: String
            let match_format: Int
            let challenger_id: UUID
            let receiver_id: UUID
            let remote_status: String?
            let player_scores: [String: Int]?
            let winner_id: UUID?
            let ended_at: String?
            let created_at: String
            let updated_at: String
        }
        
        // Query matches table for completed remote matches
        let response: [RemoteMatchResponse] = try await supabaseService.client
            .from("matches")
            .select()
            .eq("match_mode", value: "remote")
            .eq("remote_status", value: "completed")
            .or("challenger_id.eq.\(userId.uuidString),receiver_id.eq.\(userId.uuidString)")
            .order("ended_at", ascending: false)
            .execute()
            .value
        
        print("📡 Found \(response.count) completed remote matches")
        
        // Convert to RemoteMatch objects and then to MatchResult
        var matchResults: [MatchResult] = []
        
        for matchData in response {
            // Fetch user data for challenger and receiver
            guard let challenger = try? await fetchUser(id: matchData.challenger_id),
                  let receiver = try? await fetchUser(id: matchData.receiver_id) else {
                print("⚠️ Skipping remote match \(matchData.id.uuidString.prefix(8))... - couldn't fetch user data")
                continue
            }
            
            // Parse dates
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            guard let createdAt = dateFormatter.date(from: matchData.created_at),
                  let endedAtString = matchData.ended_at,
                  let endedAt = dateFormatter.date(from: endedAtString) else {
                print("⚠️ Skipping remote match \(matchData.id.uuidString.prefix(8))... - invalid dates")
                continue
            }
            
            // Convert player_scores dictionary from [String: Int] to [UUID: Int]
            var playerScores: [UUID: Int]?
            if let scores = matchData.player_scores {
                playerScores = [:]
                for (key, value) in scores {
                    if let uuid = UUID(uuidString: key) {
                        playerScores?[uuid] = value
                    }
                }
            }
            
            // Create RemoteMatch object
            let remoteMatch = RemoteMatch(
                id: matchData.id,
                matchMode: matchData.match_mode,
                gameType: matchData.game_type,
                gameName: matchData.game_name,
                matchFormat: matchData.match_format,
                challengerId: matchData.challenger_id,
                receiverId: matchData.receiver_id,
                status: RemoteMatchStatus(rawValue: matchData.remote_status ?? ""),
                currentPlayerId: nil,
                challengeExpiresAt: nil,
                joinWindowExpiresAt: nil,
                lastVisitPayload: nil,
                playerScores: playerScores,
                turnIndexInLeg: nil,
                createdAt: createdAt,
                updatedAt: dateFormatter.date(from: matchData.updated_at) ?? createdAt,
                endedBy: nil,
                endedReason: nil,
                winnerId: matchData.winner_id,
                endedAt: endedAt,
                debugCounter: nil
            )
            
            // Convert to MatchResult using adapter (now async to load turn data)
            if let matchResult = await remoteMatchAdapter.convertToMatchResult(
                remoteMatch: remoteMatch,
                challenger: challenger,
                receiver: receiver
            ) {
                print("✅ [RemoteMatchAdapter] Converted remote match \(matchData.id.uuidString.prefix(8))... to MatchResult")
                print("   - ID: \(matchResult.id)")
                print("   - isRemote: \(matchResult.metadata?["isRemote"] ?? "nil")")
                print("   - Game: \(matchResult.gameName)")
                print("   - Winner: \(matchResult.winner?.displayName ?? "nil")")
                print("   - Turns loaded: \(matchResult.players.first?.turns.count ?? 0)")
                matchResults.append(matchResult)
            } else {
                print("❌ [RemoteMatchAdapter] Failed to convert remote match \(matchData.id.uuidString.prefix(8))...")
            }
        }
        
        print("✅ Converted \(matchResults.count) remote matches to MatchResult")
        return matchResults
    }
    
    /// Fetch user data from Supabase
    private func fetchUser(id: UUID) async throws -> User {
        let response: [User] = try await supabaseService.client
            .from("users")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        
        guard let user = response.first else {
            throw NSError(domain: "MatchHistoryService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        return user
    }
    
    /// Merge local, Supabase, and remote matches, removing duplicates
    private func mergeMatches(local: [MatchResult], supabase: [MatchResult], remote: [MatchResult] = []) -> [MatchResult] {
        print("🔄 [MergeMatches] Starting merge:")
        print("   - Local: \(local.count) matches")
        print("   - Supabase: \(supabase.count) matches")
        print("   - Remote: \(remote.count) matches")
        
        func totalTurns(_ m: MatchResult) -> Int {
            m.players.reduce(0) { $0 + $1.turns.count }
        }
        
        var matchesById: [UUID: MatchResult] = [:]
        var localMatchesById: [UUID: MatchResult] = [:]
        
        // Store local matches in a separate dictionary to preserve turn data
        for match in local {
            let turnCount = match.players.first?.turns.count ?? 0
            print("🔄 [MergeMatches] Adding LOCAL match \(match.id.uuidString.prefix(8))... (\(match.gameName), \(turnCount) turns)")
            matchesById[match.id] = match
            localMatchesById[match.id] = match
        }
        
        // Add Supabase matches, but preserve turn data from local matches
        for match in supabase {
            let turnCount = match.players.first?.turns.count ?? 0
            let wasLocal = matchesById[match.id] != nil
            print("🔄 [MergeMatches] Adding SUPABASE match \(match.id.uuidString.prefix(8))... (\(match.gameName), \(turnCount) turns) \(wasLocal ? "[OVERWRITES LOCAL]" : "")")

            // If we have a local version with turn data, prefer it to avoid losing turns
            if let localMatch = localMatchesById[match.id] {
                let localTurns = totalTurns(localMatch)
                let supabaseTurns = totalTurns(match)
                let keeping = localTurns >= supabaseTurns ? "LOCAL" : "SUPABASE"
                print("🧩 [MatchDBG] [merge] id=\(match.id.uuidString.prefix(8)) localTurns=\(localTurns) supabaseTurns=\(supabaseTurns) -> keeping \(keeping)")
                
                if localTurns > 0 {
                    print("   ✅ Keeping LOCAL version to preserve \(localTurns) turns (Supabase version has \(supabaseTurns) turns)")
                    matchesById[match.id] = localMatch
                } else {
                    matchesById[match.id] = match
                }
            } else {
                matchesById[match.id] = match
            }
        }
        
        // Add remote matches (will overwrite if same ID)
        for match in remote {
            // let turnCount = match.players.first?.turns.count ?? 0
            // let wasLocal = matchesById[match.id] != nil
            // print("🔄 [MergeMatches] Adding REMOTE match \(match.id.uuidString.prefix(8))... isRemote=\(match.metadata?["isRemote"] ?? "nil"), \(turnCount) turns \(wasLocal ? "[OVERWRITES]" : "")")
            matchesById[match.id] = match
        }
        
        let result = Array(matchesById.values)
        // print("🔄 [MergeMatches] Final result: \(result.count) matches")
        // if let firstMatch = result.first {
        //     let turnCount = firstMatch.players.first?.turns.count ?? 0
        //     print("   📊 First merged match: \(firstMatch.gameName), \(turnCount) turns)")
        // }
        
        return result
    }
    
    // MARK: - Summary Loading (Phase 11: Lazy Loading)
    
    /// Refresh match summaries (lightweight, no turn data)
    func refreshSummaries(userId: UUID) async {
        isLoading = true
        loadError = nil
        
        do {
            let allSummaries = try await matchesService.loadAllMatchSummaries(userId: userId)
            summaries = allSummaries
            lastLoadedTime = Date()
            isLoading = false
            
            // Clear detail cache on refresh
            detailCache.removeAll()
            
            print("✅ Refreshed \(summaries.count) match summaries")
        } catch {
            isLoading = false
            loadError = "Couldn't sync with cloud"
            print("❌ Refresh summaries error: \(error)")
        }
    }
    
    /// Refresh summaries in background (called on match completed notification)
    private func refreshSummariesInBackground() async {
        guard !isLoading else {
            print("⏭️ Skipping background summary refresh - already loading")
            return
        }
        
        print("🔔 Match completed - refreshing summaries in background")
        
        guard let userId = AuthService.shared.currentUser?.id else {
            print("⚠️ No current user for background refresh")
            return
        }
        
        do {
            let allSummaries = try await matchesService.loadAllMatchSummaries(userId: userId)
            summaries = allSummaries
            lastLoadedTime = Date()
            
            print("✅ Background summary refresh complete: \(summaries.count) summaries")
        } catch {
            print("⚠️ Background summary refresh failed: \(error)")
        }
    }
    
    // MARK: - Detail Loading (Lazy with Cache)
    
    /// Load full match detail by ID (with caching)
    func loadFullDetail(matchId: UUID) async throws -> MatchResult {
        // Check cache first
        if let cached = detailCache[matchId] {
            print("✅ [Cache Hit] Returning cached detail for \(matchId.uuidString.prefix(8))")
            return cached
        }
        
        print("🔍 [Cache Miss] Loading full detail for \(matchId.uuidString.prefix(8))")
        
        // Try device-stored first (instant)
        let localMatches = storageManager.loadMatches()
        if let localMatch = localMatches.first(where: { $0.id == matchId }) {
            detailCache[matchId] = localMatch
            return localMatch
        }
        
        // Try Supabase
        if let match = try await matchesService.loadMatchById(matchId) {
            detailCache[matchId] = match
            return match
        }
        
        throw NSError(domain: "MatchHistoryService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Match not found"])
    }
    
    /// Seed the cache with a pre-loaded MatchResult (called from End Game path)
    func seedDetailCache(match: MatchResult) {
        detailCache[match.id] = match
        print("🌱 [Cache Seed] Cached detail for \(match.id.uuidString.prefix(8)) from End Game")
    }
    
    /// Invalidate detail cache
    func invalidateDetailCache(matchId: UUID? = nil) {
        if let matchId = matchId {
            detailCache.removeValue(forKey: matchId)
            print("🗑️ Invalidated cache for match \(matchId.uuidString.prefix(8))")
        } else {
            detailCache.removeAll()
            print("🗑️ Cleared entire detail cache")
        }
    }
}
