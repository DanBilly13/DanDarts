//
//  HalveItViewModel.swift
//  DanDart
//
//  Game state manager for Halve It game
//  Handles scoring, turn management, and win detection
//

import Foundation
import Combine

@MainActor
class HalveItViewModel: ObservableObject {
    // MARK: - Game Configuration
    let players: [Player]
    let difficulty: HalveItDifficulty
    let targets: [HalveItTarget]
    let matchId: UUID
    let gameId: UUID
    
    // MARK: - Game State
    @Published var currentPlayerIndex: Int = 0
    @Published var currentRound: Int = 0  // 0-5 (6 rounds total)
    @Published var currentThrow: [ScoredThrow] = []
    @Published var selectedDartIndex: Int? = nil  // For tap-to-edit functionality
    @Published var playerScores: [UUID: Int] = [:]  // Player ID -> current score
    @Published var isGameOver: Bool = false
    @Published var winner: Player?
    
    // Animation state
    @Published var showScoreAnimation: Bool = false // Triggers arcade-style score pop
    
    // MARK: - Turn History
    @Published var turnHistory: [HalveItTurnHistory] = []
    
    // MARK: - Computed Properties
    var currentPlayer: Player {
        players[currentPlayerIndex]
    }
    
    var currentTarget: HalveItTarget {
        targets[currentRound]
    }
    
    var currentPlayerScore: Int {
        playerScores[currentPlayer.id] ?? 0
    }
    
    var isTurnComplete: Bool {
        // Turn is complete when all 3 darts are thrown
        currentThrow.count == 3
    }
    
    // MARK: - Initialization
    init(players: [Player], difficulty: HalveItDifficulty, matchId: UUID = UUID(), gameId: UUID) {
        self.players = players
        self.difficulty = difficulty
        self.targets = difficulty.generateTargets()
        self.matchId = matchId
        self.gameId = gameId
        
        // Initialize all players with 0 score
        for player in players {
            playerScores[player.id] = 0
        }
    }
    
    // MARK: - Dart Input
    
    /// Record a dart throw
    func recordThrow(baseValue: Int, scoreType: ScoreType) {
        // If a dart is selected, replace it instead of appending
        if let selectedIndex = selectedDartIndex, selectedIndex < currentThrow.count {
            let dart = ScoredThrow(baseValue: baseValue, scoreType: scoreType)
            currentThrow[selectedIndex] = dart
            selectedDartIndex = nil  // Clear selection after replacement
        } else {
            // Normal append behavior
            guard currentThrow.count < 3 else { return }
            let dart = ScoredThrow(baseValue: baseValue, scoreType: scoreType)
            currentThrow.append(dart)
        }
    }
    
    /// Select a dart for editing
    func selectDart(at index: Int) {
        guard index < currentThrow.count else { return }
        selectedDartIndex = (selectedDartIndex == index) ? nil : index  // Toggle selection
    }
    
    /// Undo the last dart in current throw
    func undoLastDart() {
        guard !currentThrow.isEmpty else { return }
        currentThrow.removeLast()
        selectedDartIndex = nil  // Clear selection when undoing
    }
    
    /// Clear all darts in current throw
    func clearThrow() {
        currentThrow.removeAll()
        selectedDartIndex = nil  // Clear selection when clearing
    }
    
    // MARK: - Turn Management
    
    /// Complete the current turn and calculate score
    func completeTurn() {
        let scoreBefore = currentPlayerScore
        var pointsScored = 0
        var hitTarget = false
        
        // Calculate points from hitting target
        for dart in currentThrow {
            if currentTarget.isHit(by: dart) {
                pointsScored += currentTarget.points(for: dart)
                hitTarget = true
            }
        }
        
        // Determine new score
        let scoreAfter: Int
        if currentThrow.isEmpty || (!hitTarget && currentThrow.count == 3) {
            // Missed all 3 darts - halve score (round up)
            scoreAfter = Int(ceil(Double(scoreBefore) / 2.0))
        } else {
            // Hit target - add points
            scoreAfter = scoreBefore + pointsScored
        }
        
        // Update player score
        playerScores[currentPlayer.id] = scoreAfter
        
        // Trigger score animation (arcade-style pop)
        showScoreAnimation = true
        
        // Record turn in history (include ALL darts thrown for accurate stats)
        let turnRecord = HalveItTurnHistory(
            playerId: currentPlayer.id,
            playerName: currentPlayer.displayName,
            round: currentRound,
            target: currentTarget,
            darts: currentThrow, // All darts thrown (for accurate hit rate calculation)
            scoreBefore: scoreBefore,
            scoreAfter: scoreAfter,
            pointsScored: pointsScored,
            wasHalved: !hitTarget && currentThrow.count == 3
        )
        turnHistory.append(turnRecord)
        
        // Clear current throw and selection
        currentThrow.removeAll()
        selectedDartIndex = nil
        
        // Delay player/round switch to allow score animation to complete
        Task {
            // Wait for animation to complete (grow + immediate shrink)
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
            showScoreAnimation = false
            
            // Pause before rotating cards
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds pause
            
            // Move to next player or next round
            if currentPlayerIndex < players.count - 1 {
                // Next player's turn in same round
                currentPlayerIndex += 1
            } else {
                // All players finished this round
                currentPlayerIndex = 0
                
                if currentRound < targets.count - 1 {
                    // Move to next round
                    currentRound += 1
                } else {
                    // Game over - all rounds complete
                    endGame()
                }
            }
        }
    }
    
