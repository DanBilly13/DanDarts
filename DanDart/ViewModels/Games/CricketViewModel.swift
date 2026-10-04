//
//  CricketViewModel.swift
//  Dart Freak
//
//  Turn flow for Cricket (Tactics). The rules live in CricketEngine; this keeps the visit
//  on screen, one state snapshot per dart so deleting a dart restores the game exactly,
//  and saves the finished match the way Killer does.
//

import Foundation
import SwiftUI

/// Everything a finished Cricket match sends to storage.
struct CricketMatchPayload {
    let matchResult: MatchResult
    let turnHistory: [TurnHistory]
}

@MainActor
final class CricketViewModel: ObservableObject {

    // MARK: - Published

    @Published private(set) var state: CricketState
    @Published var currentThrow: [ScoredThrow] = []
    @Published var selectedDartIndex: Int? = 0
    @Published private(set) var winner: Player?
    @Published private(set) var isGameOver = false

    // MARK: - Setup

    /// In throwing order.
    let players: [Player]
    let matchId = UUID()
    var authService: AuthService?

    private let startedAt = Date()
    private let persistsMatch: Bool
    private let soundManager = SoundManager.shared

    /// Parallel to `currentThrow`.
    private var currentThrowMetadata: [CricketDartMetadata] = []
    /// One snapshot per dart in `currentThrow`, taken just before the dart. Cleared when the visit is saved.
    private var dartSnapshots: [CricketState] = []
    private var playerTurnHistory: [UUID: [MatchTurn]] = [:]

    init(players: [Player], shuffle: Bool = true, persistsMatch: Bool = true) {
        let order = shuffle ? players.shuffled() : players
        self.players = order
        self.state = CricketState(playerIds: order.map(\.id))
        self.persistsMatch = persistsMatch
    }

    // MARK: - Derived

    var currentPlayer: Player {
        players.first { $0.id == state.currentPlayerId } ?? players[0]
    }

    /// The winning dart is thrown but not yet saved. It never auto-saves.
    var isWinningThrow: Bool {
        state.winnerId != nil && !isGameOver
    }

    /// Three darts, or the dart that won the game.
    var canSave: Bool {
        !isGameOver && state.isVisitComplete
    }

    /// Once the game is over the match has been saved, so there is nothing left to undo.
    var canDelete: Bool {
        !currentThrow.isEmpty && !isGameOver
    }

    // MARK: - Actions

    func recordThrow(value: Int, scoreType: ScoreType) {
        guard !isGameOver, state.canThrow else { return }

        let dart = CricketDart.from(baseValue: value, scoreType: scoreType)
        dartSnapshots.append(state)

        let result = CricketEngine.apply(dart, to: state)
        state = result.state

        currentThrow.append(ScoredThrow(baseValue: value, scoreType: scoreType))
        currentThrowMetadata.append(CricketDartMetadata(
            target: dart.target?.rawValue,
            marks: dart.marks,
            marksAdded: result.outcome.marksAdded,
            pointsScored: result.outcome.pointsScored
        ))

        if result.outcome.marksAdded > 0 || result.outcome.pointsScored > 0 {
            soundManager.playScoreSound()
        } else {
            soundManager.playMissSound()
        }

        selectedDartIndex = min(currentThrow.count, 2)
    }

    /// Undo the last dart of the visit: remove it AND restore the marks, points and winner it changed.
    func deleteThrow() {
        guard canDelete else { return }

        currentThrow.removeLast()
        if !currentThrowMetadata.isEmpty { currentThrowMetadata.removeLast() }
        if let snapshot = dartSnapshots.popLast() { state = snapshot }

        selectedDartIndex = currentThrow.count
    }

    /// Save the visit: record it, then either end the game or pass play on.
    func completeTurn() {
        guard canSave else { return }

        let player = currentPlayer
        let pointsAfter = state.points(for: player.id)
        let pointsBefore = dartSnapshots.first?.points(for: player.id) ?? pointsAfter

        let darts = currentThrow.enumerated().map { index, dart in
            MatchDart(
                baseValue: dart.baseValue,
                multiplier: dart.scoreType.multiplier,
                cricketMetadata: index < currentThrowMetadata.count ? currentThrowMetadata[index] : nil
            )
        }
        let turnNumber = (playerTurnHistory[player.id] ?? []).count + 1
        playerTurnHistory[player.id, default: []].append(MatchTurn(
            turnNumber: turnNumber,
            darts: darts,
            scoreBefore: pointsBefore,
            scoreAfter: pointsAfter,
            isBust: false
        ))

        if let winnerId = state.winnerId {
            winner = players.first { $0.id == winnerId }
            isGameOver = true
            if persistsMatch { saveMatch() }
            return
        }

        state = CricketEngine.endVisit(state)
        currentThrow.removeAll()
        currentThrowMetadata.removeAll()
        dartSnapshots.removeAll()
        selectedDartIndex = 0
    }

