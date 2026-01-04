import Foundation
import SwiftUI

@MainActor
class SuddenDeathViewModel: ObservableObject {
    enum RoundPhase {
        case playing
        case endOfRoundPause
    }
    
    // MARK: - Published Properties
    
    @Published var players: [Player]
    @Published var currentPlayerIndex: Int = 0
    @Published var currentThrow: [ScoredThrow] = []
    @Published var selectedDartIndex: Int? = nil
    @Published var winner: Player? = nil
    @Published var isGameOver: Bool = false
    
    // Lives tracking: [Player.id: remaining lives]
    @Published var playerLives: [UUID: Int] = [:]
    /// Lives as shown in the UI; we delay updating these until the next round
    /// starts so the hearts change in sync with the round header.
    @Published var displayPlayerLives: [UUID: Int] = [:]
    
    // Per-round scores: [Player.id: round total]
    @Published var roundScores: [UUID: Int] = [:]
    
    // Turn history tracking: [Player.id: [turns]]
    private var turnHistory: [UUID: [MatchTurn]] = [:]
    
    // Round tracking
    @Published var roundNumber: Int = 1
    @Published var phase: RoundPhase = .playing
    // Animation state
    @Published var animatingLifeLoss: UUID? = nil
    @Published var animatingPlayerTransition: Bool = false
    /// The player whose round score just updated (for score pop animation in UI)
    @Published var scoreAnimationPlayerId: UUID? = nil
    @Published var showSkullWiggle: Bool = false
    
    // MARK: - Properties
    
    let startingLives: Int
    private let soundManager = SoundManager.shared
    let matchId = UUID()
    private let matchStartTime = Date()
    
    // Services (optional for Supabase sync)
    var authService: AuthService?
    
    // MARK: - Computed Properties
    
    var currentPlayer: Player {
        players[currentPlayerIndex]
    }
    
    var currentThrowTotal: Int {
        currentThrow.reduce(0) { $0 + $1.totalValue }
    }
    
    var isTurnComplete: Bool {
        currentThrow.count == 3
    }
    
    var activePlayers: [Player] {
        players.filter { (playerLives[$0.id] ?? 0) > 0 }
    }
    
    var eliminatedPlayers: Set<UUID> {
        Set(players.filter { (playerLives[$0.id] ?? 0) == 0 }.map { $0.id })
    }
    
    /// Players currently at the lowest *saved* score for this round (for skull indicator).
    /// Uses committed roundScores only so the skull moves when the score is saved,
    /// and still highlights players who just lost a life at the end of the round.
    var playersInDanger: Set<UUID> {
        let scoredEntries = roundScores

        guard !scoredEntries.isEmpty else { return [] }
        
        let minScore = scoredEntries.values.min() ?? 0
        let ids = scoredEntries.filter { $0.value == minScore }.map { $0.key }
        return Set(ids)
    }
    
    // MARK: - Initialization
    
    init(players: [Player], startingLives: Int) {
        // Randomize player order for fair play
        self.players = players.shuffled()
        self.startingLives = startingLives
        
        // Initialize lives
        for player in self.players {
            playerLives[player.id] = startingLives
            displayPlayerLives[player.id] = startingLives
        }
        
        // Start with first active player
        currentPlayerIndex = 0
    }
    
    // MARK: - Game Actions
    
    func recordThrow(_ scoredThrow: ScoredThrow) {
        // Replace selected dart or append
        if let selectedIndex = selectedDartIndex, selectedIndex < currentThrow.count {
            currentThrow[selectedIndex] = scoredThrow
            selectedDartIndex = nil
        } else {
            guard currentThrow.count < 3 else { return }
            currentThrow.append(scoredThrow)
        }
        
        // Sounds
        if scoredThrow.totalValue == 0 {
            soundManager.playMissSound()
        } else {
            soundManager.playScoreSound()
        }
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
    }
    
    func clearThrow() {
        currentThrow.removeAll()
        selectedDartIndex = nil
    }
    
