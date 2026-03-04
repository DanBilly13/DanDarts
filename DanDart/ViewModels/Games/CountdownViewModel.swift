//
//  CountdownViewModel.swift
//  Dart Freak
//
//  Game state manager for countdown games (301/501)
//  Handles scoring, turn management, and win detection
//

import SwiftUI

@MainActor
class CountdownViewModel: ObservableObject {
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
    
    // Services
    private var authService: AuthService?
    private let analytics = AnalyticsService.shared
    
    /// Inject AuthService from the view
    func setAuthService(_ service: AuthService) {
        self.authService = service
    }
    
    // Animation state
    @Published var showScoreAnimation: Bool = false // Triggers arcade-style score pop
    @Published var isTransitioningPlayers: Bool = false // True during player switch animation
    
    // Match saving
    @Published var matchId: UUID? = nil // ID for saved match
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
    
    init(game: Game, players: [Player], matchFormat: Int = 1) {
        self.game = game
        // Randomize player order for fair play
        let shuffledPlayers = players.shuffled()
        self.players = shuffledPlayers
        self.originalPlayerOrder = shuffledPlayers // Store for color consistency
        self.matchStartTime = Date()
        self.matchFormat = matchFormat
        
        // Create match ID for saving
        self.matchId = UUID()
        
        // Determine starting score based on game type
        if game.title.contains("301") {
            self.startingScore = 301
        } else if game.title.contains("501") {
            self.startingScore = 501
        } else {
            self.startingScore = 301 // Default
        }
        
        // Initialize player scores
        for player in self.players {
            playerScores[player.id] = startingScore
            legsWon[player.id] = 0
        }
        
        // Log game started event
        let gameType = game.title.contains("301") ? "301" : "501"
        let hasGuests = players.contains(where: { $0.userId == nil })
        analytics.logGameStarted(
            gameType: gameType,
            playerCount: players.count,
            hasGuests: hasGuests,
            matchFormat: matchFormat
        )
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
    
    /// Save the current turn and switch to next player
    func saveScore() {
        guard !currentThrow.isEmpty else { return }
        guard winner == nil else { return }
        
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
        
        // Apply visit through engine (pure rules)
        let (newState, events) = CountdownEngine.applyVisit(
            state: engineState,
            playerId: currentPlayer.id,
            darts: currentThrow
        )
        
        // Extract values for turn history
        let throwTotal = currentThrowTotal
        let currentScore = playerScores[currentPlayer.id] ?? startingScore
        
        // Process events and update UI
        for event in events {
            switch event {
            case .busted(let playerId):
                // Play bust sound
                SoundManager.shared.playCountdownBust()
                
                saveTurnHistory(
                    player: currentPlayer,
                    darts: currentThrow,
                    scoreBefore: currentScore,
                    scoreAfter: currentScore,
                    isBust: true
                )
                
                currentThrow.removeAll()
                selectedDartIndex = nil
                turnStartedWithCheckout = false
                
                // Update state from engine
                currentPlayerIndex = newState.currentPlayerIndex
                
                // Set transition flag to hide bust button during switch
                isTransitioningPlayers = true
                
                // Increment visit counter after all players complete their turn
                if turnHistory.count % players.count == 0 {
                    currentVisit += 1
                }
                
                updateCheckoutSuggestion()
                
                // Clear transition flag after brief delay
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    isTransitioningPlayers = false
                }
                return
                
            case .scored(let playerId, let before, let after):
                // Record visit for undo functionality
                lastVisit = Visit(
                    playerID: playerId,
                    playerName: currentPlayer.displayName,
                    dartsThrown: currentThrow,
                    scoreChange: throwTotal,
                    previousScore: before,
                    newScore: after,
                    currentPlayerIndex: currentPlayerIndex
                )
                
                // Update scores from engine
                playerScores = newState.scores
                
                // Play appropriate sound
                if after == 0 {
                    SoundManager.shared.playCountdownWinner()
                } else {
                    SoundManager.shared.playCountdownSaveScore()
                }
                
                // Trigger score animation
                showScoreAnimation = true
                
                // Save turn history
                saveTurnHistory(
                    player: currentPlayer,
                    darts: currentThrow,
                    scoreBefore: before,
                    scoreAfter: after,
                    isBust: false
                )
                
            case .legWon(let winnerId):
                legWinner = players.first { $0.id == winnerId }
                legsWon = newState.legsWon
                
                // Play lighter celebration for leg win
                SoundManager.shared.playScoreSound()
                
            case .matchWon(let winnerId):
                winner = players.first { $0.id == winnerId }
                isMatchWon = true
                legsWon = newState.legsWon
                
                // Save match result to local storage
                saveMatchResult()
                
                // Winner detected - clear state but don't switch players
                currentThrow.removeAll()
                selectedDartIndex = nil
                return
            }
        }
        
        // Check if leg won (match continues)
        if events.contains(where: { if case .legWon = $0 { return true } else { return false } }) &&
           !events.contains(where: { if case .matchWon = $0 { return true } else { return false } }) {
            // Leg won but match continues
            currentThrow.removeAll()
            selectedDartIndex = nil
            turnStartedWithCheckout = false
            return
        }
        
        // Normal turn - clear and switch player
        currentThrow.removeAll()
        selectedDartIndex = nil
        turnStartedWithCheckout = false
        
        // Set transition flag to hide bust button during animation
        isTransitioningPlayers = true
        
        // Delay player switch to allow score animation to complete
        Task {
            // Wait for animation to complete (grow + immediate shrink)
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
            showScoreAnimation = false
            
            // Pause before rotating cards
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds pause
            
            // Update player index from engine
            currentPlayerIndex = newState.currentPlayerIndex
            
            // Increment visit counter after all players complete their turn
            if turnHistory.count % players.count == 0 {
                currentVisit += 1
            }
            
            updateCheckoutSuggestion()
            
            // Clear transition flag after player switch completes
            isTransitioningPlayers = false
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

// MARK: - Turn History Model

struct TurnHistory: Identifiable {
    let id = UUID()
    let player: Player
    let playerId: UUID // For easier lookup
    let turnNumber: Int // Turn index for this player
    let darts: [ScoredThrow]
    let scoreBefore: Int
    let scoreAfter: Int
    let isBust: Bool
    let timestamp: Date = Date()
    let gameMetadata: [String: String]? // Game-specific data (e.g., Halve-It: target_display)
    
    var throwTotal: Int {
        darts.reduce(0) { $0 + $1.totalValue }
    }
    
    var displayText: String {
        let dartsText = darts.map { $0.displayText }.joined(separator: ", ")
        if isBust {
            return "\(dartsText) - BUST"
        } else {
            return "\(dartsText) = \(throwTotal)"
        }
    }
}
