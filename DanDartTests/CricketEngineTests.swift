//
//  CricketEngineTests.swift
//  DanDartTests
//
//  The Cricket rules: marks, closing, scoring on overflow, dead targets, winning.
//

import Foundation
import Testing
@testable import DanDart

struct CricketEngineTests {

    // MARK: - helpers

    private func game(_ playerCount: Int = 2) -> (state: CricketState, ids: [UUID]) {
        let ids = (0..<playerCount).map { _ in UUID() }
        return (CricketState(playerIds: ids), ids)
    }

    /// One dart thrown by whoever is up.
    private func throwDart(_ state: CricketState, _ target: CricketTarget?, _ marks: Int)
        -> (state: CricketState, outcome: CricketOutcome) {
        CricketEngine.apply(CricketDart(target: target, marks: marks), to: state)
    }

    private func close(_ state: inout CricketState, _ id: UUID,
                       targets: [CricketTarget] = CricketTarget.allCases) {
        for target in targets { state.markCounts[id]![target] = 3 }
    }

    private let everythingButBull: [CricketTarget] = [.twenty, .nineteen, .eighteen, .seventeen, .sixteen, .fifteen]

    // MARK: - marks

    @Test func aSingleAddsOneMark() {
        let g = game()
        let r = throwDart(g.state, .twenty, 1)

        #expect(r.state.marks(for: g.ids[0], on: .twenty) == 1)
        #expect(r.outcome.marksAdded == 1)
        #expect(r.outcome.pointsScored == 0)
    }

    @Test func aTrebleClosesATargetInOneDart() {
        let g = game()
        let r = throwDart(g.state, .nineteen, 3)

        #expect(r.state.marks(for: g.ids[0], on: .nineteen) == 3)
        #expect(r.outcome.closedTarget)
        #expect(r.outcome.pointsScored == 0)
    }

    @Test func threeSinglesCloseATarget() {
        let g = game()
        var s = g.state
        s = throwDart(s, .eighteen, 1).state
        s = throwDart(s, .eighteen, 1).state
        let r = throwDart(s, .eighteen, 1)

        #expect(r.state.marks(for: g.ids[0], on: .eighteen) == 3)
        #expect(r.outcome.closedTarget)
    }

    @Test func aMissRecordsNoMarksButUsesTheDart() {
        let g = game()
        let r = throwDart(g.state, nil, 0)

        #expect(CricketTarget.allCases.allSatisfy { r.state.marks(for: g.ids[0], on: $0) == 0 })
        #expect(r.state.dartsThrown == 1)
        #expect(r.outcome == CricketOutcome())
    }

    // MARK: - scoring

    @Test func extraHitsScoreWhileAnOpponentIsOpen() {
        let g = game()
        var s = throwDart(g.state, .twenty, 3).state
        let r = throwDart(s, .twenty, 1)
        s = r.state

        #expect(r.outcome.pointsScored == 20)
        #expect(s.points(for: g.ids[0]) == 20)
    }

    @Test func aTrebleOnTwoMarksClosesWithOneAndScoresTheOtherTwo() {
        var g = game()
        g.state.markCounts[g.ids[0]]![.twenty] = 2
        let r = throwDart(g.state, .twenty, 3)

        #expect(r.outcome.marksAdded == 1)
        #expect(r.outcome.closedTarget)
        #expect(r.outcome.pointsScored == 40)
    }

    @Test func noPointsOnceEveryOpponentHasClosedTheTarget() {
        var g = game()
        close(&g.state, g.ids[1], targets: [.twenty])
        var s = throwDart(g.state, .twenty, 3).state
        let r = throwDart(s, .twenty, 1)
        s = r.state

        #expect(r.outcome.pointsScored == 0)
        #expect(s.points(for: g.ids[0]) == 0)
    }

    @Test func inThreePlayersOneOpenOpponentIsEnough() {
        var g = game(3)
        close(&g.state, g.ids[1], targets: [.twenty]) // second player closed, third still open
        var s = throwDart(g.state, .twenty, 3).state
        let r = throwDart(s, .twenty, 1)
        s = r.state

        #expect(r.outcome.pointsScored == 20)
    }

    @Test func theBullScoresTwentyFivePerExtraMark() {
        var g = game()
        close(&g.state, g.ids[0], targets: [.bull])
        let r = CricketEngine.apply(CricketDart.from(baseValue: 50, scoreType: .single), to: g.state)

        #expect(r.outcome.pointsScored == 50) // inner bull = 2 marks, both overflow
    }

    // MARK: - dead targets

    @Test func closingTheLastOpenTargetMakesItDead() {
        var g = game()
        close(&g.state, g.ids[1], targets: [.twenty])
        let r = throwDart(g.state, .twenty, 3)

        #expect(r.outcome.targetBecameDead)
        #expect(r.state.isDead(.twenty))
        #expect(r.state.isDead(.nineteen) == false)
    }

    @Test func aDeadTargetGivesNothing() {
        var g = game()
        for id in g.ids { close(&g.state, id, targets: [.twenty]) }
        let r = throwDart(g.state, .twenty, 3)

        #expect(r.outcome.marksAdded == 0)
        #expect(r.outcome.pointsScored == 0)
        #expect(r.state.dartsThrown == 1)
    }

    // MARK: - converting keypad input

