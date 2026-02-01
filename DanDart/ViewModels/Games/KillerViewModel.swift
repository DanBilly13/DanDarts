//
//  KillerViewModel.swift
//  Dart Freak
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
    private var currentThrowMetadata: [KillerDartMetadata] = [] // Parallel array for metadata
    @Published var selectedDartIndex: Int? = 0  // Start with dart 1 highlighted
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
    @Published var animatingGunSpin: UUID? = nil
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
    
    // Services (optional for Supabase sync)
    var authService: AuthService?
    
    // Sound manager
    private let soundManager = SoundManager.shared
    
    var anyPlayerIsKiller: Bool {
        isKiller.values.contains(true)
    }
    
    // MARK: - Initialization
    
    let startingLives: Int
    private var playerTurnHistory: [UUID: [MatchTurn]] = [:] // Per-player turn history
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
    
    // MARK: - Helper: Get Match Player ID
    
    /// Returns the ID that will be used in MatchPlayer (userId for connected, player.id for guests)
    private func matchPlayerId(for player: Player) -> UUID {
        return player.userId ?? player.id
    }
    
    // MARK: - Game Actions
    
    func recordThrow(value: Int, multiplier: Int) {
        guard phase == .playing else { return }
        
        // Prevent recording more than 3 darts
        // Note: In Killer mode, we don't allow editing previous darts because
        // game state changes (lives, killer status) are permanent and can't be undone.
        // Players should use the menu Restart option if they made a mistake.
        guard currentThrow.count < 3 else { return }
        
        print("🎯 recordThrow called: value=\(value), multiplier=\(multiplier)")
        
        let scoreType: ScoreType = {
            switch multiplier {
            case 2: return .double
            case 3: return .triple
            default: return .single
            }
        }()
        let dart = ScoredThrow(baseValue: value, scoreType: scoreType)
        print("   Created ScoredThrow: base=\(dart.baseValue), type=\(scoreType), total=\(dart.totalValue)")
        currentThrow.append(dart)
        
        // Process throw and get metadata
        let metadata = processThrow(dart)
        currentThrowMetadata.append(metadata)
        
        // Move highlight to next dart position (or stay on last if all 3 thrown)
        selectedDartIndex = min(currentThrow.count, 2)
        
        // Check for immediate win AFTER metadata is appended
        checkForImmediateWin()
    }
    
    private func processThrow(_ dart: ScoredThrow) -> KillerDartMetadata {
        let playerID = currentPlayer.id
        let playerNumber = playerNumbers[playerID] ?? 0
        let thrownNumber = dart.baseValue
        let multiplier = dart.scoreType.multiplier
        
        // Check if player hit their own double to become a Killer
        if thrownNumber == playerNumber && multiplier == 2 && !(isKiller[playerID] ?? false) {
            activateKiller(playerID: playerID)
            return KillerDartMetadata(outcome: .becameKiller, affectedPlayerIds: [])
        }
        
        // If player is a Killer
        if isKiller[playerID] ?? false {
            // Check if hit own number (any multiplier) - lose lives based on multiplier
            if thrownNumber == playerNumber {
                let livesToRemove = multiplier
                print("   💀 Hit own number \(playerNumber) with multiplier \(multiplier) - removing \(livesToRemove) lives from \(currentPlayer.displayName)")
                var affectedIds: [UUID] = []
                for i in 0..<livesToRemove {
                    print("      Life loss \(i+1)/\(livesToRemove): \(currentPlayer.displayName) before=\(displayPlayerLives[playerID] ?? -1)")
                    loseLife(playerID: playerID)
                    print("      Life loss \(i+1)/\(livesToRemove): \(currentPlayer.displayName) after=\(displayPlayerLives[playerID] ?? -1)")
                    // Use matchPlayerId for consistency with MatchPlayer
                    affectedIds.append(matchPlayerId(for: currentPlayer))
                }
                return KillerDartMetadata(outcome: .hitOwnNumber, affectedPlayerIds: affectedIds)
            }
            
            // Check if hit opponent's number
            for opponent in players where opponent.id != playerID {
                if let opponentNumber = playerNumbers[opponent.id], thrownNumber == opponentNumber {
                    // Play hit sound first
                    soundManager.playKillerHit()
                    
                    // Check if this hit will eliminate the opponent
                    let opponentLives = displayPlayerLives[opponent.id] ?? 0
                    let willEliminate = opponentLives <= multiplier
                    
                    // Play kill sound based on multiplier (with slight delay)
                    // Store multiplier for potential elimination sound timing
                    let hitMultiplier = multiplier
                    Task {
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s delay
                        await MainActor.run {
                            switch hitMultiplier {
                            case 1:
                                self.soundManager.playKillSingle()
                            case 2:
                                self.soundManager.playKillDouble()
                            case 3:
                                self.soundManager.playKillTriple()
                            default:
                                break
                            }
                        }
                    }
                    
                    // If this will eliminate the opponent, play Dead sound with overlap timing
                    if willEliminate {
                        // Calculate delay based on kill sound duration (0.3s initial delay + sound duration - 0.25s overlap)
                        // KillSingle: ~1.0s, KillDouble: ~1.5s, KillTriple: ~2.0s
                        let killSoundDuration: Double = {
                            switch hitMultiplier {
                            case 1: return 1.0  // KillSingle
                            case 2: return 1.5  // KillDouble
                            case 3: return 2.0  // KillTriple
                            default: return 1.0
                            }
                        }()
                        
                        let deadSoundDelay = 0.3 + killSoundDuration - 0.25 // Start 0.25s before kill sound ends
                        
                        Task {
                            try? await Task.sleep(nanoseconds: UInt64(deadSoundDelay * 1_000_000_000))
                            await MainActor.run {
                                self.soundManager.playKillerDead()
                            }
                        }
                    }
                    
                    // Trigger gun spin animation for the attacker (current player)
                    triggerGunSpin(playerID: playerID)
                    
                    // Remove lives based on multiplier
                    let livesToRemove = multiplier
                    print("   💥 Hit opponent's number \(opponentNumber) with multiplier \(multiplier) - removing \(livesToRemove) lives from \(opponent.displayName)")
                    var affectedIds: [UUID] = []
                    for i in 0..<livesToRemove {
                        print("      Life loss \(i+1)/\(livesToRemove): \(opponent.displayName) before=\(displayPlayerLives[opponent.id] ?? -1)")
                        loseLife(playerID: opponent.id)
                        print("      Life loss \(i+1)/\(livesToRemove): \(opponent.displayName) after=\(displayPlayerLives[opponent.id] ?? -1)")
                        // Use matchPlayerId for consistency with MatchPlayer
                        affectedIds.append(matchPlayerId(for: opponent))
                    }
                    
                    return KillerDartMetadata(outcome: .hitOpponent, affectedPlayerIds: affectedIds)
                }
            }
        }
        
        // Miss - didn't hit any relevant number
        soundManager.playKillerMiss()
        return KillerDartMetadata(outcome: .miss, affectedPlayerIds: [])
    }
    
    private func checkForImmediateWin() {
        // Count players with lives > 0
        let playersWithLives = players.filter { (displayPlayerLives[$0.id] ?? 0) > 0 }
        
        // If only one player left, they win immediately
        if playersWithLives.count == 1 {
            winner = playersWithLives.first
            isGameOver = true
            
            // Sync lives immediately
            playerLives = displayPlayerLives
            
            // Save the current turn before saving the match
            saveCurrentTurnToHistory()
            
            // Save match
            saveMatch()
        }
    }
    
    private func saveCurrentTurnToHistory() {
        // Only save if there are darts in the current throw
        guard !currentThrow.isEmpty else { return }
        
        // Create darts with metadata
        let darts = currentThrow.enumerated().map { index, dart in
            let metadata = index < currentThrowMetadata.count ? currentThrowMetadata[index] : nil
            return MatchDart(
                baseValue: dart.baseValue,
                multiplier: dart.scoreType.multiplier,
                killerMetadata: metadata
            )
        }
        
        // Get current player's turn number
        let playerTurns = playerTurnHistory[currentPlayer.id] ?? []
        let turn = MatchTurn(
            turnNumber: playerTurns.count + 1,
            darts: darts,
            scoreBefore: 0,
            scoreAfter: 0,
            isBust: false
        )
        
        // Append to this player's turn history
        if playerTurnHistory[currentPlayer.id] == nil {
            playerTurnHistory[currentPlayer.id] = []
        }
        playerTurnHistory[currentPlayer.id]?.append(turn)
    }
    
    private func saveMatch() {
        guard let winner = winner else { return }
        
        // Create match players with their individual turns
        let matchPlayers = players.map { player in
            let turns = playerTurnHistory[player.id] ?? []
            let totalDarts = turns.reduce(0) { $0 + $1.darts.count }
            
            return MatchPlayer.from(
                player: player,
                finalScore: 0,
                startingScore: 0,
                totalDartsThrown: totalDarts,
                turns: turns
            )
        }
        
        // Create metadata with player numbers and starting lives
        var metadata: [String: String] = [
            "starting_lives": "\(startingLives)"
        ]
        // Store player numbers as "player_{uuid}": "number"
        // Use matchPlayerId to ensure consistency with MatchPlayer IDs
        for player in players {
            if let number = playerNumbers[player.id] {
                let playerId = matchPlayerId(for: player)
                metadata["player_\(playerId.uuidString)"] = "\(number)"
            }
        }
        
        let matchResult = MatchResult(
            id: matchId,
            gameType: "Killer",
            gameName: "Killer",
            players: matchPlayers,
            winnerId: matchPlayerId(for: winner),
            timestamp: Date(),
            duration: 0,
            matchFormat: 1,
            totalLegsPlayed: 1,
            metadata: metadata
        )
        
        MatchStorageManager.shared.saveMatch(matchResult)
        MatchStorageManager.shared.updatePlayerStats(for: matchPlayers, winnerId: matchPlayerId(for: winner))
        
        // Capture current user ID before Task
        let currentUserId = authService?.currentUser?.id
        
        // Convert turn history dictionary to flat array for Supabase
        var flatTurnHistory: [TurnHistory] = []
        for player in players {
            if let playerTurns = playerTurnHistory[player.id] {
                for (index, turn) in playerTurns.enumerated() {
                    // Convert MatchDart to ScoredThrow for TurnHistory
                    let scoredThrows = turn.darts.map { dart in
                        ScoredThrow(
                            baseValue: dart.baseValue,
                            scoreType: dart.multiplier == 1 ? .single : (dart.multiplier == 2 ? .double : .triple)
                        )
                    }
                    
                    // Serialize killer metadata into gameMetadata dictionary
                    // Store as JSON string because [String: String] can't hold nested arrays
                    var gameMetadata: [String: String]? = nil
                    if !turn.darts.isEmpty {
                        // Create array of dart metadata with indices to maintain alignment
                        let dartsArray = turn.darts.enumerated().compactMap { dartIndex, dart -> [String: Any]? in
                            guard let metadata = dart.killerMetadata else { return nil }
                            return [
                                "dart_index": dartIndex,
                                "outcome": metadata.outcome.rawValue,
                                "affected_player_ids": metadata.affectedPlayerIds.map { $0.uuidString }
                            ]
                        }
                        
                        // Convert to JSON string for storage
                        if !dartsArray.isEmpty,
                           let jsonData = try? JSONSerialization.data(withJSONObject: dartsArray),
                           let jsonString = String(data: jsonData, encoding: .utf8) {
                            gameMetadata = ["killer_darts": jsonString]
                        }
                    }
                    
                    flatTurnHistory.append(TurnHistory(
                        player: player,
                        playerId: player.id,
                        turnNumber: index,
                        darts: scoredThrows,
                        scoreBefore: turn.scoreBefore,
                        scoreAfter: turn.scoreAfter,
                        isBust: turn.isBust,
                        gameMetadata: gameMetadata
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
                    gameId: "killer",
                    players: players,
                    winnerId: winnerId,
                    startedAt: Date().addingTimeInterval(-600), // Approximate start time
                    endedAt: Date(),
                    turnHistory: flatTurnHistory,
                    matchFormat: 1,
                    legsWon: [:],
                    gameMetadata: metadata,
                    currentUserId: currentUserId
                )
                
                print("✅ Killer match saved to Supabase: \(matchId)")
                
                // Delete from local storage after successful sync
                await MainActor.run {
                    MatchStorageManager.shared.deleteMatch(withId: matchId)
                    print("🗑️ Killer match removed from local storage after sync: \(matchId)")
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
                print("❌ Failed to save Killer match to Supabase: \(error)")
            }
        }
    }
    
    private func activateKiller(playerID: UUID) {
        isKiller[playerID] = true
        animatingKillerActivation = playerID
        
        // Play killer unlocked sound
        soundManager.playKillerUnlocked()
        
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
    
    private func triggerGunSpin(playerID: UUID) {
        animatingGunSpin = playerID
        
        // Reset animation after 0.6 seconds (matching animation duration)
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            await MainActor.run {
                self.animatingGunSpin = nil
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
        currentThrowMetadata.removeAll()
        selectedDartIndex = 0  // Reset to dart 1 for next turn
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
        
        // Record turn in history with metadata
        let darts = currentThrow.enumerated().map { index, dart in
            let metadata = index < currentThrowMetadata.count ? currentThrowMetadata[index] : nil
            return MatchDart(
                baseValue: dart.baseValue,
                multiplier: dart.scoreType.multiplier,
                killerMetadata: metadata
            )
        }
        // Get current player's turn number
        let playerTurns = playerTurnHistory[currentPlayer.id] ?? []
        let turn = MatchTurn(
            turnNumber: playerTurns.count + 1,
            darts: darts,
            scoreBefore: 0, // Killer doesn't track scores
            scoreAfter: 0,
            isBust: false
        )
        
        // Append to this player's turn history
        if playerTurnHistory[currentPlayer.id] == nil {
            playerTurnHistory[currentPlayer.id] = []
        }
        playerTurnHistory[currentPlayer.id]?.append(turn)
        
        // Check for eliminations
        checkForEliminations()
        
        // Count players with lives > 0 (using displayPlayerLives for immediate check)
        let playersWithLives = players.filter { (displayPlayerLives[$0.id] ?? 0) > 0 }
        
        // Check for winner
        if playersWithLives.count == 1 {
            winner = playersWithLives.first
            isGameOver = true
            return
        }
        
        // Check if game is over (no players left - shouldn't happen but safety check)
        if playersWithLives.count == 0 {
            print("[Killer] Warning: No players left alive")
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
        print("🔄 moveToNextPlayer called. Current: \(currentPlayer.displayName) (index \(currentPlayerIndex))")
        print("   Player lives: \(players.map { "\($0.displayName)=\(displayPlayerLives[$0.id] ?? -1)" }.joined(separator: ", "))")
        
        // Find next active player (use displayPlayerLives for immediate response)
        var nextIndex = (currentPlayerIndex + 1) % players.count
        var attempts = 0
        
        while (displayPlayerLives[players[nextIndex].id] ?? 0) == 0 && attempts < players.count {
            print("   Skipping \(players[nextIndex].displayName) (lives: \(displayPlayerLives[players[nextIndex].id] ?? -1))")
            nextIndex = (nextIndex + 1) % players.count
            attempts += 1
        }
        
        // Safety check: if all players eliminated, don't update (game should end)
        if attempts >= players.count {
            print("[Killer] Warning: All players eliminated, cannot move to next player")
            return
        }
        
        currentPlayerIndex = nextIndex
        print("   ➡️ Next player: \(currentPlayer.displayName) (index \(currentPlayerIndex), lives: \(displayPlayerLives[currentPlayer.id] ?? -1))")
    }
    
    // MARK: - Match Storage
    
    func getMatchData() -> (playerTurns: [UUID: [MatchTurn]], matchId: UUID) {
        return (playerTurnHistory, matchId)
    }
}
