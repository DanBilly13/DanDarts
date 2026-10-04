//
//  CricketViewModelTests.swift
//  DanDartTests
//
//  Turn flow, undo and the saved payload for a Cricket game.
//

import Foundation
import Testing
@testable import DanDart

@MainActor
struct CricketViewModelTests {

    /// Two players in a fixed order (A throws first). Never saves to storage or the network.
    private func makeGame() -> (vm: CricketViewModel, a: Player, b: Player) {
        let a = Player(displayName: "A", nickname: "a")
        let b = Player(displayName: "B", nickname: "b")
        let vm = CricketViewModel(players: [a, b], shuffle: false, persistsMatch: false)
        return (vm, a, b)
    }

    private func throwDart(_ vm: CricketViewModel, _ value: Int, _ type: ScoreType = .single) {
        vm.recordThrow(value: value, scoreType: type)
    }

    private func missVisit(_ vm: CricketViewModel) {
        for _ in 0..<3 { throwDart(vm, 0) }
        vm.completeTurn()
    }

    /// A wins on the second dart of their fourth visit: T20 T19 T18 / T17 T16 T15 / bull, 25.
    private func playUpToTheWinningDart(_ vm: CricketViewModel) {
        for value in [20, 19, 18] { throwDart(vm, value, .triple) }
        vm.completeTurn()
        missVisit(vm)
        for value in [17, 16, 15] { throwDart(vm, value, .triple) }
        vm.completeTurn()
        missVisit(vm)
        throwDart(vm, 50) // inner bull: 2 marks
        throwDart(vm, 25) // outer bull: the third mark
    }

    // MARK: - darts

    @Test func aDartUpdatesTheBoardAndTheVisit() {
        let g = makeGame()
        throwDart(g.vm, 20, .triple)

        #expect(g.vm.state.marks(for: g.a.id, on: .twenty) == 3)
        #expect(g.vm.currentThrow.count == 1)
        #expect(g.vm.currentThrow[0].displayText == "T20")
    }

    @Test func aVisitSavesAfterThreeDartsAndNotBefore() {
        let g = makeGame()
        throwDart(g.vm, 20)
        throwDart(g.vm, 20)
        #expect(g.vm.canSave == false)

        throwDart(g.vm, 20)
        #expect(g.vm.canSave)
    }

    @Test func aFourthDartIsIgnored() {
        let g = makeGame()
        for _ in 0..<4 { throwDart(g.vm, 20) }

        #expect(g.vm.currentThrow.count == 3)
    }

    @Test func savingTheVisitPassesPlayOn() {
        let g = makeGame()
        for _ in 0..<3 { throwDart(g.vm, 0) }
        g.vm.completeTurn()

        #expect(g.vm.state.currentPlayerId == g.b.id)
        #expect(g.vm.currentThrow.isEmpty)
        #expect(g.vm.canSave == false)
    }

    // MARK: - undo

    @Test func deletingAClosingDartTakesTheMarksBack() {
        let g = makeGame()
        throwDart(g.vm, 20, .triple)
        g.vm.deleteThrow()

        #expect(g.vm.state.marks(for: g.a.id, on: .twenty) == 0)
        #expect(g.vm.currentThrow.isEmpty)
        #expect(g.vm.selectedDartIndex == 0)
    }

    @Test func deletingAScoringDartTakesTheMarksAndPointsBack() {
        let g = makeGame()
        throwDart(g.vm, 20, .triple)
        throwDart(g.vm, 20) // 20 points
        #expect(g.vm.state.points(for: g.a.id) == 20)

        g.vm.deleteThrow()

        #expect(g.vm.state.points(for: g.a.id) == 0)
        #expect(g.vm.state.marks(for: g.a.id, on: .twenty) == 3)
        #expect(g.vm.currentThrow.count == 1)
    }

    @Test func deleteDoesNothingWithNoDarts() {
        let g = makeGame()
        #expect(g.vm.canDelete == false)
        g.vm.deleteThrow()
        #expect(g.vm.currentThrow.isEmpty)
    }

    // MARK: - winning

    @Test func theWinningDartWaitsForSaveAndCanBeUndone() {
        let g = makeGame()
        playUpToTheWinningDart(g.vm)

        #expect(g.vm.state.winnerId == g.a.id)
        #expect(g.vm.isWinningThrow)
        #expect(g.vm.canSave)
        #expect(g.vm.isGameOver == false)

        g.vm.deleteThrow()

        #expect(g.vm.state.winnerId == nil)
        #expect(g.vm.isWinningThrow == false)
        #expect(g.vm.canSave == false)
        #expect(g.vm.state.marks(for: g.a.id, on: .bull) == 2)
    }

    @Test func noMoreDartsAfterTheWinningDart() {
        let g = makeGame()
        playUpToTheWinningDart(g.vm)
        throwDart(g.vm, 20)

        #expect(g.vm.currentThrow.count == 2)
    }

    @Test func savingTheWinningVisitEndsTheGame() {
        let g = makeGame()
        playUpToTheWinningDart(g.vm)
        g.vm.completeTurn()

        #expect(g.vm.isGameOver)
        #expect(g.vm.winner?.id == g.a.id)
        #expect(g.vm.canDelete == false)
    }