    // MARK: - Saving

    /// The ID stored for a player: their account for members, their own ID for guests.
    private func matchPlayerId(for player: Player) -> UUID {
        player.userId ?? player.id
    }

    /// nil until the game has a winner and its last visit has been recorded.
    func makeMatchPayload() -> CricketMatchPayload? {
        guard isGameOver, let winner else { return nil }

        let matchPlayers = players.map { player -> MatchPlayer in
            let turns = playerTurnHistory[player.id] ?? []
            return MatchPlayer.from(
                player: player,
                finalScore: state.points(for: player.id),
                startingScore: 0,
                totalDartsThrown: turns.reduce(0) { $0 + $1.darts.count },
                turns: turns
            )
        }

        let placements = CricketEngine.placements(for: state)
        var metadata: [String: String] = [:]
        for player in players {
            if let place = placements[player.id] {
                metadata["placement_\(matchPlayerId(for: player).uuidString)"] = "\(place)"
            }
        }

        let result = MatchResult(
            id: matchId,
            gameType: "Cricket",
            gameName: "Cricket",
            players: matchPlayers,
            winnerId: matchPlayerId(for: winner),
            timestamp: Date(),
            duration: Date().timeIntervalSince(startedAt),
            matchFormat: 1,
            totalLegsPlayed: 1,
            metadata: metadata
        )

        var flatTurnHistory: [TurnHistory] = []
        for player in players {
            for (index, turn) in (playerTurnHistory[player.id] ?? []).enumerated() {
                let scoredThrows = turn.darts.map { dart in
                    ScoredThrow(
                        baseValue: dart.baseValue,
                        scoreType: dart.multiplier == 1 ? .single : (dart.multiplier == 2 ? .double : .triple)
                    )
                }
                var gameMetadata: [String: String]?
                if let json = CricketMatchData.encode(turn.darts.map(\.cricketMetadata)) {
                    gameMetadata = [CricketMatchData.metadataKey: json]
                }
                flatTurnHistory.append(TurnHistory(
                    player: player,
                    playerId: player.id,
                    turnNumber: index,
                    darts: scoredThrows,
                    scoreBefore: turn.scoreBefore,
                    scoreAfter: turn.scoreAfter,
                    isBust: false,
                    gameMetadata: gameMetadata
                ))
            }
        }

        return CricketMatchPayload(matchResult: result, turnHistory: flatTurnHistory)
    }

    private func saveMatch() {
        guard let payload = makeMatchPayload(), let winner else { return }
        let matchResult = payload.matchResult
        let winnerMatchId = matchPlayerId(for: winner)

        MatchStorageManager.shared.saveMatch(matchResult)
        MatchStorageManager.shared.updatePlayerStats(for: matchResult.players, winnerId: winnerMatchId)

        let currentUserId = authService?.currentUser?.id
        let matchId = self.matchId
        let metadata = matchResult.metadata ?? [:]
        let players = self.players
        let startedAt = self.startedAt

        Task {
            do {
                let updatedUser = try await MatchService().saveMatch(
                    matchId: matchId,
                    gameId: "cricket",
                    players: players,
                    winnerId: winnerMatchId,
                    startedAt: startedAt,
                    endedAt: Date(),
                    turnHistory: payload.turnHistory,
                    matchFormat: 1,
                    legsWon: [:],
                    gameMetadata: metadata,
                    currentUserId: currentUserId
                )
                print("✅ Cricket match saved to Supabase: \(matchId)")

                await MainActor.run {
                    MatchStorageManager.shared.deleteMatch(withId: matchId)
                    if let updatedUser = updatedUser {
                        self.authService?.currentUser = updatedUser
                        self.authService?.objectWillChange.send()
                    }
                }
            } catch {
                print("❌ Failed to save Cricket match to Supabase: \(error)")
            }
        }
    }
}
