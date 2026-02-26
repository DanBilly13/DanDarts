//
//  RemoteGameplayViewModel.swift
//  DanDart
//
//  Remote match game state manager for 301/501
//  Server-authoritative turn management with realtime sync
//

import SwiftUI
import Supabase

@MainActor
class RemoteGameplayViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // Match ID (stable identity)
    let matchId: UUID
    
    // Remote match state (fetched asynchronously)
    @Published var remoteMatch: RemoteMatch?
    @Published var challenger: User?
    @Published var receiver: User?
    @Published var currentUser: User?
    
    // Players (derived from users)
    @Published var players: [Player] = []
    @Published var playerScores: [UUID: Int] = [:]
    @Published var currentThrow: [ScoredThrow] = []
    @Published var selectedDartIndex: Int? = nil
    
    // Turn state
    @Published var isMyTurn: Bool = false
    @Published var isSaving: Bool = false
    
    // Reveal state (1-2s delay showing last visit)
    @Published var showingReveal: Bool = false
    @Published var revealVisit: LastVisitPayload? = nil
    
    // Animation state
    @Published var showScoreAnimation: Bool = false
    @Published var isTransitioningPlayers: Bool = false
    
    // Checkout suggestion
    @Published var suggestedCheckout: String? = nil
    private var turnStartedWithCheckout: Bool = false
    
    // Winner detection
    @Published var winner: Player? = nil
    @Published var isMatchWon: Bool = false
    
    // Services
    private let remoteMatchService = RemoteMatchService()
    private let authService = AuthService.shared
    private var realtimeChannel: RealtimeChannelV2?
    private var subscribedMatchId: UUID?
    private var pendingSubscriptionMatchId: UUID?
    private var isSubscribing: Bool = false
    
    // Debug: helps prove whether multiple VM instances are being created
    private let viewModelInstanceId: UUID = UUID()
    
    // Game configuration
    var startingScore: Int = 301
    private let matchStartTime: Date
    
    // MARK: - Computed Properties
    
    var currentPlayer: Player {
        guard let currentPlayerId = remoteMatch?.currentPlayerId else {
            return players.isEmpty ? Player.mockPlayers[0] : players[0]
        }
        return players.first { $0.userId == currentPlayerId } ?? (players.isEmpty ? Player.mockPlayers[0] : players[0])
    }
    
    var opponentPlayer: Player {
        guard let myUserId = currentUser?.id else {
            return players.isEmpty ? Player.mockPlayers[1] : players[1]
        }
        return players.first { $0.userId != myUserId } ?? (players.isEmpty ? Player.mockPlayers[1] : players[1])
    }
    
    var myPlayer: Player {
        guard let myUserId = currentUser?.id else {
            return players.isEmpty ? Player.mockPlayers[0] : players[0]
        }
        return players.first { $0.userId == myUserId } ?? (players.isEmpty ? Player.mockPlayers[0] : players[0])
    }
    
    /// Player index for color assignment (Challenger=0/Red, Receiver=1/Green)
    func playerIndex(for player: Player) -> Int {
        // Challenger is always index 0 (red), Receiver is always index 1 (green)
        guard let challengerId = remoteMatch?.challengerId else { return 0 }
        if player.userId == challengerId {
            return 0
        } else {
            return 1
        }
    }
    
    var isTurnComplete: Bool {
        // Turn is complete if:
        // 1. All 3 darts thrown
        // 2. Bust recorded
        // 3. Player has reached exactly zero (winner)
        if currentThrow.count == 3 || currentThrow.contains(where: { $0.baseValue == -1 }) {
            return true
        }
        
        if isBust {
            return true
        }
        
        let currentScore = playerScores[currentPlayer.userId ?? currentPlayer.id] ?? startingScore
        let throwTotal = currentThrowTotal
        let newScore = currentScore - throwTotal
        
        return newScore == 0
    }
    
    var currentThrowTotal: Int {
        currentThrow.reduce(0) { $0 + $1.totalValue }
    }
    
    var canBust: Bool {
        guard !isTransitioningPlayers else { return false }
        guard isMyTurn else { return false }
        
        let currentScore = playerScores[currentPlayer.userId ?? currentPlayer.id] ?? startingScore
        let throwTotal = currentThrowTotal
        let remainingScore = currentScore - throwTotal
        
        let dartsRemaining = 3 - currentThrow.count
        let maxPossibleScore = dartsRemaining * 60
        
        return remainingScore - maxPossibleScore <= 1
    }
    
    var isBust: Bool {
        if currentThrow.contains(where: { $0.baseValue == -1 }) {
            return true
        }
        
        guard !currentThrow.isEmpty else { return false }
        
        let currentScore = playerScores[currentPlayer.userId ?? currentPlayer.id] ?? startingScore
        let throwTotal = currentThrowTotal
        let newScore = currentScore - throwTotal
        
        if newScore < 0 || newScore == 1 {
            return true
        }
        
        if newScore == 0 {
            if let lastDart = currentThrow.last {
                return lastDart.scoreType != .double
            }
        }
        
        return false
    }
    
    var isWinningThrow: Bool {
        guard !currentThrow.isEmpty else { return false }
        
        let currentScore = playerScores[currentPlayer.userId ?? currentPlayer.id] ?? startingScore
        let throwTotal = currentThrowTotal
        let newScore = currentScore - throwTotal
        
        if newScore == 0 {
            if let lastDart = currentThrow.last {
                return lastDart.scoreType == .double
            }
        }
        
        return false
    }
    
    /// Current visit number (server-authoritative)
    /// Formula: (turnIndexInLeg / 2) + 1
    var currentVisit: Int {
        // TODO: Get turnIndexInLeg from server match state
        // For now, return 1 as placeholder
        return 1
    }
    
    var canDelete: Bool {
        !currentThrow.isEmpty && isMyTurn
    }
    
    // MARK: - Initialization
    
    init(matchId: UUID) {
        self.matchId = matchId
        self.matchStartTime = Date()
        
        print("🎮 [RemoteGameplayVM] Initializing with matchId: \(matchId)")
        print("🎮 [RemoteGameplayVM] VM instance: \(viewModelInstanceId.uuidString)")
        
        // Load match data and subscribe
        Task {
            await loadMatchData()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadMatchData() async {
        print("📥 [RemoteGameplayVM] Loading match data for matchId: \(matchId)")
        
        // Fetch match from service
        guard let fetchedMatch = try? await remoteMatchService.fetchMatch(matchId: matchId) else {
            print("❌ [RemoteGameplayVM] Failed to fetch match")
            return
        }
        
        // Fetch users
        let users: [User]
        do {
            users = try await SupabaseService.shared.client
                .from("users")
                .select()
                .in("id", values: [fetchedMatch.challengerId.uuidString, fetchedMatch.receiverId.uuidString])
                .execute()
                .value
        } catch {
            print("❌ [RemoteGameplayVM] Failed to fetch users: \(error)")
            return
        }
        
        guard let challengerUser = users.first(where: { $0.id == fetchedMatch.challengerId }),
              let receiverUser = users.first(where: { $0.id == fetchedMatch.receiverId }),
              let currentUserData = authService.currentUser else {
            print("❌ [RemoteGameplayVM] Missing user data")
            return
        }
        
        // Update published properties on MainActor
        await MainActor.run {
            self.remoteMatch = fetchedMatch
            self.challenger = challengerUser
            self.receiver = receiverUser
            self.currentUser = currentUserData
            
            // Determine starting score
            if fetchedMatch.gameType == "301" {
                self.startingScore = 301
            } else if fetchedMatch.gameType == "501" {
                self.startingScore = 501
            } else {
                self.startingScore = 301
            }
            
            // Create players
            let challengerPlayer = Player(
                id: UUID(),
                displayName: challengerUser.displayName,
                nickname: challengerUser.nickname,
                avatarURL: challengerUser.avatarURL,
                isGuest: false,
                totalWins: challengerUser.totalWins,
                totalLosses: challengerUser.totalLosses,
                userId: challengerUser.id
            )
            
            let receiverPlayer = Player(
                id: UUID(),
                displayName: receiverUser.displayName,
                nickname: receiverUser.nickname,
                avatarURL: receiverUser.avatarURL,
                isGuest: false,
                totalWins: receiverUser.totalWins,
                totalLosses: receiverUser.totalLosses,
                userId: receiverUser.id
            )
            
            self.players = [challengerPlayer, receiverPlayer]
            
            // Initialize scores
            for player in self.players {
                self.playerScores[player.userId ?? player.id] = self.startingScore
            }
            
            // Set initial turn state
            self.updateTurnState()
            
            print("✅ [RemoteGameplayVM] Match data loaded successfully")
            
            // Subscribe to realtime updates
            self.subscribeToMatch()
        }
    }
    
    deinit {
        // Swift 6: avoid capturing `self` from a Task that could outlive deinit.
        let channel = realtimeChannel
        Task {
            if let channel {
                await channel.unsubscribe()
            }
        }
    }
    
    // MARK: - Realtime Subscription
    
    private func subscribeToMatch() {
        print("🔔 [RemoteGameplay] ========================================")
        print("🔔 [RemoteGameplay] SUBSCRIBING TO MATCH")
        print("🔔 [RemoteGameplay] VM instance: \(viewModelInstanceId.uuidString)")
        print("🔔 [RemoteGameplay] Match ID: \(matchId)")
        print("🔔 [RemoteGameplay] Current User ID: \(currentUser?.id.uuidString ?? "unknown")")
        print("🔔 [RemoteGameplay] Timestamp: \(Date())")
        
        // Guard against duplicate subscriptions (idempotency)
        if subscribedMatchId == matchId {
            print("🔔 [RemoteGameplay] Already subscribed to match \(matchId)")
            print("🔔 [RemoteGameplay] ========================================")
            return
        }
        
        // Guard against a subscription that is already in-flight for this match
        if pendingSubscriptionMatchId == matchId {
            print("🔔 [RemoteGameplay] Subscription already in progress for match \(matchId), skipping")
            print("🔔 [RemoteGameplay] ========================================")
            return
        }
        
        // Guard against any concurrent subscribe attempts (belt-and-braces)
        if isSubscribing {
            print("🔔 [RemoteGameplay] Subscription already in progress (unknown match), skipping")
            print("🔔 [RemoteGameplay] ========================================")
            return
        }
        
        // Mark subscription as in-flight immediately (prevents double-calls within same VM instance)
        isSubscribing = true
        pendingSubscriptionMatchId = matchId
        
        print("🔔 [RemoteGameplay] ========================================")
        
        let channelName = "match:\(matchId)"
        print("🔔 [RemoteGameplay] Creating channel: \(channelName)")
        let channel = SupabaseService.shared.client.channel(channelName)
        
        // Listen for UPDATE events with server-side filtering
        print("🔔 [RemoteGameplay] Registering UPDATE callback with server filter...")
        print("🔔 [RemoteGameplay] Server filter: id=eq.\(matchId.uuidString)")
        _ = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "matches",
            filter: "id=eq.\(matchId.uuidString)"
        ) { [weak self] action in
            // CRITICAL: Log INSIDE callback to prove events are arriving
            print("🚨🚨🚨 [RemoteGameplay] ========================================")
            print("🚨🚨🚨 [RemoteGameplay] UPDATE CALLBACK FIRED!!!")
            print("🚨🚨🚨 [RemoteGameplay] Timestamp: \(Date())")
            print("🚨🚨🚨 [RemoteGameplay] Raw record: \(action.record)")
            print("🚨🚨🚨 [RemoteGameplay] Server-filtered - no client-side check needed")
            print("🚨🚨🚨 [RemoteGameplay] ========================================")
            
            // No client-side filtering needed - server already filtered by match ID
            Task { @MainActor in
                print("🎬 [RemoteGameplay] Task started on MainActor")
                await self?.handleMatchUpdate(action)
                print("🎬 [RemoteGameplay] Task completed")
            }
        }
        
        // Monitor channel status changes
        print("🔔 [RemoteGameplay] Setting up status change monitoring...")
        _ = channel.onStatusChange { status in
            print("📊 [RemoteGameplay] ========================================")
            print("📊 [RemoteGameplay] CHANNEL STATUS CHANGED: \(status)")
            print("📊 [RemoteGameplay] Timestamp: \(Date())")
            print("� [RemoteGameplay] ========================================")
        }
        
        print("🔔 [RemoteGameplay] Attempting to subscribe...")
        Task {
            do {
                try await channel.subscribeWithError()
                await MainActor.run {
                    self.realtimeChannel = channel
                    self.subscribedMatchId = matchId
                    self.pendingSubscriptionMatchId = nil
                    self.isSubscribing = false
                    print("✅ [RemoteGameplay] ========================================")
                    print("✅ [RemoteGameplay] SUBSCRIPTION SUCCESSFUL")
                    print("✅ [RemoteGameplay] Channel: \(channelName)")
                    print("✅ [RemoteGameplay] Status: \(channel.status)")
                    print("✅ [RemoteGameplay] subscribedMatchId set to: \(matchId)")
                    print("✅ [RemoteGameplay] Timestamp: \(Date())")
                    print("✅ [RemoteGameplay] ========================================")
                }
            } catch {
                await MainActor.run {
                    self.pendingSubscriptionMatchId = nil
                    self.isSubscribing = false
                }
                print("❌ [RemoteGameplay] ========================================")
                print("❌ [RemoteGameplay] SUBSCRIPTION FAILED")
                print("❌ [RemoteGameplay] Error: \(error)")
                print("❌ [RemoteGameplay] Timestamp: \(Date())")
                print("❌ [RemoteGameplay] ========================================")
            }
        }
    }
    
    private func unsubscribeFromMatch() async {
        guard let channel = realtimeChannel else { return }
        print("🔕 [RemoteGameplay] Unsubscribing from match")
        await channel.unsubscribe()
        realtimeChannel = nil
        subscribedMatchId = nil
        isSubscribing = false
        pendingSubscriptionMatchId = nil
        print("🔕 [RemoteGameplay] Cleared realtimeChannel, subscribedMatchId, pendingSubscriptionMatchId, and isSubscribing")
    }
    
    private func handleMatchUpdate(_ action: UpdateAction) async {
        print("📡 [RemoteGameplay] ========================================")
        print("📡 [RemoteGameplay] HANDLE MATCH UPDATE CALLED")
        print("📡 [RemoteGameplay] Timestamp: \(Date())")
        print("📡 [RemoteGameplay] ========================================")
        
        // Decode the updated match
        let record = action.record
        print("📡 [RemoteGameplay] Raw record keys: \(record.keys)")
        print("📡 [RemoteGameplay] Attempting to serialize record...")
        
        guard let data = try? JSONSerialization.data(withJSONObject: record) else {
            print("❌ [RemoteGameplay] Failed to serialize record to JSON data")
            return
        }
        
        print("📡 [RemoteGameplay] JSON data size: \(data.count) bytes")
        print("📡 [RemoteGameplay] Attempting to decode RemoteMatch...")
        
        // Configure decoder for Supabase data (ISO8601 dates)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let updatedMatch = try? decoder.decode(RemoteMatch.self, from: data) else {
            print("❌ [RemoteGameplay] Failed to decode RemoteMatch")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("❌ [RemoteGameplay] JSON string: \(jsonString)")
            }
            return
        }
        
        print("✅ [RemoteGameplay] Match decoded successfully")
        print("📡 [RemoteGameplay] Match ID: \(updatedMatch.id)")
        print("📡 [RemoteGameplay] Match status: \(updatedMatch.status?.rawValue ?? "nil")")
        print("📡 [RemoteGameplay] Current player ID: \(updatedMatch.currentPlayerId?.uuidString ?? "nil")")
        print("📡 [RemoteGameplay] Last visit payload: \(updatedMatch.lastVisitPayload != nil ? "present" : "nil")")
        
        // Store old state for comparison
        let oldCurrentPlayerId = self.remoteMatch?.currentPlayerId
        let oldIsMyTurn = self.isMyTurn
        
        print("📡 [RemoteGameplay] OLD currentPlayerId: \(oldCurrentPlayerId?.uuidString ?? "nil")")
        print("📡 [RemoteGameplay] OLD isMyTurn: \(oldIsMyTurn)")
        
        // Update match state
        print("📡 [RemoteGameplay] Updating remoteMatch property...")
        self.remoteMatch = updatedMatch
        print("✅ [RemoteGameplay] remoteMatch updated")
        
        // Update turn state
        print("📡 [RemoteGameplay] Calling updateTurnState()...")
        updateTurnState()
        
        print("📡 [RemoteGameplay] NEW currentPlayerId: \(self.remoteMatch?.currentPlayerId?.uuidString ?? "nil")")
        print("📡 [RemoteGameplay] NEW isMyTurn: \(self.isMyTurn)")
        print("📡 [RemoteGameplay] Turn changed: \(oldIsMyTurn != self.isMyTurn)")
        
        // Handle reveal if there's a last visit
        if let lastVisit = updatedMatch.lastVisitPayload {
            print("👁️ [RemoteGameplay] Last visit payload found, showing reveal...")
            await showReveal(lastVisit)
        } else {
            print("⚠️ [RemoteGameplay] No last visit payload to reveal")
        }
        
        // Check for match completion
        if updatedMatch.status == RemoteMatchStatus.completed {
            print("🏆 [RemoteGameplay] Match is completed, handling completion...")
            handleMatchCompletion()
        }
        
        print("📡 [RemoteGameplay] ========================================")
        print("📡 [RemoteGameplay] HANDLE MATCH UPDATE COMPLETE")
        print("📡 [RemoteGameplay] ========================================")
    }
    
    // MARK: - Turn Management
    
    private func updateTurnState() {
        guard let remoteMatch = remoteMatch,
              let currentUser = currentUser else {
            print("⚠️ [RemoteGameplay] Data not loaded yet, skipping updateTurnState")
            return
        }
        
        print("🎯 [RemoteGameplay] ========================================")
        print("🎯 [RemoteGameplay] UPDATE TURN STATE")
        print("🎯 [RemoteGameplay] Current user ID: \(currentUser.id)")
        print("🎯 [RemoteGameplay] Match currentPlayerId: \(remoteMatch.currentPlayerId?.uuidString ?? "nil")")
        
        let oldIsMyTurn = isMyTurn
        
        // Update isMyTurn based on currentPlayerId
        isMyTurn = remoteMatch.currentPlayerId == currentUser.id
        
        print("🎯 [RemoteGameplay] Comparison result: \(remoteMatch.currentPlayerId == currentUser.id)")
        print("🎯 [RemoteGameplay] OLD isMyTurn: \(oldIsMyTurn)")
        print("🎯 [RemoteGameplay] NEW isMyTurn: \(isMyTurn)")
        print("🎯 [RemoteGameplay] Turn changed: \(oldIsMyTurn != isMyTurn)")
        print("🎯 [RemoteGameplay] ========================================")
        
        // Update checkout suggestion if it's my turn
        if isMyTurn {
            updateCheckoutSuggestion()
        }
    }
    
    // MARK: - Game Actions
    
    func recordThrow(value: Int, multiplier: Int) {
        guard isMyTurn else {
            print("⚠️ [RemoteGameplay] Not my turn, ignoring throw")
            return
        }
        guard !isSaving else {
            print("⚠️ [RemoteGameplay] Already saving, ignoring throw")
            return
        }
        
        // Handle bust
        if value == -1 {
            currentThrow.append(ScoredThrow(baseValue: -1, scoreType: .single))
            return
        }
        
        let scoreType: ScoreType
        switch multiplier {
        case 1: scoreType = .single
        case 2: scoreType = .double
        case 3: scoreType = .triple
        default: scoreType = .single
        }
        
        let scoredThrow = ScoredThrow(baseValue: value, scoreType: scoreType)
        
        if let selectedIndex = selectedDartIndex, selectedIndex <= currentThrow.count, selectedIndex < 3 {
            if selectedIndex < currentThrow.count {
                currentThrow[selectedIndex] = scoredThrow
            } else {
                currentThrow.append(scoredThrow)
            }
            selectedDartIndex = (currentThrow.count < 3) ? currentThrow.count : nil
        } else if currentThrow.count < 3 {
            currentThrow.append(scoredThrow)
        }
        
        // Play sound effects
        if scoredThrow.totalValue == 0 {
            let dartNumber = currentThrow.count
            switch dartNumber {
            case 1: SoundManager.shared.playCountdownCat()
            case 2: SoundManager.shared.playCountdownBrokenGlass()
            case 3: SoundManager.shared.playCountdownHorse()
            default: break
            }
        } else {
            SoundManager.shared.playCountdownThud()
        }
        
        if currentThrow.count == 3 && currentThrowTotal == 180 {
            SoundManager.shared.play180Sound()
        }
        
        updateCheckoutSuggestion()
    }
    
    func selectDart(at index: Int) {
        guard index < currentThrow.count else { return }
        guard isMyTurn else { return }
        selectedDartIndex = index
    }
    
    func deleteThrow() {
        guard isMyTurn else { return }
        
        if let selectedIndex = selectedDartIndex, selectedIndex < currentThrow.count {
            currentThrow.remove(at: selectedIndex)
        } else if !currentThrow.isEmpty {
            let lastIndex = currentThrow.count - 1
            currentThrow.removeLast()
            selectedDartIndex = lastIndex
        }
        
        updateCheckoutSuggestion()
    }
    
    // MARK: - Save Visit (Server Call)
    
    func saveVisit() async {
        guard !currentThrow.isEmpty else { return }
        guard isMyTurn else { return }
        guard !isSaving else { return }
        guard let remoteMatch = remoteMatch,
              let currentUser = currentUser else {
            print("⚠️ [RemoteGameplay] Data not loaded yet, cannot save visit")
            return
        }
        
        print("💾 [RemoteGameplay] ========================================")
        print("💾 [RemoteGameplay] SAVING VISIT")
        print("💾 [RemoteGameplay] Match ID: \(remoteMatch.id)")
        print("💾 [RemoteGameplay] Current user ID: \(currentUser.id)")
        print("💾 [RemoteGameplay] Current throw: \(currentThrow.map { $0.totalValue })")
        print("💾 [RemoteGameplay] Timestamp: \(Date())")
        print("💾 [RemoteGameplay] ========================================")
        
        // Disable input immediately
        isSaving = true
        print("💾 [RemoteGameplay] isSaving set to true")
        
        // Convert darts to simple array of values for server
        let dartValues = currentThrow.map { $0.totalValue }
        print("💾 [RemoteGameplay] Dart values: \(dartValues)")
        
        do {
            print("💾 [RemoteGameplay] Calling remoteMatchService.saveVisit()...")
            // Call server to save visit
            try await remoteMatchService.saveVisit(
                matchId: remoteMatch.id,
                darts: dartValues
            )
            
            print("✅ [RemoteGameplay] ========================================")
            print("✅ [RemoteGameplay] VISIT SAVED SUCCESSFULLY")
            print("✅ [RemoteGameplay] Server acknowledged save")
            print("✅ [RemoteGameplay] Waiting for realtime update...")
            print("✅ [RemoteGameplay] ========================================")
            
            // Clear current throw
            currentThrow.removeAll()
            selectedDartIndex = nil
            print("✅ [RemoteGameplay] Current throw cleared")
            
            // Server will emit updated match state via realtime
            // which will trigger reveal and turn switch
            
        } catch {
            print("❌ [RemoteGameplay] ========================================")
            print("❌ [RemoteGameplay] FAILED TO SAVE VISIT")
            print("❌ [RemoteGameplay] Error: \(error)")
            print("❌ [RemoteGameplay] ========================================")
            isSaving = false
            
            // TODO: Show error to user
        }
    }
    
    // MARK: - Reveal Delay
    
    private func showReveal(_ visit: LastVisitPayload) async {
        print("👁️ [RemoteGameplay] ========================================")
        print("👁️ [RemoteGameplay] SHOWING REVEAL")
        print("👁️ [RemoteGameplay] Player ID: \(visit.playerId)")
        print("👁️ [RemoteGameplay] Darts: \(visit.darts)")
        print("👁️ [RemoteGameplay] Score before: \(visit.scoreBefore)")
        print("👁️ [RemoteGameplay] Score after: \(visit.scoreAfter)")
        print("👁️ [RemoteGameplay] Timestamp: \(visit.timestamp)")
        print("👁️ [RemoteGameplay] ========================================")
        
        revealVisit = visit
        showingReveal = true
        print("👁️ [RemoteGameplay] Reveal state set: showingReveal = true")
        
        // Update scores from visit
        let oldScore = playerScores[visit.playerId]
        playerScores[visit.playerId] = visit.scoreAfter
        print("👁️ [RemoteGameplay] Score updated: \(oldScore ?? 0) → \(visit.scoreAfter)")
        
        // Show reveal for 1.5 seconds
        print("👁️ [RemoteGameplay] Waiting 1.5 seconds...")
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        showingReveal = false
        revealVisit = nil
        isSaving = false
        
        print("✅ [RemoteGameplay] ========================================")
        print("✅ [RemoteGameplay] REVEAL COMPLETE")
        print("✅ [RemoteGameplay] showingReveal = false, isSaving = false")
        print("✅ [RemoteGameplay] ========================================")
    }
    
    // MARK: - Match Completion
    
    private func handleMatchCompletion() {
        print("🏆 [RemoteGameplay] Match completed")
        
        // Determine winner from current scores.
        // NOTE: `playerScores` is keyed by userId (UUID).
        guard let challengerId = challenger?.id,
              let receiverId = receiver?.id else {
            print("⚠️ [RemoteGameplay] Missing challenger/receiver user IDs, cannot determine winner")
            isMatchWon = true
            return
        }
        
        let challengerScore = playerScores[challengerId] ?? startingScore
        let receiverScore = playerScores[receiverId] ?? startingScore
        
        if challengerScore == 0 {
            winner = players.first(where: { $0.userId == challengerId }) ?? players.first
        } else if receiverScore == 0 {
            winner = players.first(where: { $0.userId == receiverId }) ?? players.dropFirst().first
        }
        
        isMatchWon = true
    }
    
    // MARK: - Checkout Calculation
    
    private func updateCheckoutSuggestion() {
        guard isMyTurn else {
            suggestedCheckout = nil
            return
        }
        
        let currentScore = playerScores[currentPlayer.userId ?? currentPlayer.id] ?? startingScore
        let remainingAfterThrow = currentScore - currentThrowTotal
        let dartsLeft = 3 - currentThrow.count
        
        if currentThrow.isEmpty {
            turnStartedWithCheckout = (remainingAfterThrow >= 2 && remainingAfterThrow <= 170)
        }
        
        guard remainingAfterThrow >= 2 && remainingAfterThrow <= 170 && dartsLeft > 0 else {
            if turnStartedWithCheckout && !currentThrow.isEmpty && remainingAfterThrow > 1 {
                suggestedCheckout = "Not Available \(remainingAfterThrow)pts left"
            } else {
                suggestedCheckout = nil
            }
            return
        }
        
        if let checkout = calculateCheckout(score: remainingAfterThrow, dartsAvailable: dartsLeft) {
            suggestedCheckout = checkout
        } else {
            if turnStartedWithCheckout && !currentThrow.isEmpty {
                suggestedCheckout = "Not Available \(remainingAfterThrow)pts left"
            } else {
                suggestedCheckout = nil
            }
        }
    }
    
    private func calculateCheckout(score: Int, dartsAvailable: Int) -> String? {
        guard score >= 2 && score <= 170 else { return nil }
        
        if let checkout = CountdownViewModel.CheckoutChart.checkouts[score] {
            let dartsNeeded = checkout.components(separatedBy: " → ").count
            if dartsNeeded <= dartsAvailable {
                return checkout
            }
        }
        
        return nil
    }
}