    // MARK: - saved payload

    @Test func theSavedMatchHasPlacementsAndPerDartData() throws {
        let g = makeGame()
        playUpToTheWinningDart(g.vm)
        g.vm.completeTurn()

        let payload = try #require(g.vm.makeMatchPayload())
        let result = payload.matchResult

        #expect(result.gameName == "Cricket")
        #expect(result.gameType == "Cricket")
        #expect(result.winnerId == g.a.id)
        #expect(result.metadata?["placement_\(g.a.id.uuidString)"] == "1")
        #expect(result.metadata?["placement_\(g.b.id.uuidString)"] == "2")

        // Every turn carries its darts as cricket_darts.
        #expect(payload.turnHistory.count == 5) // A: 3 visits, B: 2 visits
        #expect(payload.turnHistory.allSatisfy { $0.gameMetadata?["cricket_darts"] != nil })

        // And the final board can be rebuilt from what was saved.
        let boards = CricketBoardBuilder.build(players: result.players)
        let boardA = try #require(boards[g.a.id])
        #expect(CricketTarget.allCases.allSatisfy { boardA.marks(on: $0) == 3 })
        #expect(boards[g.b.id]?.marks(on: .twenty) == 0)
    }

    @Test func theBoardRebuiltFromWhatTheDatabaseReturnsMatchesTheGame() throws {
        let g = makeGame()
        playUpToTheWinningDart(g.vm)
        g.vm.completeTurn()
        let payload = try #require(g.vm.makeMatchPayload())

        // Rebuild the players the way MatchesService does when it reads Supabase.
        let rebuilt = g.vm.players.map { player -> MatchPlayer in
            let saved = payload.turnHistory
                .filter { $0.playerId == player.id }
                .sorted { $0.turnNumber < $1.turnNumber }
            let turns = saved.map { turn -> MatchTurn in
                let cricketDarts = CricketMatchData.decodeAll(from: turn.gameMetadata as [String: Any]?)
                let darts = turn.darts.enumerated().map { index, dart in
                    MatchDart(baseValue: dart.totalValue, multiplier: 1, killerMetadata: nil,
                              cricketMetadata: cricketDarts[index])
                }
                return MatchTurn(turnNumber: turn.turnNumber, darts: darts,
                                 scoreBefore: turn.scoreBefore, scoreAfter: turn.scoreAfter, isBust: false)
            }
            return MatchPlayer.from(player: player, finalScore: 0, startingScore: 0,
                                    totalDartsThrown: turns.reduce(0) { $0 + $1.darts.count }, turns: turns)
        }

        let boards = CricketBoardBuilder.build(players: rebuilt)
        for player in g.vm.players {
            let board = try #require(boards[player.id])
            for target in CricketTarget.allCases {
                #expect(board.marks(on: target) == g.vm.state.marks(for: player.id, on: target))
            }
            #expect(board.points == g.vm.state.points(for: player.id))
        }
    }

    @Test func undoThenADifferentDartIsWhatGetsSaved() throws {
        let g = makeGame()
        throwDart(g.vm, 20, .triple)
        g.vm.deleteThrow()
        for value in [19, 18, 17] { throwDart(g.vm, value, .triple) }
        g.vm.completeTurn()
        missVisit(g.vm)
        for value in [20, 16, 15] { throwDart(g.vm, value, .triple) }
        g.vm.completeTurn()
        missVisit(g.vm)
        throwDart(g.vm, 50)
        throwDart(g.vm, 25)
        g.vm.completeTurn()

        let payload = try #require(g.vm.makeMatchPayload())
        let firstTurn = try #require(payload.turnHistory
            .filter { $0.playerId == g.a.id }
            .min { $0.turnNumber < $1.turnNumber })
        let darts = CricketMatchData.decodeAll(from: firstTurn.gameMetadata as [String: Any]?)

        #expect(firstTurn.darts.map(\.displayText) == ["T19", "T18", "T17"])
        #expect(darts.count == 3)
        #expect(darts[0]?.target == 19)
    }

    @Test func aSignedInMembersIdsAreUsedConsistently() throws {
        let memberUserId = UUID()
        let a = Player(displayName: "A", nickname: "a", isGuest: false, userId: memberUserId)
        let b = Player(displayName: "B", nickname: "b")
        let vm = CricketViewModel(players: [a, b], shuffle: false, persistsMatch: false)
        playUpToTheWinningDart(vm)
        vm.completeTurn()

        let payload = try #require(vm.makeMatchPayload())
        let result = payload.matchResult

        #expect(result.winnerId == memberUserId)
        #expect(result.metadata?["placement_\(memberUserId.uuidString)"] == "1")
        #expect(CricketBoardBuilder.build(players: result.players)[memberUserId] != nil)
        let turnsOfA = payload.turnHistory.filter { $0.player.id == a.id }
        #expect(turnsOfA.count == 3)
        #expect(turnsOfA.allSatisfy { $0.playerId == a.id })
    }

    @Test func noPayloadUntilThereIsAWinner() {
        let g = makeGame()
        throwDart(g.vm, 20)

        #expect(g.vm.makeMatchPayload() == nil)
    }
}