    func completeTurn() {
        // Ignore save actions if we're in the end-of-round pause state
        guard phase == .playing else { return }
        
        // Only commit if we have at least one dart
        let total = currentThrowTotal
        roundScores[currentPlayer.id] = total
        
        // Record turn in history
        recordTurn(playerId: currentPlayer.id, score: total)
        
        // Trigger score pop animation for this player's round score
        let justScoredPlayerId = currentPlayer.id
        scoreAnimationPlayerId = justScoredPlayerId
        
        // Debug: log round state for skull + turn issues
        let debugScores = roundScores.map { entry in
            if let player = players.first(where: { $0.id == entry.key }) {
                return "\(player.displayName): \(entry.value)"
            } else {
                return "<unknown>: \(entry.value)"
            }
        }.joined(separator: ", ")
        let dangerNames = playersInDanger.compactMap { id in
            players.first(where: { $0.id == id })?.displayName
        }.joined(separator: ", ")
        print("[SuddenDeath] R\(roundNumber) after save — scores: [\(debugScores)] | playersInDanger: [\(dangerNames)] | currentPlayerIndex: \(currentPlayerIndex) (", currentPlayer.displayName, ")")
        
        Task { [weak self] in
            // Allow the UI animation to play, then clear the flag
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
            await MainActor.run {
                if self?.scoreAnimationPlayerId == justScoredPlayerId {
                    self?.scoreAnimationPlayerId = nil
                }
            }
        }
        
        // Move to next player or end round
        if let nextIndex = nextActivePlayerIndex(after: currentPlayerIndex) {
            currentPlayerIndex = nextIndex
            clearThrow()
        } else {
            // All active players have thrown this round
            endRound()
        }
    }
    
    private func nextActivePlayerIndex(after index: Int) -> Int? {
        guard !activePlayers.isEmpty else { return nil }
        
        var next = index + 1
        while next < players.count {
            let player = players[next]
            if (playerLives[player.id] ?? 0) > 0 {
                return next
            }
            next += 1
        }
        
        // No further active players
        return nil
    }
    
    private func endRound() {
        guard !roundScores.isEmpty else { return }
        
        // Enter end-of-round pause phase so the UI can show animations and
        // ignore further input until the next round starts or the game ends.
        phase = .endOfRoundPause
        
        // Determine lowest score among active players
        let activeIds = activePlayers.map { $0.id }
        let activeRoundScores = roundScores.filter { activeIds.contains($0.key) }
        guard !activeRoundScores.isEmpty else { return }
        
        let minScore = activeRoundScores.values.min() ?? 0
        let losers = activeRoundScores.filter { $0.value == minScore }.map { $0.key }
        
        // Special rule: If only 2 players remain and they tie, no one loses a life
        // Both players play again in the next round
        let isTwoPlayerTie = activePlayers.count == 2 && losers.count == 2
        
        if !isTwoPlayerTie {
            // Mark life loss in turn history
            markLifeLossInHistory(playerIds: losers)
            
            // Apply life loss for all losers (game state only; UI will update at
            // the start of the next round via displayPlayerLives)
            for id in losers {
                if let currentLives = playerLives[id], currentLives > 0 {
                    playerLives[id] = max(0, currentLives - 1)
                }
            }
        }
        
        // Trigger skull wiggle for players in danger during the pause at the
        // end of the round (or before game end in the final round).
        print("[SuddenDeath] 💀 Skull spinning – end-of-round pause active")
        showSkullWiggle = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            await MainActor.run {
                self?.showSkullWiggle = false
            }
        }
        
