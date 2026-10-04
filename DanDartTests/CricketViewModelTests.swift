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

    @Test func noPayloadUntilThereIsAWinner() {
        let g = makeGame()
        throwDart(g.vm, 20)

        #expect(g.vm.makeMatchPayload() == nil)
    }
}
