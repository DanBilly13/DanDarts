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
    @Published var showPlayerScorePop: Bool = false // Triggers player card score pop animation
    @Published var showSkullWiggle: Bool = false // Triggers skull wiggle when player fails
    @Published var animatingLifeLoss: UUID? = nil // Player ID whose life is animating
    @Published var animatingPlayerTransition: Bool = false // Triggers player card fade transition
    
    // MARK: - Properties
    
    let startingLives: Int
    private let soundManager = SoundManager.shared
    let matchId = UUID()
    private let matchStartTime = Date()
    private let originalPlayerOrder: [Player] // Preserve original order for consistent colors
    
    // Turn history tracking: [Player.id: [MatchTurn]]
    private var turnHistory: [UUID: [MatchTurn]] = [:]
    
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
        // Store original player order for consistent color assignment
        self.originalPlayerOrder = players
        // Randomize player order for fair play
        self.players = players.shuffled()
        self.startingLives = startingLives
        
        // Initialize lives for all players
        for player in self.players {
            playerLives[player.id] = startingLives
            currentTurnScores[player.id] = 0
            turnHistory[player.id] = []
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
        
        // Record turn in history
        recordTurn(score: turnScore, lostLife: false)
        
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
                
                // Wait for score pop animation to complete before switching players
                Task {
                    try? await Task.sleep(nanoseconds: 250_000_000) // 0.25s for pop animation
                    await MainActor.run {
                        finishTurnTransition()
                    }
                }
                return // Exit early, finishTurnTransition will be called after animation
            } else {
                // Lost a life
                if let currentLives = playerLives[currentPlayer.id] {
                    soundManager.playMissSound()
                    triggerSkullWiggle()
                    
                    // Mark life loss in turn history
                    markLifeLossInHistory()
                    
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
        
        // If no life was lost and didn't beat score, proceed immediately
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
    
    // MARK: - Turn History Tracking
    
    /// Record a turn in the history
    private func recordTurn(score: Int, lostLife: Bool) {
        let darts = currentThrow.map { scoredThrow in
            MatchDart(baseValue: scoredThrow.baseValue, multiplier: scoredThrow.scoreType.multiplier)
        }
        
        let turn = MatchTurn(
            turnNumber: (turnHistory[currentPlayer.id]?.count ?? 0) + 1,
            darts: darts,
            scoreBefore: 0, // Not applicable for Knockout
            scoreAfter: score, // Store the turn score
            isBust: lostLife
        )
        
        turnHistory[currentPlayer.id, default: []].append(turn)
    }
    
    /// Mark the last recorded turn as a life loss
    private func markLifeLossInHistory() {
        guard var turns = turnHistory[currentPlayer.id], !turns.isEmpty else { return }
        
        // Create a new turn with isBust set to true (MatchTurn properties are immutable)
        let lastTurn = turns[turns.count - 1]
        let updatedTurn = MatchTurn(
            id: lastTurn.id,
            turnNumber: lastTurn.turnNumber,
            darts: lastTurn.darts,
            scoreBefore: lastTurn.scoreBefore,
            scoreAfter: lastTurn.scoreAfter,
            isBust: true
        )
        turns[turns.count - 1] = updatedTurn
        turnHistory[currentPlayer.id] = turns
    }
    
    // MARK: - Match Storage
    
    /// Save match result to local storage and Supabase
    private func saveMatchResult() {
        guard let winner = winner else { return }
        
        // Calculate match duration
        let duration = Date().timeIntervalSince(matchStartTime)
        
        // Create match players with final lives remaining and turn history
        // Use original player order to maintain consistent color assignment
        let matchPlayers = originalPlayerOrder.map { player in
            MatchPlayer(
                id: player.id,
                displayName: player.displayName,
                nickname: player.nickname,
                avatarURL: player.avatarURL,
                isGuest: player.isGuest,
                finalScore: playerLives[player.id] ?? 0,
                startingScore: startingLives,
                totalDartsThrown: 0, // Knockout doesn't track individual darts
                turns: turnHistory[player.id] ?? [],
                legsWon: 0
            )
        }
        
        // Create match result
        let matchResult = MatchResult(
            id: matchId,
            gameType: "Knockout",
            gameName: "Knockout",
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
        
        // Convert turn history dictionary to flat array for Supabase
        var flatTurnHistory: [TurnHistory] = []
        for player in players {
            if let playerTurns = turnHistory[player.id] {
                for (index, turn) in playerTurns.enumerated() {
                    // Convert MatchDart to ScoredThrow for TurnHistory
                    let scoredThrows = turn.darts.map { dart in
                        ScoredThrow(
                            baseValue: dart.baseValue,
                            scoreType: dart.multiplier == 1 ? .single : (dart.multiplier == 2 ? .double : .triple)
                        )
                    }
                    
                    flatTurnHistory.append(TurnHistory(
                        player: player,
                        playerId: player.id,
                        turnNumber: index,
                        darts: scoredThrows,
                        scoreBefore: turn.scoreBefore,
                        scoreAfter: turn.scoreAfter,
                        isBust: turn.isBust,
                        gameMetadata: nil
                    ))
                }
            }
        }
        
        // Sync to Supabase (async, non-blocking)
        Task {
            do {
                let matchService = MatchService()
                
                // Get winner's ID (userId for connected players, player.id for guests)
                let winnerId = winner.userId ?? winner.id
                
                let updatedUser = try await matchService.saveMatch(
                    matchId: matchId,
                    gameId: "knockout",
                    players: players,
                    winnerId: winnerId,
                    startedAt: matchStartTime,
                    endedAt: Date(),
                    turnHistory: flatTurnHistory,
                    matchFormat: 1,
                    legsWon: [:],
                    currentUserId: currentUserId
                )
                
                print("✅ Knockout match saved to Supabase: \(matchId)")
                
                // Delete from local storage after successful sync
                await MainActor.run {
                    MatchStorageManager.shared.deleteMatch(withId: matchId)
                    print("🗑️ Knockout match removed from local storage after sync: \(matchId)")
                }
                
                // Update AuthService with fresh user data
                if let updatedUser = updatedUser {
                    await MainActor.run {
                        self.authService?.currentUser = updatedUser
                        self.authService?.objectWillChange.send()
                    }
                    print("✅ User profile updated with fresh stats: \(updatedUser.totalWins)W/\(updatedUser.totalLosses)L")
                }
            } catch {
                print("❌ Failed to save Knockout match to Supabase: \(error)")
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
        showPlayerScorePop = false
        showSkullWiggle = false
        animatingLifeLoss = nil
        animatingPlayerTransition = false
        
        // Reset lives and turn history
        for player in players {
            playerLives[player.id] = startingLives
            currentTurnScores[player.id] = 0
            turnHistory[player.id] = []
        }
    }
    
    // MARK: - Animation
    
    private func triggerScoreAnimation() {
        showScoreAnimation = true
        showPlayerScorePop = true
        
        Task {
            // Wait for animation to complete
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
            showScoreAnimation = false
            showPlayerScorePop = false
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
