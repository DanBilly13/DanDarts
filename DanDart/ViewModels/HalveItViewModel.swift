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
    
    // MARK: - Game State
    @Published var currentPlayerIndex: Int = 0
    @Published var currentRound: Int = 0  // 0-5 (6 rounds total)
    @Published var currentThrow: [ScoredThrow] = []
    @Published var playerScores: [UUID: Int] = [:]  // Player ID -> current score
    @Published var isGameOver: Bool = false
    @Published var winner: Player?
    
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
    
    // MARK: - Initialization
    init(players: [Player], difficulty: HalveItDifficulty) {
        self.players = players
        self.difficulty = difficulty
        self.targets = difficulty.generateTargets()
        
        // Initialize all players with 0 score
        for player in players {
            playerScores[player.id] = 0
        }
    }
    
    // MARK: - Dart Input
    
    /// Record a dart throw
    func recordThrow(baseValue: Int, scoreType: ScoreType) {
        guard currentThrow.count < 3 else { return }
        
        let dart = ScoredThrow(baseValue: baseValue, scoreType: scoreType)
        currentThrow.append(dart)
    }
    
    /// Undo the last dart in current throw
    func undoLastDart() {
        guard !currentThrow.isEmpty else { return }
        currentThrow.removeLast()
    }
    
    /// Clear all darts in current throw
    func clearThrow() {
        currentThrow.removeAll()
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
        
        // Record turn in history
        let turnRecord = HalveItTurnHistory(
            playerId: currentPlayer.id,
            playerName: currentPlayer.displayName,
            round: currentRound,
            target: currentTarget,
            darts: currentThrow,
            scoreBefore: scoreBefore,
            scoreAfter: scoreAfter,
            pointsScored: pointsScored,
            wasHalved: !hitTarget && currentThrow.count == 3
        )
        turnHistory.append(turnRecord)
        
        // Clear current throw
        currentThrow.removeAll()
        
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
    }
    
    // MARK: - Game Reset
    
    func resetGame() {
        currentPlayerIndex = 0
        currentRound = 0
        currentThrow.removeAll()
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