        // Check for winner
        let remaining = activePlayers
        if remaining.count <= 1 {
            if let champ = remaining.first {
                winner = champ
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await MainActor.run {
                        guard let self else { return }
                        self.isGameOver = true
                        self.soundManager.playGameWin()
                        self.saveMatchResult()
                    }
                }
            }
            return
        }
        
        // Delay starting the next round so the UI can briefly show who lost
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second pause
            await MainActor.run {
                guard let self else { return }
                self.roundNumber += 1
                self.roundScores.removeAll()
                self.clearThrow()

                // Sync UI lives with updated game lives at the start of the
                // new round
                self.displayPlayerLives = self.playerLives

                // Move current player index to first active player
                if let firstActiveIndex = self.players.firstIndex(where: { (self.playerLives[$0.id] ?? 0) > 0 }) {
                    self.currentPlayerIndex = firstActiveIndex
                }

                // Resume normal play after the end-of-round pause
                self.phase = .playing
            }
        }
    }
    
    func restartGame() {
        // Reset lives and state, keep player order
        for player in players {
            playerLives[player.id] = startingLives
            displayPlayerLives[player.id] = startingLives
        }
        roundScores.removeAll()
        turnHistory.removeAll()
        currentThrow.removeAll()
        selectedDartIndex = nil
        roundNumber = 1
        winner = nil
        isGameOver = false
        phase = .playing
        
        if let firstActiveIndex = players.firstIndex(where: { (playerLives[$0.id] ?? 0) > 0 }) {
            currentPlayerIndex = firstActiveIndex
        } else {
            currentPlayerIndex = 0
        }
    }
    
    // MARK: - Turn History
    
    private func recordTurn(playerId: UUID, score: Int) {
        // Get current accumulated score (sum of all previous turns)
        let previousTurns = turnHistory[playerId] ?? []
        let scoreBefore = previousTurns.last?.scoreAfter ?? 0
        let scoreAfter = scoreBefore + score
        
        // Check if this player lost a life this round (will be determined at end of round)
        // For now, set isBust to false; we'll update it when the round ends
        let matchDarts = currentThrow.map { scoredThrow in
            MatchDart(
                baseValue: scoredThrow.baseValue,
                multiplier: scoredThrow.scoreType.multiplier
            )
        }
        
        let turn = MatchTurn(
            turnNumber: roundNumber,
            darts: matchDarts,
            scoreBefore: scoreBefore,
            scoreAfter: scoreAfter,
            isBust: false // Will be updated at end of round
        )
        
        if turnHistory[playerId] == nil {
            turnHistory[playerId] = []
        }
        turnHistory[playerId]?.append(turn)
    }
    
    private func markLifeLossInHistory(playerIds: [UUID]) {
        // Mark the most recent turn for these players as a bust (life lost)
        for playerId in playerIds {
            guard var turns = turnHistory[playerId], !turns.isEmpty else { continue }
            let lastIndex = turns.count - 1
            turns[lastIndex] = MatchTurn(
                id: turns[lastIndex].id,
                turnNumber: turns[lastIndex].turnNumber,
                darts: turns[lastIndex].darts,
                scoreBefore: turns[lastIndex].scoreBefore,
                scoreAfter: turns[lastIndex].scoreAfter,
                isBust: true
            )
            turnHistory[playerId] = turns
        }
    }
    
    // MARK: - Match Storage
    
    private func saveMatchResult() {
        guard let winner = winner else { return }
        
        let duration = Date().timeIntervalSince(matchStartTime)
        
        let matchPlayers = players.map { player in
            let turns = turnHistory[player.id] ?? []
            let totalDarts = turns.reduce(0) { $0 + $1.darts.count }
            let finalScore = turns.last?.scoreAfter ?? 0
            
            return MatchPlayer(
                id: player.id,
                displayName: player.displayName,
                nickname: player.nickname,
                avatarURL: player.avatarURL,
                isGuest: player.isGuest,
                finalScore: finalScore,
                startingScore: 0,
                totalDartsThrown: totalDarts,
                turns: turns,
                legsWon: 0
            )
        }
        
        let matchResult = MatchResult(
            id: matchId,
            gameType: "sudden_death",
            gameName: "Sudden Death",
            players: matchPlayers,
            winnerId: winner.userId ?? winner.id,
            timestamp: matchStartTime,
            duration: duration,
            matchFormat: 1,
            totalLegsPlayed: 1,
            metadata: ["starting_lives": "\(startingLives)"]
        )
        
        MatchStorageManager.shared.saveMatch(matchResult)
        MatchStorageManager.shared.updatePlayerStats(for: matchPlayers, winnerId: winner.userId ?? winner.id)
        
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
        
        Task {
            do {
                let matchService = MatchService()
                let winnerId = winner.userId ?? winner.id
                let updatedUser = try await matchService.saveMatch(
                    matchId: matchId,
                    gameId: "sudden_death",
                    players: players,
                    winnerId: winnerId,
                    startedAt: matchStartTime,
                    endedAt: Date(),
                    turnHistory: flatTurnHistory,
                    matchFormat: 1,
                    legsWon: [:],
                    currentUserId: currentUserId
                )
                
                print("✅ Sudden Death match saved to Supabase: \(matchId)")
                
                // Delete from local storage after successful sync
                await MainActor.run {
                    MatchStorageManager.shared.deleteMatch(withId: matchId)
                    print("🗑️ Sudden Death match removed from local storage after sync: \(matchId)")
                }
                
                if let updatedUser = updatedUser {
                    await MainActor.run {
                        self.authService?.currentUser = updatedUser
                        self.authService?.objectWillChange.send()
                    }
                    print("✅ User profile updated with fresh stats: \(updatedUser.totalWins)W/\(updatedUser.totalLosses)L")
                }
            } catch {
                print("❌ Failed to save Sudden Death match to Supabase: \(error)")
            }
        }
    }
}
