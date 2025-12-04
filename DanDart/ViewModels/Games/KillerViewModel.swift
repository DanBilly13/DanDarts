//
//  KillerViewModel.swift
//  DanDart
//
//  ViewModel for Killer game mode
//  Players are assigned random numbers (1-20), must hit their double to become a Killer,
//  then can eliminate opponents by hitting their numbers
//

import Foundation
import SwiftUI

@MainActor
class KillerViewModel: ObservableObject {
    enum TurnPhase {
        case playing
        case betweenTurnsPause
    }
    
    // MARK: - Published Properties
    
    @Published var players: [Player]
    @Published var currentPlayerIndex: Int = 0
    @Published var currentThrow: [ScoredThrow] = []
    @Published var selectedDartIndex: Int? = nil
    @Published var winner: Player? = nil
    @Published var isGameOver: Bool = false
    @Published var phase: TurnPhase = .playing
    
    // Player assigned numbers (1-20, no duplicates)
    @Published var playerNumbers: [UUID: Int] = [:]
    
    // Killer status tracking
    @Published var isKiller: [UUID: Bool] = [:]
    
    // Lives tracking: [Player.id: remaining lives]
    @Published var playerLives: [UUID: Int] = [:]
    @Published var displayPlayerLives: [UUID: Int] = [:] // For UI animations
    
    // Animation state
    @Published var animatingLifeLoss: UUID? = nil
    @Published var animatingLifeGain: UUID? = nil
    @Published var animatingKillerActivation: UUID? = nil
    @Published var eliminatedPlayers: Set<UUID> = []
    
    // MARK: - Computed Properties
    
    var currentPlayer: Player {
        players[currentPlayerIndex]
    }
    
    var activePlayers: [Player] {
        players.filter { !eliminatedPlayers.contains($0.id) }
    }
    
    var canSave: Bool {
        currentThrow.count == 3 && phase == .playing
    }
    
    var anyPlayerIsKiller: Bool {
        isKiller.values.contains(true)
    }
    
    // MARK: - Initialization
    
    let startingLives: Int
    private var turnHistory: [MatchTurn] = []
    let matchId: UUID
    
    init(players: [Player], startingLives: Int) {
        self.players = players
        self.startingLives = startingLives
        self.matchId = UUID()
        
        // Assign random numbers (1-20, no duplicates)
        assignRandomNumbers()
        
        // Initialize lives for all players
        for player in players {
            playerLives[player.id] = startingLives
            displayPlayerLives[player.id] = startingLives
            isKiller[player.id] = false
        }
    }
    
    // MARK: - Number Assignment
    
    private func assignRandomNumbers() {
        var availableNumbers = Array(1...20)
        availableNumbers.shuffle()
        
        for (index, player) in players.enumerated() {
            playerNumbers[player.id] = availableNumbers[index]
        }
    }
    
    // MARK: - Game Actions
    
    func recordThrow(value: Int, multiplier: Int) {
        guard phase == .playing else { return }
        
        let scoreType: ScoreType = {
            switch multiplier {
            case 2: return .double
            case 3: return .triple
            default: return .single
            }
        }()
        let dart = ScoredThrow(baseValue: value, scoreType: scoreType)
        currentThrow.append(dart)
        selectedDartIndex = currentThrow.count - 1
        
        // Process throw immediately for real-time UI updates
        processThrow(dart)
    }
    
    private func processThrow(_ dart: ScoredThrow) {
        let playerID = currentPlayer.id
        let playerNumber = playerNumbers[playerID] ?? 0
        let thrownNumber = dart.baseValue
        let multiplier = dart.scoreType.multiplier
        
        // Check if player hit their own double to become a Killer
        if thrownNumber == playerNumber && multiplier == 2 && !(isKiller[playerID] ?? false) {
            activateKiller(playerID: playerID)
            return
        }
        
        // If player is a Killer
        if isKiller[playerID] ?? false {
            // Check if hit own number (any multiplier) - lose a life
            if thrownNumber == playerNumber {
                loseLife(playerID: playerID)
                return
            }
            
            // Check if hit opponent's number
            for opponent in players where opponent.id != playerID {
                if let opponentNumber = playerNumbers[opponent.id], thrownNumber == opponentNumber {
                    // Remove lives based on multiplier
                    let livesToRemove = multiplier
                    for _ in 0..<livesToRemove {
                        loseLife(playerID: opponent.id)
                    }
                    return
                }
            }
        }
    }
    
    private func activateKiller(playerID: UUID) {
        isKiller[playerID] = true
        animatingKillerActivation = playerID
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        
        // Reset animation after delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                self.animatingKillerActivation = nil
            }
        }
    }
    
    private func loseLife(playerID: UUID) {
        guard let currentLives = displayPlayerLives[playerID], currentLives > 0 else { return }
        
        // Update display lives
        displayPlayerLives[playerID] = currentLives - 1
        animatingLifeLoss = playerID
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Reset animation after delay
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                self.animatingLifeLoss = nil
            }
        }
        
        // If player is eliminated, add to eliminatedPlayers after fade animation
        if currentLives - 1 == 0 {
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // Match fade duration
                await MainActor.run {
                    self.eliminatedPlayers.insert(playerID)
                }
            }
        }
    }
    
    func clearThrow() {
        currentThrow.removeAll()
        selectedDartIndex = nil
    }
    
    func undoLastDart() {
        guard !currentThrow.isEmpty, phase == .playing else { return }
        currentThrow.removeLast()
        selectedDartIndex = currentThrow.isEmpty ? nil : currentThrow.count - 1
        
        // Note: We don't undo the game state changes (lives, killer status)
        // This is intentional - once a dart is thrown, its effects are permanent
        // User should use "Restart" if they made a mistake
    }
    
    func completeTurn() {
        guard phase == .playing else { return }
        
        // Sync actual lives with display lives
        playerLives = displayPlayerLives
        
        // Record turn in history
        let darts = currentThrow.map { dart in
            MatchDart(
                baseValue: dart.baseValue,
                multiplier: dart.scoreType.multiplier
            )
        }
        let turn = MatchTurn(
            turnNumber: turnHistory.count + 1,
            darts: darts,
            scoreBefore: 0, // Killer doesn't track scores
            scoreAfter: 0,
            isBust: false
        )
        turnHistory.append(turn)
        
        // Check for eliminations
        checkForEliminations()
        
        // Check for winner
        if activePlayers.count == 1 {
            winner = activePlayers.first
            isGameOver = true
            return
        }
        
        // Move to next player
        clearThrow()
        moveToNextPlayer()
    }
    
    private func checkForEliminations() {
        for player in players {
            if let lives = playerLives[player.id], lives == 0 {
                // Player eliminated - fade out animation handled by view
                print("[Killer] Player \(player.displayName) eliminated")
            }
        }
    }
    
    private func moveToNextPlayer() {
        // Find next active player
        var nextIndex = (currentPlayerIndex + 1) % players.count
        var attempts = 0
        
        while (playerLives[players[nextIndex].id] ?? 0) == 0 && attempts < players.count {
            nextIndex = (nextIndex + 1) % players.count
            attempts += 1
        }
        
        currentPlayerIndex = nextIndex
    }
    
    // MARK: - Match Storage
    
    func getMatchData() -> (turns: [MatchTurn], matchId: UUID) {
        return (turnHistory, matchId)
    }
}
