//
//  KnockoutViewModel.swift
//  DanDart
//
//  Created by DanDarts Team
//

import Foundation
import SwiftUI

@MainActor
class KnockoutViewModel: ObservableObject {
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
    
    // Animation state
    @Published var showScoreAnimation: Bool = false // Triggers score to beat pop animation
    @Published var showSkullWiggle: Bool = false // Triggers skull wiggle when player fails
    @Published var animatingLifeLoss: UUID? = nil // Player ID whose life is animating
    @Published var animatingPlayerTransition: Bool = false // Triggers player card fade transition
    
    // MARK: - Properties
    
    let startingLives: Int
    private let soundManager = SoundManager.shared
    private let matchId = UUID()
    private let matchStartTime = Date()
    
    // Services (optional for Supabase sync)
    var authService: AuthService?
    
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
        // Randomize player order for fair play
        self.players = players.shuffled()
        self.startingLives = startingLives
        
        // Initialize lives for all players
        for player in self.players {
            playerLives[player.id] = startingLives
            currentTurnScores[player.id] = 0
        }
        
        // First player is automatically player to beat
        playerToBeatIndex = 0
        scoreToBeat = 0
    }
    
    // MARK: - Game Actions
    
    func recordThrow(_ scoredThrow: ScoredThrow) {
        // If a dart is selected, replace it instead of appending
        if let selectedIndex = selectedDartIndex, selectedIndex < currentThrow.count {
            currentThrow[selectedIndex] = scoredThrow
            selectedDartIndex = nil  // Clear selection after replacement
        } else {
            // Normal append behavior
            guard currentThrow.count < 3 else { return }
            currentThrow.append(scoredThrow)
        }
        
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
            triggerScoreAnimation()
        } else {
            // Check if current player beat the score
            if turnScore > scoreToBeat {
                // New player to beat!
                scoreToBeat = turnScore
                playerToBeatIndex = currentPlayerIndex
                soundManager.playScoreSound()
                triggerScoreAnimation()
            } else {
                // Lost a life
                if let currentLives = playerLives[currentPlayer.id] {
                    soundManager.playMissSound()
                    triggerSkullWiggle()
                    
                    // Trigger life loss animation
                    triggerLifeLossAnimation(for: currentPlayer.id)
                    
                    // Wait for life loss animation, then update lives
                    Task {
                        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s for life animation + small buffer
                        await MainActor.run {
                            playerLives[currentPlayer.id] = max(0, currentLives - 1)
                            
                            // Check if player is eliminated
                            if playerLives[currentPlayer.id] == 0 {
                                print("💀 \(currentPlayer.displayName) is eliminated!")
                            }
                            
                            // After life is lost, proceed with turn completion
                            finishTurnTransition()
                        }
                    }
                    return // Exit early, finishTurnTransition will handle the rest
                }
            }
        }
        
        // If no life was lost, proceed immediately
        finishTurnTransition()
    }
    
    private func finishTurnTransition() {
        // Clear current throw
        clearThrow()
        
        // Check for game over
        if activePlayers.count == 1 {
            endGame()
            return
        }
        
        // Trigger player transition animation
        triggerPlayerTransition()
        
        // Switch player immediately so avatar lineup animates during fade-in
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s - small delay for fade-out to start
            await MainActor.run {
                moveToNextPlayer() // Avatar lineup changes here, animates during fade-in
            }
        }
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
            
            // Save match result
            saveMatchResult()
        }
    }
    
    // MARK: - Match Storage
    
    /// Save match result to local storage and Supabase
    private func saveMatchResult() {
        guard let winner = winner else { return }
        
        // Calculate match duration
        let duration = Date().timeIntervalSince(matchStartTime)
        
        // Create match players with final lives remaining
        let matchPlayers = players.map { player in
            MatchPlayer(
                id: player.id,
                displayName: player.displayName,
                nickname: player.nickname,
                avatarURL: player.avatarURL,
                isGuest: player.isGuest,
                finalScore: playerLives[player.id] ?? 0,
                startingScore: startingLives,
                totalDartsThrown: 0, // Sudden Death doesn't track individual darts
                turns: [], // Sudden Death doesn't track turn-by-turn history
                legsWon: 0
            )
        }
        
        // Create match result
        let matchResult = MatchResult(
            id: matchId,
            gameType: "Sudden Death",
            gameName: "Sudden Death",
            players: matchPlayers,
            winnerId: winner.id,
            timestamp: matchStartTime,
            duration: duration,
            matchFormat: 1,
            totalLegsPlayed: 1,
            metadata: ["starting_lives": "\(startingLives)"]
        )
        
        // Save to local storage
        MatchStorageManager.shared.saveMatch(matchResult)
        
        // Update player stats
        MatchStorageManager.shared.updatePlayerStats(for: matchPlayers, winnerId: winner.id)
        
        // Capture current user ID before Task
        let currentUserId = authService?.currentUser?.id
        
        // Sync to Supabase (async, non-blocking)
        Task {
            do {
                let matchService = MatchService()
                
                // Get winner's user ID (nil for guests)
                let winnerId = winner.userId
                
                let updatedUser = try await matchService.saveMatch(
                    matchId: matchId,
                    gameId: "sudden_death",
                    players: players,
                    winnerId: winnerId,
                    startedAt: matchStartTime,
                    endedAt: Date(),
                    turnHistory: [], // Sudden Death doesn't track turn history
                    matchFormat: 1,
                    legsWon: [:], // Sudden Death doesn't use legs
                    currentUserId: currentUserId
                )
                
                print("✅ Sudden Death match saved to Supabase: \(matchId)")
                
                // Update AuthService with fresh user data
                if let updatedUser = updatedUser {
                    await MainActor.run {
                        self.authService?.currentUser = updatedUser
                    }
                }
            } catch {
                print("❌ Failed to save Sudden Death match to Supabase: \(error)")
            }
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
        showScoreAnimation = false
        showSkullWiggle = false
        animatingLifeLoss = nil
        animatingPlayerTransition = false
        
        // Reset lives
        for player in players {
            playerLives[player.id] = startingLives
            currentTurnScores[player.id] = 0
        }
    }
    
    // MARK: - Animation
    
    private func triggerScoreAnimation() {
        showScoreAnimation = true
        
        Task {
            // Wait for animation to complete
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
            showScoreAnimation = false
        }
    }
    
    private func triggerSkullWiggle() {
        showSkullWiggle = true
        
        Task {
            // Wait for wiggle animation to complete
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
            showSkullWiggle = false
        }
    }
    
    private func triggerLifeLossAnimation(for playerId: UUID) {
        animatingLifeLoss = playerId
        
        Task {
            // Wait for life loss animation to complete (pop + shrink)
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            animatingLifeLoss = nil
        }
    }
    
    private func triggerPlayerTransition() {
        animatingPlayerTransition = true
        
        Task {
            // Wait for fade transition to complete
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
            animatingPlayerTransition = false
        }
    }
}
