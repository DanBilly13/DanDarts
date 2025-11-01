//
//  CountdownViewModel.swift
//  DanDart
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
    
    // Multi-leg match tracking
    @Published var currentLeg: Int = 1
    @Published var legsWon: [UUID: Int] = [:] // Player ID to legs won
    @Published var matchFormat: Int // Total legs in match (1, 3, 5, or 7)
    @Published var legWinner: Player? = nil // Winner of current leg (before match winner)
    @Published var isMatchWon: Bool = false // True when match is won (not just leg)
    
    // Animation state
    @Published var showScoreAnimation: Bool = false // Triggers arcade-style score pop
    
    // Match saving
    @Published var matchId: UUID? = nil // ID for saved match
    
    // Game configuration
    let game: Game
    let startingScore: Int
    private let matchStartTime: Date
    
    // MARK: - Computed Properties
    
    var currentPlayer: Player {
        players[currentPlayerIndex]
    }
    
    var isTurnComplete: Bool {
        // Turn is complete if:
        // 1. All 3 darts thrown
        // 2. Bust recorded
        // 3. Player has reached exactly zero (winner)
        if currentThrow.count == 3 || currentThrow.contains(where: { $0.baseValue == -1 }) {
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
    
    // MARK: - Initialization
    
    init(game: Game, players: [Player], matchFormat: Int = 1) {
        self.game = game
        self.players = players
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
        for player in players {
            playerScores[player.id] = startingScore
            legsWon[player.id] = 0
        }
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
        
        // If a dart is selected, replace it instead of appending
        if let selectedIndex = selectedDartIndex, selectedIndex < currentThrow.count {
            currentThrow[selectedIndex] = scoredThrow
            selectedDartIndex = nil // Deselect after replacement
        } else if currentThrow.count < 3 {
            // Otherwise append if we have room
            currentThrow.append(scoredThrow)
        }
        
        // Play sound effects
        if scoredThrow.totalValue == 0 {
            SoundManager.shared.playMissSound()
        } else {
            SoundManager.shared.playScoreSound()
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
    
    /// Save the current turn and switch to next player
    func saveScore() {
        guard !currentThrow.isEmpty else { return }
        guard winner == nil else { return }
        
        let throwTotal = currentThrowTotal
        let currentScore = playerScores[currentPlayer.id] ?? startingScore
        let newScore = currentScore - throwTotal
        
        // Check for bust (score would go below 0, exactly 1, or finish without double)
        let isBustTurn = newScore < 0 || newScore == 1
        
        // If reaching exactly 0, must finish on a double
        let finishedOnDouble = if newScore == 0 {
            currentThrow.last?.scoreType == .double
        } else {
            false
        }
        
        if isBustTurn || (newScore == 0 && !finishedOnDouble) {
            // Bust - score stays the same
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
            
            // Update checkout for new player
            updateCheckoutSuggestion()
            return
        }
        
        // Valid score - update player score
        playerScores[currentPlayer.id] = newScore
        
        // Trigger score animation (arcade-style pop)
        showScoreAnimation = true
        
        // Save turn history before checking for winner
        saveTurnHistory(
            player: currentPlayer,
            darts: currentThrow,
            scoreBefore: currentScore,
            scoreAfter: newScore,
            isBust: false
        )
        
        // Check for leg winner (must finish on exactly 0)
        if newScore == 0 {
            legWinner = currentPlayer
            
            // Increment leg count for winner
            legsWon[currentPlayer.id, default: 0] += 1
            
            // Calculate legs needed to win match
            let legsNeededToWin = (matchFormat / 2) + 1 // Best of 3 = 2, Best of 5 = 3, etc.
            let currentPlayerLegs = legsWon[currentPlayer.id] ?? 0
            
            // Check if match is won
            if currentPlayerLegs >= legsNeededToWin {
                // Match won!
                winner = currentPlayer
                isMatchWon = true
                
                // Play celebration sound
                SoundManager.shared.playGameWin()
                
                // Save match result to local storage
                saveMatchResult()
                
                // Winner detected - clear state but don't switch players
                currentThrow.removeAll()
                selectedDartIndex = nil
                return
            } else {
                // Leg won but match continues
                // Play lighter celebration for leg win
                SoundManager.shared.playScoreSound()
                
                // Clear current throw and selection
                currentThrow.removeAll()
                selectedDartIndex = nil
                
                // Note: UI should show leg win celebration before calling resetLeg()
                // Don't automatically reset here - let UI handle the transition
                return
            }
        }
        
        // Clear current throw and selection
        currentThrow.removeAll()
        selectedDartIndex = nil
        
        // Delay player switch to allow score animation to complete
        Task {
            // Wait for animation to complete (grow + immediate shrink)
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
            showScoreAnimation = false
            
            // Pause before rotating cards
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds pause
            switchPlayer()
            updateCheckoutSuggestion()
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
        switchPlayer()
    }
    
    /// Switch to the next player
    func switchPlayer() {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
        SoundManager.shared.resetMissCounter()
    }
    
    /// Undo the last turn (restore previous state)
    func undoLastTurn() {
        guard let lastTurn = lastTurn else { return }
        guard winner == nil else { return } // Can't undo after game is won
        
        // Restore player score
        playerScores[lastTurn.player.id] = lastTurn.scoreBefore
        
        // Switch back to previous player
        currentPlayerIndex = players.firstIndex(where: { $0.id == lastTurn.player.id }) ?? 0
        
        // Remove last turn from history
        if let index = turnHistory.firstIndex(where: { $0.id == lastTurn.id }) {
            turnHistory.remove(at: index)
        }
        
        // Update lastTurn to the new last turn (if any)
        self.lastTurn = turnHistory.last
        
        // Clear current throw
        currentThrow.removeAll()
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
        
        SoundManager.shared.resetMissCounter()
    }
    
    /// Reset for a new leg (after leg win but match continues)
    func resetLeg() {
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
        
        // Update checkout for first player
        updateCheckoutSuggestion()
        
        SoundManager.shared.resetMissCounter()
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
        let remainingAfterThrow = currentScore - currentThrowTotal
        let dartsLeft = 3 - currentThrow.count
        
        // Only suggest checkouts for scores 2-170 with darts remaining
        guard remainingAfterThrow >= 2 && remainingAfterThrow <= 170 && dartsLeft > 0 else {
            suggestedCheckout = nil
            return
        }
        
        // Calculate checkout based on darts remaining
        if let checkout = calculateCheckout(score: remainingAfterThrow, dartsAvailable: dartsLeft) {
            suggestedCheckout = checkout
        } else {
            suggestedCheckout = nil
        }
    }
    
    /// Calculate the optimal checkout for a given score
    private func calculateCheckout(score: Int, dartsAvailable: Int) -> String? {
        // Can't checkout on 1 or above 170
        guard score >= 2 && score <= 170 else { return nil }
        
        // Check if we have a pre-calculated checkout
        if let checkout = CheckoutChart.checkouts[score] {
            // Verify we have enough darts for this checkout
            let dartsNeeded = checkout.components(separatedBy: " → ").count
            if dartsNeeded <= dartsAvailable {
                return checkout
            }
        }
        
        return nil
    }
    
    // MARK: - Checkout Chart
    
    struct CheckoutChart {
    /// Standard dart checkout chart (2-170)
    /// Format: "D20" = Double 20, "T20" = Triple 20, "Bull" = Bullseye (50)
    static let checkouts: [Int: String] = [
        // 2-40: Single dart checkouts (doubles only)
        2: "D1", 4: "D2", 6: "D3", 8: "D4", 10: "D5",
        12: "D6", 14: "D7", 16: "D8", 18: "D9", 20: "D10",
        22: "D11", 24: "D12", 26: "D13", 28: "D14", 30: "D15",
        32: "D16", 34: "D17", 36: "D18", 38: "D19", 40: "D20",
        
        // Odd numbers 3-39: Two dart checkouts (single + double)
        3: "1 → D1", 5: "1 → D2", 7: "3 → D2", 9: "1 → D4", 11: "3 → D4",
        13: "5 → D4", 15: "7 → D4", 17: "9 → D4", 19: "3 → D8", 21: "5 → D8",
        23: "7 → D8", 25: "9 → D8", 27: "11 → D8", 29: "13 → D8", 31: "15 → D8",
        33: "17 → D8", 35: "3 → D16", 37: "5 → D16", 39: "7 → D16",
        
        // 41-60: Two dart checkouts
        41: "9 → D16", 42: "10 → D16", 43: "11 → D16", 44: "12 → D16", 45: "13 → D16",
        46: "6 → D20", 47: "15 → D16", 48: "16 → D16", 49: "17 → D16", 50: "Bull",
        51: "19 → D16", 52: "20 → D16", 53: "13 → D20", 54: "14 → D20", 55: "15 → D20",
        56: "16 → D20", 57: "17 → D20", 58: "18 → D20", 59: "19 → D20", 60: "20 → D20",
        
        // 61-80: Two dart checkouts
        61: "T15 → D8", 62: "T10 → D16", 63: "T13 → D12", 64: "T16 → D8", 65: "T11 → D16",
        66: "T10 → D18", 67: "T17 → D8", 68: "T20 → D4", 69: "T19 → D6", 70: "T18 → D8",
        71: "T13 → D16", 72: "T16 → D12", 73: "T19 → D8", 74: "T14 → D16", 75: "T17 → D12",
        76: "T20 → D8", 77: "T15 → D16", 78: "T18 → D12", 79: "T13 → D20", 80: "T20 → D10",
        
        // 81-100: Two dart checkouts
        81: "T19 → D12", 82: "Bull → D16", 83: "T17 → D16", 84: "T20 → D12", 85: "T15 → D20",
        86: "T18 → D16", 87: "T17 → D18", 88: "T16 → D20", 89: "T19 → D16", 90: "T18 → D18",
        91: "T17 → D20", 92: "T20 → D16", 93: "T19 → D18", 94: "T18 → D20", 95: "T19 → D19",
        96: "T20 → D18", 97: "T19 → D20", 98: "T20 → D19", 99: "T19 → D21", 100: "T20 → D20",
        
        // 101-120: Three dart checkouts
        101: "T17 → 10 → D20", 102: "T20 → 10 → D16", 103: "T19 → 10 → D18", 104: "T18 → 10 → D20",
        105: "T20 → 13 → D16", 106: "T20 → 14 → D16", 107: "T19 → Bull", 108: "T20 → 16 → D16",
        109: "T20 → 17 → D16", 110: "T20 → Bull", 111: "T20 → 19 → D16", 112: "T20 → 20 → D16",
        113: "T20 → 13 → D20", 114: "T20 → 14 → D20", 115: "T20 → 15 → D20", 116: "T20 → 16 → D20",
        117: "T20 → 17 → D20", 118: "T20 → 18 → D20", 119: "T20 → 19 → D20", 120: "T20 → 20 → D20",
        
        // 121-140: Three dart checkouts
        121: "T20 → T11 → D14", 122: "T18 → T18 → D7", 123: "T19 → T16 → D9", 124: "T20 → T16 → D8",
        125: "T20 → T15 → D10", 126: "T19 → T19 → D6", 127: "T20 → T17 → D8", 128: "T18 → T14 → D16",
        129: "T19 → T16 → D12", 130: "T20 → T18 → D8", 131: "T20 → T13 → D16", 132: "T20 → T16 → D12",
        133: "T20 → T19 → D8", 134: "T20 → T14 → D16", 135: "T20 → T17 → D12", 136: "T20 → T20 → D8",
        137: "T20 → T15 → D16", 138: "T20 → T18 → D12", 139: "T20 → T13 → D20", 140: "T20 → T20 → D10",
        
        // 141-160: Three dart checkouts
        141: "T20 → T19 → D12", 142: "T20 → T14 → D20", 143: "T20 → T17 → D16", 144: "T20 → T20 → D12",
        145: "T20 → T15 → D20", 146: "T20 → T18 → D16", 147: "T20 → T17 → D18", 148: "T20 → T16 → D20",
        149: "T20 → T19 → D16", 150: "T20 → T18 → D18", 151: "T20 → T17 → D20", 152: "T20 → T20 → D16",
        153: "T20 → T19 → D18", 154: "T20 → T18 → D20", 155: "T20 → T19 → D19", 156: "T20 → T20 → D18",
        157: "T20 → T19 → D20", 158: "T20 → T20 → D19", 159: "T20 → T19 → D21", 160: "T20 → T20 → D20",
        
        // 161-170: Three dart checkouts
        161: "T20 → T17 → Bull", 162: "T20 → T18 → Bull", 163: "T20 → T19 → Bull", 164: "T20 → T18 → Bull",
        165: "T20 → T19 → Bull", 166: "T20 → T18 → Bull", 167: "T20 → T19 → Bull", 168: "T20 → T20 → Bull",
        169: "T20 → T19 → Bull", 170: "T20 → T20 → Bull"
    ]
}
    
    // MARK: - Match Storage
    
    /// Save match result to local storage and Supabase
    private func saveMatchResult() {
        guard let winner = winner else { return }
        guard let matchId = matchId else { return }
        
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
            winnerId: winner.id,
            duration: matchDuration,
            matchFormat: matchFormat,
            totalLegsPlayed: currentLeg,
            metadata: nil // No game-specific metadata for countdown games
        )
        
        // Save to local storage
        MatchStorageManager.shared.saveMatch(matchResult)
        
        // Update player stats
        MatchStorageManager.shared.updatePlayerStats(for: matchPlayers, winnerId: winner.id)
        
        // Save to Supabase (async, non-blocking)
        Task {
            do {
                let matchService = MatchService()
                
                // Determine game ID for database
                let gameId = game.title.lowercased().replacingOccurrences(of: " ", with: "_")
                
                // Get winner's user ID (nil for guests)
                let winnerId = winner.userId
                
                try await matchService.saveMatch(
                    matchId: matchId,
                    gameId: gameId,
                    players: players,
                    winnerId: winnerId,
                    startedAt: matchStartTime,
                    endedAt: Date(),
                    turnHistory: turnHistory,
                    matchFormat: matchFormat,
                    legsWon: legsWon
                )
                
                print("✅ Match saved to Supabase: \(matchId)")
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
