//
//  RemoteGameViewModel.swift
//  Dart Freak
//
//  Game state manager for remote countdown games (301/501)
//  Handles scoring, turn management, and win detection
//

import SwiftUI

@MainActor
class RemoteGameViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var players: [Player]
    @Published var currentPlayerIndex: Int = 0
    @Published var playerScores: [UUID: Int] = [:]
    @Published var currentThrow: [ScoredThrow] = []
    @Published var winner: Player? = nil
    @Published var lastTurn: TurnHistory? = nil
    @Published var turnHistory: [TurnHistory] = []
    @Published var suggestedCheckout: String? = nil
    @Published var selectedDartIndex: Int? = nil
    @Published var initialCheckoutForTurn: String? = nil // Checkout at start of turn (for opponent display)
    
    // Track if turn started with a checkout available
    private var turnStartedWithCheckout: Bool = false
    
    // Undo functionality
    @Published private(set) var lastVisit: Visit? = nil
    
    // Multi-leg match tracking
    @Published var currentLeg: Int = 1
    @Published var legsWon: [UUID: Int] = [:] // Player ID to legs won
    @Published var matchFormat: Int // Total legs in match (1, 3, 5, or 7)
    @Published var legWinner: Player? = nil // Winner of current leg (before match winner)
    @Published var isMatchWon: Bool = false // True when match is won (not just leg)
    @Published var currentVisit: Int = 1 // Current visit number (increments after all players complete turn)
    
    // Remote match state
    @Published var isSaving: Bool = false
    @Published var saveError: String? = nil
    @Published var isRevealingScore: Bool = false // True during 1-2s reveal window
    @Published var lastScoredVisit: Int? = nil // Value of last scored visit for reveal
    var remoteMatchId: UUID? // Remote match ID for server RPC
    var remoteMatchService: RemoteMatchService?
    
    // Services
    private var authService: AuthService?
    private let analytics = AnalyticsService.shared
    
    /// Inject AuthService from the view
    func setAuthService(_ service: AuthService) {
        self.authService = service
    }
    
    /// Inject RemoteMatchService from the view
    func setRemoteMatchService(_ service: RemoteMatchService) {
        self.remoteMatchService = service
        print("✅ [RemoteGameVM] remoteMatchService injected: \(ObjectIdentifier(service)) / flowMatchId=\(service.flowMatchId?.uuidString.prefix(8) ?? "nil")...")
    }
    
    // Animation state
    @Published var showScoreAnimation: Bool = false // Triggers arcade-style score pop
    @Published var isTransitioningPlayers: Bool = false // True during player switch animation
    
    // Match saving (local storage)
    @Published var matchId: UUID? = nil // ID for saved match result
    @Published var savedMatchResult: MatchResult? = nil // Saved match data for passing to GameEndView
    private var hasBeenSaved: Bool = false // Prevent double-saving
    
    // Game configuration
    let game: Game
    let startingScore: Int
    private let matchStartTime: Date
    private let originalPlayerOrder: [Player] // Store original randomized order for color consistency
    
    // MARK: - Computed Properties
    
    var currentPlayer: Player {
        players[currentPlayerIndex]
    }
    
    /// Get the original index of a player for consistent color assignment
    /// This ensures player colors don't change when order rotates in multi-leg matches
    func originalIndex(of player: Player) -> Int {
        return originalPlayerOrder.firstIndex(where: { $0.id == player.id }) ?? 0
    }
    
    var isTurnComplete: Bool {
        // Turn is complete if:
        // 1. All 3 darts thrown
        // 2. Bust recorded (explicit bust button pressed)
        // 3. Player has gone bust (detected automatically)
        // 4. Player has reached exactly zero (winner)
        if currentThrow.count == 3 || currentThrow.contains(where: { $0.baseValue == -1 }) {
            return true
        }
        
        // Check if player has gone bust (show Bust button immediately)
        if isBust {
            return true
        }
        
        // Check if current throw would result in exactly zero (winning condition)
        let currentScore = playerScores[currentPlayer.id] ?? startingScore
        let throwTotal = currentThrowTotal
        let newScore = currentScore - throwTotal
        
        return newScore == 0
    }
    
    var currentThrowTotal: Int {
        currentThrow.reduce(0) { $0 + $1.totalValue }
    }
    
    /// Determines if a bust is mathematically possible with remaining darts
    var canBust: Bool {
        // Hide bust button during player transition to prevent flicker
        guard !isTransitioningPlayers else { return false }
        
        let currentScore = playerScores[currentPlayer.id] ?? startingScore
        let throwTotal = currentThrowTotal
        let remainingScore = currentScore - throwTotal
        
        // Calculate maximum possible score with remaining darts (60 per dart = T20)
        let dartsRemaining = 3 - currentThrow.count
        let maxPossibleScore = dartsRemaining * 60
        
        // Bust is impossible if: remainingScore - maxPossibleScore > 1
        // (Can't go below 2, which is the minimum non-bust score)
        return remainingScore - maxPossibleScore <= 1
    }
    
    var isBust: Bool {
        // Check if bust button was pressed
        if currentThrow.contains(where: { $0.baseValue == -1 }) {
            return true
        }
        
        // Check if the current throw would result in a bust
        guard !currentThrow.isEmpty else { return false }
        
        let currentScore = playerScores[currentPlayer.id] ?? startingScore
        let throwTotal = currentThrowTotal
        let newScore = currentScore - throwTotal
        
        // Bust if: score goes below 0, equals 1, or reaches 0 without a double
        if newScore < 0 || newScore == 1 {
            return true
        }
        
        // If reaching exactly 0, must finish on a double
        if newScore == 0 {
            // Check if last dart was a double
            if let lastDart = currentThrow.last {
                return lastDart.scoreType != .double
            }
        }
        
        return false
    }
    
    var isWinningThrow: Bool {
        // Check if the current throw would result in a win (exactly 0 with a double)
        guard !currentThrow.isEmpty else { return false }
        
        let currentScore = playerScores[currentPlayer.id] ?? startingScore
        let throwTotal = currentThrowTotal
        let newScore = currentScore - throwTotal
        
        // Win if: score reaches exactly 0 AND last dart was a double
        if newScore == 0 {
            if let lastDart = currentThrow.last {
                return lastDart.scoreType == .double
            }
        }
        
        return false
    }
    
    /// Current leg status display (e.g., "Leg 2/5")
    var legStatusText: String {
        return "Leg \(currentLeg)/\(matchFormat)"
    }
    
    /// Check if this is a multi-leg match
    var isMultiLegMatch: Bool {
        return matchFormat > 1
    }
    
    /// Check if undo is available
    var canUndo: Bool {
        return lastVisit != nil && winner == nil
    }
    
    // MARK: - Initialization
    
    init(game: Game, players: [Player], matchFormat: Int = 1, authService: AuthService? = nil, remoteMatchId: UUID? = nil) {
        self.game = game
        self.players = players
        self.matchFormat = matchFormat
        self.authService = authService
        self.remoteMatchId = remoteMatchId
        self.originalPlayerOrder = players
        self.matchStartTime = Date()
        
        print("🎯 [RemoteGameVM] Init - game: \(game.title), players: \(players.count), format: \(matchFormat)")
        if let matchId = remoteMatchId {
            print("✅ [RemoteGameVM] remoteMatchId set: \(matchId.uuidString.prefix(8))...")
        } else {
            print("⚠️ [RemoteGameVM] remoteMatchId is NIL (local game)")
        }
        
        // Determine starting score based on game type
        if game.title == "301" {
            self.startingScore = 301
        } else if game.title == "501" {
            self.startingScore = 501
        } else {
            self.startingScore = 501 // Default
        }
        
        // Initialize player scores
        for player in players {
            playerScores[player.id] = startingScore
        }
        
        // Initialize legs won for multi-leg matches
        if matchFormat > 1 {
            for player in players {
                legsWon[player.id] = 0
            }
        }
        
        print("✅ [RemoteGameVM] Initialized - startingScore: \(startingScore)")
    }
    
    deinit {
        print("🗑️ [RemoteGameVM] Deinit")
    }
    
    // MARK: - Game Actions
    
    /// Record a throw (dart hit)
    func recordThrow(value: Int, multiplier: Int) {
        guard winner == nil else { return } // Game already won
        
        // Handle bust - end turn immediately
        if value == -1 {
            bustCurrentTurn()
            return
        }
        
        // Determine score type from multiplier
        let scoreType: ScoreType
        switch multiplier {
        case 1: scoreType = .single
        case 2: scoreType = .double
        case 3: scoreType = .triple
        default: scoreType = .single
        }
        
        let scoredThrow = ScoredThrow(baseValue: value, scoreType: scoreType)
        
        // If a dart is selected, replace it or fill that position
        if let selectedIndex = selectedDartIndex, selectedIndex <= currentThrow.count, selectedIndex < 3 {
            if selectedIndex < currentThrow.count {
                // Replace existing dart
                currentThrow[selectedIndex] = scoredThrow
            } else {
                // Fill empty position (after undo/delete)
                currentThrow.append(scoredThrow)
            }
            // Advance to next position if there's room, otherwise clear selection
            selectedDartIndex = (currentThrow.count < 3) ? currentThrow.count : nil
        } else if currentThrow.count < 3 {
            // No selection, just append
            currentThrow.append(scoredThrow)
        }
        
        // Play sound effects based on hit/miss and dart number
        if scoredThrow.totalValue == 0 {
            // Missed - play progressive miss sounds
            let dartNumber = currentThrow.count // 1, 2, or 3
            switch dartNumber {
            case 1:
                SoundManager.shared.playCountdownCat()
            case 2:
                SoundManager.shared.playCountdownBrokenGlass()
            case 3:
                SoundManager.shared.playCountdownHorse()
            default:
                break
            }
        } else {
            // Hit the board - play thud
            SoundManager.shared.playCountdownThud()
        }
        
        // Check for 180 (perfect score with 3 darts)
        if currentThrow.count == 3 && currentThrowTotal == 180 {
            SoundManager.shared.play180Sound()
        }
        
        // Update checkout suggestion after each dart
        updateCheckoutSuggestion()
    }
    
    /// Select a dart for editing
    func selectDart(at index: Int) {
        guard index < currentThrow.count else { return }
        selectedDartIndex = index
    }
    
    /// Deselect the currently selected dart
    func deselectDart() {
        selectedDartIndex = nil
    }
    
    /// Delete the current throw or move back to previous throw
    func deleteThrow() {
        // If there's a selected dart, delete it and keep that position selected
        if let selectedIndex = selectedDartIndex, selectedIndex < currentThrow.count {
            currentThrow.remove(at: selectedIndex)
            // Keep the same index selected (now points to empty slot or next throw)
            // This maintains the active border on the cleared position
        } else if !currentThrow.isEmpty {
            // No selection, delete the last throw and select that position
            let lastIndex = currentThrow.count - 1
            currentThrow.removeLast()
            selectedDartIndex = lastIndex
        }
        // If currentThrow is empty and no selection, do nothing
    }
    
    /// Check if delete button should be enabled
    var canDelete: Bool {
        !currentThrow.isEmpty
    }
    
    /// Save the current turn to the server (remote matches only)
    func saveScore() {
        guard !currentThrow.isEmpty else { return }
        guard winner == nil else { return }
        guard let remoteMatchId = remoteMatchId else {
            print("❌ [RemoteGame] No remoteMatchId - cannot save visit")
            return
        }
        guard let remoteMatchService = remoteMatchService else {
            print("❌ [RemoteGame] No remoteMatchService - cannot save visit")
            return
        }
        
        // Guard: Check match is still valid (server-authoritative)
        if let flowMatch = remoteMatchService.flowMatch {
            // Check if expired
            if flowMatch.isExpired {
                print("❌ [RemoteGame] Cannot save - match expired")
                saveError = "Match expired"
                return
            }
            
            // Check if still in progress
            if flowMatch.status != .inProgress {
                print("❌ [RemoteGame] Cannot save - match not in progress (status: \(flowMatch.status?.rawValue ?? "nil"))")
                saveError = "Match no longer active"
                return
            }
        }
        
        // Build engine state from current VM state
        let engineState = CountdownState(
            startingScore: startingScore,
            scores: playerScores,
            playerIds: players.map { $0.id },
            currentPlayerIndex: currentPlayerIndex,
            currentLeg: currentLeg,
            legsWon: legsWon,
            matchFormat: matchFormat,
            isEnded: winner != nil,
            winnerId: winner?.id
        )
        
        // Apply visit through engine (LOCAL PREDICTION)
        let (newState, events) = CountdownEngine.applyVisit(
            state: engineState,
            playerId: currentPlayer.id,
            darts: currentThrow
        )
        
        // Extract scores for server RPC
        let throwTotal = currentThrowTotal
        let currentScore = playerScores[currentPlayer.id] ?? startingScore
        let newScore = newState.scores[currentPlayer.id] ?? currentScore
        
        // Convert currentThrow to array of integers for server
        let darts = currentThrow.map { $0.totalValue }
        
        print("💾 [RemoteGame] saveScore START - matchId: \(remoteMatchId.uuidString.prefix(8))..., player: \(currentPlayer.displayName), darts: \(darts), score: \(currentScore) → \(newScore)")
        
        // 🎵 Play sound and trigger animation IMMEDIATELY (matches local game timing)
        SoundManager.shared.playCountdownSaveScore()
        showScoreAnimation = true
        
        // Set saving state immediately to lock both players
        isSaving = true
        saveError = nil
        
        // Start animation timing task (independent of server RPC)
        Task { @MainActor in
            // Wait for animation to reach peak (mid-point at 0.125s)
            try? await Task.sleep(nanoseconds: 125_000_000) // 0.125 seconds
            
            // Update score at peak of animation (dramatic reveal!)
            playerScores[currentPlayer.id] = newScore
            print("🎬 [RemoteGame] Score updated at animation peak: \(currentScore) → \(newScore)")
            
            // Notify view to show updated score (for UI override)
            NotificationCenter.default.post(
                name: NSNotification.Name("RemoteMatchScoreUpdated"),
                object: nil,
                userInfo: ["playerId": currentPlayer.id, "score": newScore]
            )
            
            // Wait for animation to complete (another 0.125s)
            try? await Task.sleep(nanoseconds: 125_000_000) // 0.125 seconds
            showScoreAnimation = false
            print("🎬 [RemoteGame] Animation complete")
            
            // Brief pause after animation (0.2s)
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            print("🎬 [RemoteGame] Pause complete, ready for reveal")
            
            // Clear override after animation completes
            NotificationCenter.default.post(
                name: NSNotification.Name("RemoteMatchScoreAnimationComplete"),
                object: nil
            )
        }
        
        // Call server RPC (parallel to animation)
        Task {
            do {
                print("🔄 [RemoteGame] Calling save-visit RPC...")
                let updatedMatch = try await remoteMatchService.saveVisit(
                    matchId: remoteMatchId,
                    darts: darts,
                    scoreBefore: currentScore,
                    scoreAfter: newScore
                )
                
                // Server succeeded - update UI from authoritative server state
                print("✅ [RemoteGame] RPC success - status: \(updatedMatch.status?.rawValue ?? "nil"), currentPlayerId: \(updatedMatch.currentPlayerId?.uuidString.prefix(8) ?? "nil")...")
                
                // Store the scored visit value for reveal window
                lastScoredVisit = throwTotal
                
                // Clear current throw
                currentThrow.removeAll()
                selectedDartIndex = nil
                turnStartedWithCheckout = false
                initialCheckoutForTurn = nil
                
                // Wait for animation + pause to complete (0.45s total)
                // Animation: 0.25s, Pause: 0.2s
                try? await Task.sleep(nanoseconds: 450_000_000) // 0.45 seconds
                
                // Clear saving state and enter reveal window
                isSaving = false
                isRevealingScore = true
                
                // Show reveal window for 1.5 seconds
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                
                // Clear reveal state before rotation
                isRevealingScore = false
                lastScoredVisit = nil
                
                // Process events for winner detection
                for event in events {
                    switch event {
                    case .matchWon(let winnerId):
                        if let winningPlayer = players.first(where: { $0.id == winnerId }) {
                            winner = winningPlayer
                            print("🏆 [RemoteGame] Winner detected from engine: \(winningPlayer.displayName)")
                            SoundManager.shared.playCountdownWinner()
                        }
                    case .legWon(let winnerId):
                        legsWon = newState.legsWon
                        print("🎯 [RemoteGame] Leg won by \(winnerId)")
                    default:
                        break
                    }
                }
                
                // Fallback: Check server scores for winner (in case engine missed it)
                if winner == nil, let serverScores = updatedMatch.playerScores {
                    for (playerId, score) in serverScores {
                        if score == 0 {
                            if let winningPlayer = players.first(where: { $0.id == playerId }) {
                                winner = winningPlayer
                                print("🏆 [RemoteGame] Winner detected from server scores: \(winningPlayer.displayName)")
                                SoundManager.shared.playCountdownWinner()
                                break
                            }
                        }
                    }
                }
                
                // Validate server state matches our prediction
                if let serverScores = updatedMatch.playerScores {
                    if serverScores != newState.scores {
                        print("⚠️ [RemoteGame] Server state mismatch - using server (this shouldn't happen)")
                        playerScores = serverScores
                    }
                }
                
                // Update currentPlayerIndex based on server's currentPlayerId
                if let newCurrentPlayerId = updatedMatch.currentPlayerId {
                    // Find the index of the player with this ID
                    if let newIndex = players.firstIndex(where: { $0.id == newCurrentPlayerId }) {
                        if newIndex != currentPlayerIndex {
                            // Player changed - trigger rotation animation
                            let oldPlayer = players[currentPlayerIndex].displayName
                            let newPlayer = players[newIndex].displayName
                            print("🔄 [RemoteGame] Turn rotation: \(oldPlayer) → \(newPlayer) (index \(currentPlayerIndex) → \(newIndex))")
                            isTransitioningPlayers = true
                            
                            // Brief delay for rotation animation
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                            
                            // Update to new player
                            currentPlayerIndex = newIndex
                            print("✅ [RemoteGame] Rotation complete - now player \(newIndex)")
                            
                            // Clear transition flag
                            isTransitioningPlayers = false
                            
                            // Update checkout for new player
                            updateCheckoutSuggestion()
                        } else {
                            print("ℹ️ [RemoteGame] No rotation needed - same player")
                            
                            // Update checkout for same player continuing
                            updateCheckoutSuggestion()
                        }
                    }
                }
                
            } catch {
                // Server error - keep UI consistent
                print("❌ [RemoteGame] Failed to save visit: \(error)")
                saveError = error.localizedDescription
                isSaving = false
                
                // Show error to user (could use toast/banner)
                // For now, just log it
            }
        }
    }
    
    /// Handle bust scenario (player went over or hit bust button)
    private func bustCurrentTurn() {
        let currentScore = playerScores[currentPlayer.id] ?? startingScore
        
        // Save turn history for bust
        saveTurnHistory(
            player: currentPlayer,
            darts: currentThrow,
            scoreBefore: currentScore,
            scoreAfter: currentScore,
            isBust: true
        )
        
        currentThrow.removeAll()
        selectedDartIndex = nil
        switchPlayer()
        
        // After a bust, recalculate checkout for the new current player
        updateCheckoutSuggestion()
    }
    
    /// Switch to the next player
    func switchPlayer() {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
        SoundManager.shared.resetMissCounter()
    }
    
    /// Undo the last visit (restore previous state)
    func undoLastVisit() {
        guard let visit = lastVisit else { return }
        guard winner == nil else { return } // Can't undo after game is won
        
        // Restore player score to previous value
        playerScores[visit.playerID] = visit.previousScore
        
        // Restore player index to what it was before the visit
        currentPlayerIndex = visit.currentPlayerIndex
        
        // Remove the last turn from history (if it matches this visit)
        if let lastHistoryTurn = turnHistory.last,
           lastHistoryTurn.player.id == visit.playerID {
            turnHistory.removeLast()
            self.lastTurn = turnHistory.last
        }
        
        // Clear the last visit (can only undo once)
        lastVisit = nil
        
        // Clear current throw
        currentThrow.removeAll()
        selectedDartIndex = nil
        
        // Update checkout suggestion for restored player
        updateCheckoutSuggestion()
        
        // Play subtle sound feedback
        SoundManager.shared.playButtonTap()
    }
    
    /// Restart the game with same players
    func restartGame() {
        // Reset all scores
        for player in players {
            playerScores[player.id] = startingScore
            legsWon[player.id] = 0
        }
        
        // Reset game state
        currentPlayerIndex = 0
        currentThrow.removeAll()
        winner = nil
        legWinner = nil
        isMatchWon = false
        lastTurn = nil
        turnHistory.removeAll()
        currentLeg = 1
        currentVisit = 1
        
        SoundManager.shared.resetMissCounter()
    }
    
    /// Reset for a new leg (after leg win but match continues)
    func resetLeg() {
        // Rotate player order for next leg
        rotatePlayerOrder()
        
        // Reset scores for new leg
        for player in players {
            playerScores[player.id] = startingScore
        }
        
        // Increment leg counter
        currentLeg += 1
        
        // Reset leg-specific state
        currentPlayerIndex = 0
        currentThrow.removeAll()
        selectedDartIndex = nil
        legWinner = nil
        lastTurn = nil
        turnHistory.removeAll()
        currentVisit = 1
        
        // Update checkout for first player
        updateCheckoutSuggestion()
        
        SoundManager.shared.resetMissCounter()
    }
    
    /// Rotate player order for multi-leg matches
    /// 2 players: alternate starting player (P1 P2 → P2 P1 → P1 P2)
    /// 3+ players: rotate entire order left by 1 (P1 P2 P3 P4 → P2 P3 P4 P1)
    private func rotatePlayerOrder() {
        guard players.count >= 2 else { return }
        
        if players.count == 2 {
            // Simple alternation for 2 players
            players.reverse()
        } else {
            // Rotate left by 1 for 3+ players
            let firstPlayer = players.removeFirst()
            players.append(firstPlayer)
        }
    }
    
    // MARK: - Private Helpers
    
    private func saveTurnHistory(
        player: Player,
        darts: [ScoredThrow],
        scoreBefore: Int,
        scoreAfter: Int,
        isBust: Bool
    ) {
        // Calculate turn number for this player
        let playerTurnCount = turnHistory.filter { $0.playerId == player.id }.count
        
        let turn = TurnHistory(
            player: player,
            playerId: player.id,
            turnNumber: playerTurnCount,
            darts: darts,
            scoreBefore: scoreBefore,
            scoreAfter: scoreAfter,
            isBust: isBust,
            gameMetadata: nil // 301/501/Countdown don't use game-specific metadata
        )
        
        turnHistory.append(turn)
        lastTurn = turn
    }
    
    // MARK: - Checkout Calculation
    
    /// Update the suggested checkout based on current score
    func updateCheckoutSuggestion() {
        let currentScore = playerScores[currentPlayer.id] ?? startingScore
        
        // At start of turn (no darts thrown), track if checkout is available
        if currentThrow.isEmpty {
            turnStartedWithCheckout = CheckoutCalculator.isCheckoutAvailable(score: currentScore)
        }
        
        // Use shared checkout calculator
        suggestedCheckout = CheckoutCalculator.suggestCheckout(
            currentScore: currentScore,
            currentThrowTotal: currentThrowTotal,
            dartsThrown: currentThrow.count,
            turnStartedWithCheckout: turnStartedWithCheckout
        )
        
        // Capture initial checkout at turn start (for opponent display in remote matches)
        if currentThrow.isEmpty {
            initialCheckoutForTurn = suggestedCheckout
        }
    }
    
    // MARK: - Match Storage
    
    /// Save match result to local storage and Supabase
    private func saveMatchResult() {
        guard let winner = winner else { return }
        guard let matchId = matchId else { return }
        guard !hasBeenSaved else {
            print("⚠️ Match already saved, skipping duplicate save")
            return
        }
        hasBeenSaved = true
        
        let matchDuration = Date().timeIntervalSince(matchStartTime)
        
        // Build match players with their data
        let matchPlayers = players.map { player in
            let finalScore = playerScores[player.id] ?? startingScore
            let playerTurns = turnHistory.filter { $0.player.id == player.id }
            
            // Convert turn history to match turns
            let matchTurns = playerTurns.enumerated().map { index, turn in
                let matchDarts = turn.darts.map { dart in
                    MatchDart(baseValue: dart.baseValue, multiplier: dart.scoreType.multiplier)
                }
                return MatchTurn(
                    turnNumber: index + 1,
                    darts: matchDarts,
                    scoreBefore: turn.scoreBefore,
                    scoreAfter: turn.scoreAfter,
                    isBust: turn.isBust
                )
            }
            
            let totalDarts = playerTurns.reduce(0) { $0 + $1.darts.count }
            
            let playerLegsWon = legsWon[player.id] ?? 0
            
            return MatchPlayer.from(
                player: player,
                finalScore: finalScore,
                startingScore: startingScore,
                totalDartsThrown: totalDarts,
                turns: matchTurns,
                legsWon: playerLegsWon
            )
        }
        
        // Create match result with the same matchId
        let matchResult = MatchResult(
            id: matchId,
            gameType: game.title,
            gameName: game.title,
            players: matchPlayers,
            winnerId: winner.userId ?? winner.id,
            duration: matchDuration,
            matchFormat: matchFormat,
            totalLegsPlayed: currentLeg,
            metadata: nil // No game-specific metadata for countdown games
        )
        
        // Store match result for passing to GameEndView (instant access)
        self.savedMatchResult = matchResult
        
        // Save to local storage
        MatchStorageManager.shared.saveMatch(matchResult)
        
        // Update player stats
        MatchStorageManager.shared.updatePlayerStats(for: matchPlayers, winnerId: winner.userId ?? winner.id)
        
        // Log game completed event
        let gameType = game.title.contains("301") ? "301" : "501"
        let winnerType = winner.userId != nil ? "user" : "guest"
        let totalThrows = matchPlayers.reduce(0) { $0 + $1.totalDartsThrown }
        analytics.logGameCompleted(
            gameType: gameType,
            winnerType: winnerType,
            durationSeconds: Int(matchDuration),
            totalThrows: totalThrows,
            matchFormat: matchFormat
        )
        
        // Capture current user ID before entering Task (to avoid race conditions)
        let currentUserId = authService?.currentUser?.id
        print("🔍 Captured current user ID before Task: \(currentUserId?.uuidString ?? "nil")")
        print("🔍 AuthService injected: \(authService != nil)")
        
        // Save to Supabase (async, non-blocking)
        Task {
            do {
                let matchService = MatchService()
                
                // Determine game ID for database
                let gameId = game.title.lowercased().replacingOccurrences(of: " ", with: "_")
                
                // Get winner's ID (userId for connected players, player.id for guests)
                let winnerId = winner.userId ?? winner.id
                
                let updatedUser = try await matchService.saveMatch(
                    matchId: matchId,
                    gameId: gameId,
                    players: players,
                    winnerId: winnerId,
                    startedAt: matchStartTime,
                    endedAt: Date(),
                    turnHistory: turnHistory,
                    matchFormat: matchFormat,
                    legsWon: legsWon,
                    currentUserId: currentUserId
                )
                
                print("✅ Match saved to Supabase: \(matchId)")
                
                // Delete from local storage after successful sync (member matches only)
                await MainActor.run {
                    MatchStorageManager.shared.deleteMatch(withId: matchId)
                    print("🗑️ Member match removed from local storage after sync: \(matchId)")
                }
                
                // Update AuthService with the fresh user data directly (no need to query again!)
                if let updatedUser = updatedUser {
                    await MainActor.run {
                        // Update the injected authService (which is the same as AuthService.shared)
                        self.authService?.currentUser = updatedUser
                        self.authService?.objectWillChange.send()
                    }
                    print("✅ User profile updated with fresh stats: \(updatedUser.totalWins)W/\(updatedUser.totalLosses)L")
                }
                
                // Notify that match completed so other views can refresh
                NotificationCenter.default.post(name: NSNotification.Name("MatchCompleted"), object: nil)
            } catch {
                print("❌ Failed to save match to Supabase: \(error)")
                // Don't block UI - match is still saved locally
            }
        }
    }
}