    // MARK: - Game End
    
    private func endGame() {
        isGameOver = true
        
        // Find winner (highest score)
        var highestScore = 0
        var winningPlayer: Player?
        
        for player in players {
            let score = playerScores[player.id] ?? 0
            if score > highestScore {
                highestScore = score
                winningPlayer = player
            }
        }
        
        winner = winningPlayer
        
        // Save match result
        saveMatchResult()
    }
    
    // MARK: - Match Storage
    
    /// Save match result to local storage and Supabase
    private func saveMatchResult() {
        guard let winner = winner else { return }
        
        // Convert turn history to MatchTurn format
        let matchTurns = convertTurnHistory()
        
        // Create match players with final scores
        let matchPlayers = players.map { player in
            let playerTurns = matchTurns.filter { $0.id == player.id }
            let totalDarts = playerTurns.reduce(0) { $0 + $1.darts.count }
            
            return MatchPlayer(
                id: player.id,
                displayName: player.displayName,
                nickname: player.nickname,
                avatarURL: player.avatarURL,
                isGuest: player.isGuest,
                finalScore: playerScores[player.id] ?? 0,
                startingScore: 0, // Halve-It starts at 0
                totalDartsThrown: totalDarts,
                turns: playerTurns,
                legsWon: 0 // Halve-It doesn't use legs
            )
        }
        
        // Create match result with difficulty metadata
        let matchResult = MatchResult(
            id: matchId,
            gameType: "Halve It",
            gameName: "Halve It",
            players: matchPlayers,
            winnerId: winner.id,
            timestamp: Date(),
            duration: 600, // Approximate duration
            matchFormat: 1,
            totalLegsPlayed: 1,
            metadata: ["difficulty": difficulty.rawValue]
        )
        
        // Save to local storage
        MatchStorageManager.shared.saveMatch(matchResult)
        
        // Save to Supabase (async)
        Task {
            do {
                let matchService = MatchService()
                
                // Determine game ID for database (should be "halve_it", not UUID)
                let supabaseGameId = "halve_it"
                
                // Get winner's user ID (nil for guests)
                let winnerId = winner.userId
                
                // Convert turn history to TurnHistory format
                let supabaseTurns = turnHistory.enumerated().map { index, turn in
                    let player = players.first { $0.id == turn.playerId }!
                    return TurnHistory(
                        player: player,
                        playerId: turn.playerId,
                        turnNumber: index + 1,
                        darts: turn.darts,
                        scoreBefore: turn.scoreBefore,
                        scoreAfter: turn.scoreAfter,
                        isBust: false,
                        gameMetadata: ["target_display": turn.target.displayText] // Add target info
                    )
                }
                
                try await matchService.saveMatch(
                    matchId: matchId,
                    gameId: supabaseGameId,
                    players: players,
                    winnerId: winnerId,
                    startedAt: Date().addingTimeInterval(-600), // Approximate start time
                    endedAt: Date(),
                    turnHistory: supabaseTurns,
                    matchFormat: 1, // Halve-It doesn't use legs
                    legsWon: [:] // Halve-It doesn't use legs
                )
            } catch {
                print("Failed to save match to Supabase: \(error)")
            }
        }
    }
    
    /// Convert turn history to generic format for storage
    private func convertTurnHistory() -> [MatchTurn] {
        return turnHistory.map { turn in
            let darts = turn.darts.map { dart in
                MatchDart(
                    baseValue: dart.baseValue,
                    multiplier: dart.scoreType.multiplier
                )
            }
            
            return MatchTurn(
                // id auto-generates via default parameter
                turnNumber: turn.round + 1,
                darts: darts,
                scoreBefore: turn.scoreBefore,
                scoreAfter: turn.scoreAfter,
                isBust: false, // Halve-It doesn't have busts
                targetDisplay: turn.target.displayText // Add target info for match history
            )
        }
    }
    
    // MARK: - Game Reset
    
    func resetGame() {
        currentPlayerIndex = 0
        currentRound = 0
        currentThrow.removeAll()
        selectedDartIndex = nil
        isGameOver = false
        winner = nil
        turnHistory.removeAll()
        
        // Reset all scores to 0
        for player in players {
            playerScores[player.id] = 0
        }
    }
}

// MARK: - Turn History Model

struct HalveItTurnHistory: Identifiable {
    let id = UUID()
    let playerId: UUID
    let playerName: String
    let round: Int
    let target: HalveItTarget
    let darts: [ScoredThrow]
    let scoreBefore: Int
    let scoreAfter: Int
    let pointsScored: Int
    let wasHalved: Bool
}