    @Test func theOuterBullIsOneMarkAndTheInnerBullIsTwo() {
        #expect(CricketDart.from(baseValue: 25, scoreType: .single) == CricketDart(target: .bull, marks: 1))
        #expect(CricketDart.from(baseValue: 50, scoreType: .single) == CricketDart(target: .bull, marks: 2))
        #expect(CricketDart.from(baseValue: 25, scoreType: .double) == CricketDart(target: .bull, marks: 2))
    }

    @Test func numbersOutsideCricketAreMisses() {
        #expect(CricketDart.from(baseValue: 14, scoreType: .triple) == .miss)
        #expect(CricketDart.from(baseValue: 0, scoreType: .single) == .miss)
    }

    @Test func multipliersBecomeMarks() {
        #expect(CricketDart.from(baseValue: 20, scoreType: .single).marks == 1)
        #expect(CricketDart.from(baseValue: 20, scoreType: .double).marks == 2)
        #expect(CricketDart.from(baseValue: 15, scoreType: .triple).marks == 3)
    }

    // MARK: - turns

    @Test func aVisitIsThreeDarts() {
        let g = game()
        var s = g.state
        for _ in 0..<3 { s = throwDart(s, .twenty, 1).state }
        let fourth = throwDart(s, .twenty, 1)

        #expect(fourth.state == s)
        #expect(fourth.outcome == CricketOutcome())
    }

    @Test func endingTheVisitPassesPlayRoundTheTable() {
        let g = game()
        let one = CricketEngine.endVisit(throwDart(g.state, .twenty, 1).state)
        let two = CricketEngine.endVisit(one)

        #expect(one.currentPlayerId == g.ids[1])
        #expect(one.dartsThrown == 0)
        #expect(two.currentPlayerId == g.ids[0])
    }

    // MARK: - winning

    @Test func closingEverythingWhileLevelOnPointsWins() {
        var g = game()
        close(&g.state, g.ids[0], targets: everythingButBull)
        g.state.markCounts[g.ids[0]]![.bull] = 1
        let r = throwDart(g.state, .bull, 2)

        #expect(r.outcome.won)
        #expect(r.state.winnerId == g.ids[0])
    }

    @Test func equalPointsAboveZeroStillWin() {
        var g = game()
        close(&g.state, g.ids[0], targets: everythingButBull)
        g.state.markCounts[g.ids[0]]![.bull] = 1
        g.state.pointTotals[g.ids[0]] = 10
        g.state.pointTotals[g.ids[1]] = 10
        let r = throwDart(g.state, .bull, 2)

        #expect(r.state.winnerId == g.ids[0])
    }

    @Test func closingEverythingWhileBehindOnPointsDoesNotWin() {
        var g = game()
        close(&g.state, g.ids[0], targets: everythingButBull)
        g.state.markCounts[g.ids[0]]![.bull] = 1
        g.state.pointTotals[g.ids[1]] = 10
        let r = throwDart(g.state, .bull, 2)

        #expect(r.state.winnerId == nil)
        #expect(r.outcome.won == false)
        #expect(r.state.hasClosedAll(g.ids[0]))
    }

    @Test func aPlayerClosedOutAndBehindWinsByScoringPastTheLeader() {
        var g = game()
        close(&g.state, g.ids[0])                 // closed everything
        g.state.pointTotals[g.ids[1]] = 10        // leader, with the 20s still open
        let r = throwDart(g.state, .twenty, 1)    // 20 more points: 20 >= 10

        #expect(r.outcome.pointsScored == 20)
        #expect(r.state.winnerId == g.ids[0])
    }

    @Test func nothingCanBeThrownAfterTheGameIsWon() {
        var g = game()
        close(&g.state, g.ids[0], targets: everythingButBull)
        g.state.markCounts[g.ids[0]]![.bull] = 1
        let won = throwDart(g.state, .bull, 2).state
        let after = throwDart(won, .twenty, 1)

        #expect(after.state == won)
        #expect(CricketEngine.endVisit(won) == won)
    }

    @Test func theThirdPlayerCanWinInAThreePlayerGame() {
        var g = game(3)
        g.state.currentPlayerIndex = 2
        close(&g.state, g.ids[2], targets: everythingButBull)
        g.state.markCounts[g.ids[2]]![.bull] = 2
        g.state.pointTotals[g.ids[0]] = 5
        g.state.pointTotals[g.ids[1]] = 5
        g.state.pointTotals[g.ids[2]] = 5
        let r = throwDart(g.state, .bull, 1)

        #expect(r.state.winnerId == g.ids[2])
    }

    // MARK: - placements

    @Test func theWinnerIsFirstThenMostClosedThenMostPointsThenThrowingOrder() {
        var g = game(4)
        let (a, b, c, d) = (g.ids[0], g.ids[1], g.ids[2], g.ids[3])
        g.state.winnerId = c
        close(&g.state, c)
        close(&g.state, a, targets: [.twenty, .nineteen, .eighteen])
        close(&g.state, b, targets: [.twenty, .nineteen, .eighteen])
        g.state.pointTotals[b] = 40
        close(&g.state, d, targets: [.twenty])

        let placements = CricketEngine.placements(for: g.state)

        #expect(placements[c] == 1)
        #expect(placements[b] == 2) // same closed count as a, more points
        #expect(placements[a] == 3)
        #expect(placements[d] == 4)
    }

    @Test func throwingOrderBreaksAFullTie() {
        var g = game(3)
        g.state.winnerId = g.ids[2]

        let placements = CricketEngine.placements(for: g.state)

        #expect(placements[g.ids[2]] == 1)
        #expect(placements[g.ids[0]] == 2)
        #expect(placements[g.ids[1]] == 3)
    }
}
