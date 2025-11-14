import Foundation
import SwiftUI

@MainActor
class SuddenDeathViewModel: ObservableObject {
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
    
    // Round tracking
    @Published var roundNumber: Int = 1
    // Animation state
    @Published var animatingLifeLoss: UUID? = nil
    @Published var animatingPlayerTransition: Bool = false
    /// The player whose round score just updated (for score pop animation in UI)
    @Published var scoreAnimationPlayerId: UUID? = nil
    
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
        // Only commit if we have at least one dart
        let total = currentThrowTotal
        roundScores[currentPlayer.id] = total
        
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
        
        // Determine lowest score among active players
        let activeIds = activePlayers.map { $0.id }
        let activeRoundScores = roundScores.filter { activeIds.contains($0.key) }
        guard !activeRoundScores.isEmpty else { return }
        
        let minScore = activeRoundScores.values.min() ?? 0
        let losers = activeRoundScores.filter { $0.value == minScore }.map { $0.key }
        
        // Apply life loss for all losers (game state only; UI will update at
        // the start of the next round via displayPlayerLives)
        for id in losers {
            if let currentLives = playerLives[id], currentLives > 0 {
                playerLives[id] = max(0, currentLives - 1)
            }
        }
        
        // Check for winner
        let remaining = activePlayers
        if remaining.count <= 1 {
            if let champ = remaining.first {
                winner = champ
                isGameOver = true
                soundManager.playGameWin()
                saveMatchResult()
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
        currentThrow.removeAll()
        selectedDartIndex = nil
        roundNumber = 1
        winner = nil
        isGameOver = false
        
        if let firstActiveIndex = players.firstIndex(where: { (playerLives[$0.id] ?? 0) > 0 }) {
            currentPlayerIndex = firstActiveIndex
        } else {
            currentPlayerIndex = 0
        }
    }
    
    // MARK: - Match Storage
    
    private func saveMatchResult() {
        guard let winner = winner else { return }
        
        let duration = Date().timeIntervalSince(matchStartTime)
        
        let matchPlayers = players.map { player in
            MatchPlayer(
                id: player.id,
                displayName: player.displayName,
                nickname: player.nickname,
                avatarURL: player.avatarURL,
                isGuest: player.isGuest,
                finalScore: playerLives[player.id] ?? 0,
                startingScore: startingLives,
                totalDartsThrown: 0,
                turns: [],
                legsWon: 0
            )
        }
        
        let matchResult = MatchResult(
            id: matchId,
            gameType: "sudden_death",
            gameName: "Sudden Death",
            players: matchPlayers,
            winnerId: winner.id,
            timestamp: matchStartTime,
            duration: duration,
            matchFormat: 1,
            totalLegsPlayed: 1,
            metadata: ["starting_lives": "\(startingLives)"]
        )
        
        MatchStorageManager.shared.saveMatch(matchResult)
        MatchStorageManager.shared.updatePlayerStats(for: matchPlayers, winnerId: winner.id)
        
        let currentUserId = authService?.currentUser?.id
        
        Task {
            do {
                let matchService = MatchService()
                let winnerId = winner.userId
                let updatedUser = try await matchService.saveMatch(
                    matchId: matchId,
                    gameId: "sudden_death",
                    players: players,
                    winnerId: winnerId,
                    startedAt: matchStartTime,
                    endedAt: Date(),
                    turnHistory: [],
                    matchFormat: 1,
                    legsWon: [:],
                    currentUserId: currentUserId
                )
                
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
}
