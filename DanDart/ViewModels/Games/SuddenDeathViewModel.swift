//
//  SuddenDeathViewModel.swift
//  DanDart
//
//  Created by DanDarts Team
//

import Foundation
import SwiftUI

@MainActor
class SuddenDeathViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var players: [Player]
    @Published var currentPlayerIndex: Int = 0
    @Published var playerToBeatIndex: Int = 0
    @Published var currentThrow: [ScoredThrow] = []
    @Published var selectedDartIndex: Int? = nil
    @Published var winner: Player? = nil
    @Published var isGameOver: Bool = false
    
    // Lives tracking: [Player.id: remaining lives]
    @Published var playerLives: [UUID: Int] = [:]
    
    // Scores tracking: [Player.id: current turn score]
    @Published var currentTurnScores: [UUID: Int] = [:]
    
    // Score to beat (from player to beat)
    @Published var scoreToBeat: Int = 0
    
    // MARK: - Properties
    
    let startingLives: Int
    private let soundManager = SoundManager.shared
    
    // MARK: - Computed Properties
    
    var currentPlayer: Player {
        players[currentPlayerIndex]
    }
    
    var playerToBeat: Player {
        players[playerToBeatIndex]
    }
    
    var currentTurnTotal: Int {
        currentThrow.reduce(0) { $0 + $1.totalValue }
    }
    
    var isTurnComplete: Bool {
        currentThrow.count == 3
    }
    
    var pointsNeededText: String {
        let needed = scoreToBeat - currentTurnTotal + 1
        if needed > 0 {
            return "\(needed) needed to stay in the game"
        } else {
            return "You're beating the score!"
        }
    }
    
    var activePlayers: [Player] {
        players.filter { playerLives[$0.id] ?? 0 > 0 }
    }
    
    var eliminatedPlayers: Set<UUID> {
        Set(players.filter { playerLives[$0.id] ?? 0 == 0 }.map { $0.id })
    }
    
    // MARK: - Initialization
    
    init(players: [Player], startingLives: Int) {
        self.players = players
        self.startingLives = startingLives
        
        // Initialize lives for all players
        for player in players {
            playerLives[player.id] = startingLives
            currentTurnScores[player.id] = 0
        }
        
        // First player is automatically player to beat
        playerToBeatIndex = 0
        scoreToBeat = 0
    }
    
    // MARK: - Game Actions
    
    func recordThrow(_ scoredThrow: ScoredThrow) {
        guard currentThrow.count < 3 else { return }
        
        currentThrow.append(scoredThrow)
        
        // Play appropriate sound
        if scoredThrow.totalValue == 0 {
            soundManager.playMissSound()
        } else {
            soundManager.playScoreSound()
        }
        
        // Update current turn score
        currentTurnScores[currentPlayer.id] = currentTurnTotal
    }
    
    func selectDart(at index: Int) {
        guard index < currentThrow.count else {
            selectedDartIndex = nil
            return
        }
        selectedDartIndex = index
    }
    
    func undoLastDart() {
        guard !currentThrow.isEmpty else { return }
        
        if let selectedIndex = selectedDartIndex, selectedIndex < currentThrow.count {
            currentThrow.remove(at: selectedIndex)
            selectedDartIndex = nil
        } else {
            currentThrow.removeLast()
        }
        
        // Update current turn score
        currentTurnScores[currentPlayer.id] = currentTurnTotal
    }
    
    func clearThrow() {
        currentThrow.removeAll()
        selectedDartIndex = nil
        currentTurnScores[currentPlayer.id] = 0
    }
    
    func completeTurn() {
        let turnScore = currentTurnTotal
        
        // First player's first turn - they become player to beat
        if currentPlayerIndex == 0 && scoreToBeat == 0 {
            scoreToBeat = turnScore
            playerToBeatIndex = 0
            soundManager.playScoreSound()
        } else {
            // Check if current player beat the score
            if turnScore > scoreToBeat {
                // New player to beat!
                scoreToBeat = turnScore
                playerToBeatIndex = currentPlayerIndex
                soundManager.playScoreSound()
            } else {
                // Lost a life
                if let currentLives = playerLives[currentPlayer.id] {
                    playerLives[currentPlayer.id] = max(0, currentLives - 1)
                    soundManager.playMissSound()
                    
                    // Check if player is eliminated
                    if playerLives[currentPlayer.id] == 0 {
                        print("💀 \(currentPlayer.displayName) is eliminated!")
                    }
                }
            }
        }
        
        // Clear current throw
        clearThrow()
        
        // Check for game over
        if activePlayers.count == 1 {
            endGame()
            return
        }
        
        // Move to next active player
        moveToNextPlayer()
    }
    
    private func moveToNextPlayer() {
        var nextIndex = (currentPlayerIndex + 1) % players.count
        
        // Skip eliminated players
        while playerLives[players[nextIndex].id] == 0 {
            nextIndex = (nextIndex + 1) % players.count
        }
        
        currentPlayerIndex = nextIndex
        currentTurnScores[currentPlayer.id] = 0
    }
    
    func endGame() {
        if let lastPlayer = activePlayers.first {
            winner = lastPlayer
            isGameOver = true
            soundManager.playGameWin()
            print("🎉 \(lastPlayer.displayName) wins Sudden Death!")
        }
    }
    
    func restartGame() {
        // Reset all state
        currentPlayerIndex = 0
        playerToBeatIndex = 0
        scoreToBeat = 0
        currentThrow.removeAll()
        selectedDartIndex = nil
        winner = nil
        isGameOver = false
        
        // Reset lives
        for player in players {
            playerLives[player.id] = startingLives
            currentTurnScores[player.id] = 0
        }
    }
}
