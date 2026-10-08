//
//  CricketCutThroatEngineTests.swift
//  DanDartTests
//
//  Cut-Throat Cricket: overflow points go to the opponents, lowest score wins.
//

import Foundation
import Testing
@testable import DanDart

struct CricketCutThroatEngineTests {

    // MARK: - helpers

    private func game(_ playerCount: Int = 3) -> (state: CricketState, ids: [UUID]) {
        let ids = (0..<playerCount).map { _ in UUID() }
        return (CricketState(playerIds: ids, scoring: .cutThroat), ids)
    }

    private func throwDart(_ state: CricketState, _ target: CricketTarget?, _ marks: Int)
        -> (state: CricketState, outcome: CricketOutcome) {
        CricketEngine.apply(CricketDart(target: target, marks: marks), to: state)
    }

    private func close(_ state: inout CricketState, _ id: UUID,
                       targets: [CricketTarget] = CricketTarget.allCases) {
        for target in targets { state.markCounts[id]![target] = 3 }
    }

    private let everythingButTwenty: [CricketTarget] = [.nineteen, .eighteen, .seventeen, .sixteen, .fifteen, .bull]

    // MARK: - scoring mode

    @Test func scoringIsStandardByDefault() {
        let state = CricketState(playerIds: [UUID(), UUID()])
        #expect(state.scoring == .standard)
    }

    @Test func scoringMatchesTheSavedMatchFormat() {
        #expect(CricketScoring.standard.matchFormat == 1)
        #expect(CricketScoring.cutThroat.matchFormat == 2)
        #expect(CricketScoring(matchFormat: 2) == .cutThroat)
        #expect(CricketScoring(matchFormat: 1) == .standard)
        #expect(CricketScoring(matchFormat: 0) == .standard)
        #expect(CricketScoring(matchFormat: 7) == .standard)
    }

    // MARK: - scoring

    @Test func overflowGoesToEachOpenOpponentAndNotTheThrower() {
        var g = game(3)
        close(&g.state, g.ids[0], targets: [.twenty])
        let r = throwDart(g.state, .twenty, 1)

        #expect(r.state.points(for: g.ids[0]) == 0)
        #expect(r.state.points(for: g.ids[1]) == 20)
        #expect(r.state.points(for: g.ids[2]) == 20)
        #expect(r.outcome.pointsScored == 20)
        #expect(r.outcome.marksAdded == 0)
    }

    @Test func opponentsWhoHaveClosedTheTargetGetNothing() {
        var g = game(3)
        close(&g.state, g.ids[0], targets: [.twenty])
        close(&g.state, g.ids[1], targets: [.twenty])
        let r = throwDart(g.state, .twenty, 2)

        #expect(r.state.points(for: g.ids[1]) == 0)
        #expect(r.state.points(for: g.ids[2]) == 40)
        #expect(r.state.points(for: g.ids[0]) == 0)
    }

    @Test func nothingScoresOnADeadTarget() {
        var g = game(3)
        for id in g.ids { close(&g.state, id, targets: [.twenty]) }
        let r = throwDart(g.state, .twenty, 3)

        #expect(g.ids.allSatisfy { r.state.points(for: $0) == 0 })
        #expect(r.outcome.pointsScored == 0)
    }

    @Test func aTrebleThatClosesThenOverflowsGivesTheOverflowToOpponents() {
        var g = game(2)
        g.state.markCounts[g.ids[0]]![.nineteen] = 2 // one more mark closes it; two are overflow
        let r = throwDart(g.state, .nineteen, 3)

        #expect(r.state.marks(for: g.ids[0], on: .nineteen) == 3)
        #expect(r.state.points(for: g.ids[0]) == 0)
        #expect(r.state.points(for: g.ids[1]) == 38)
        #expect(r.outcome.marksAdded == 1)
        #expect(r.outcome.pointsScored == 38)
    }

    @Test func twoPlayerCutThroatHandsThePointsToTheOtherPlayer() {
        var g = game(2)
        close(&g.state, g.ids[0], targets: [.twenty])
        let r = throwDart(g.state, .twenty, 1)

        #expect(r.state.points(for: g.ids[0]) == 0)
        #expect(r.state.points(for: g.ids[1]) == 20)
    }

    @Test func standardScoringStillCreditsTheThrower() {
        let ids = [UUID(), UUID(), UUID()]
        var state = CricketState(playerIds: ids, scoring: .standard)
        state.markCounts[ids[0]]![.twenty] = 3
        let r = CricketEngine.apply(CricketDart(target: .twenty, marks: 1), to: state)

        #expect(r.state.points(for: ids[0]) == 20)
        #expect(r.state.points(for: ids[1]) == 0)
    }

    // MARK: - winning

    @Test func closingEverythingWhileLowestWins() {
        var g = game(2)
        close(&g.state, g.ids[0], targets: everythingButTwenty)
        g.state.pointTotals[g.ids[1]] = 30
        let r = throwDart(g.state, .twenty, 3)

        #expect(r.state.winnerId == g.ids[0])
        #expect(r.outcome.won)
    }

    @Test func closingEverythingWithEqualPointsWins() {
        var g = game(2)
        close(&g.state, g.ids[0], targets: everythingButTwenty)
        g.state.pointTotals[g.ids[0]] = 30
        g.state.pointTotals[g.ids[1]] = 30
        let r = throwDart(g.state, .twenty, 3)

        #expect(r.state.winnerId == g.ids[0])
    }

    @Test func closingEverythingWhileHigherKeepsPlaying() {
        var g = game(2)
        close(&g.state, g.ids[0], targets: everythingButTwenty)
        g.state.pointTotals[g.ids[0]] = 40
        g.state.pointTotals[g.ids[1]] = 30
        let r = throwDart(g.state, .twenty, 3)

        #expect(r.state.winnerId == nil)
        #expect(r.outcome.won == false)
        #expect(r.state.hasClosedAll(g.ids[0]))
    }

    @Test func aPlayerWhoClosedEarlierWinsOnceTheLowerPlayerIsFedPastThem() {
        // Anna (0) closed everything on 20 points while Ben (1) was on 10, so she did not win.
        // Cara (2) now scores 15 on Ben, who is still open on 15: Ben goes to 25 and Anna is lowest.
        var g = game(3)
        close(&g.state, g.ids[0])
        g.state.pointTotals[g.ids[0]] = 20
        g.state.pointTotals[g.ids[1]] = 10
        g.state.pointTotals[g.ids[2]] = 30
        g.state.markCounts[g.ids[2]]![.fifteen] = 3
        g.state.currentPlayerIndex = 2

        let r = throwDart(g.state, .fifteen, 1)

        #expect(r.state.points(for: g.ids[1]) == 25)
        #expect(r.state.winnerId == g.ids[0])
        #expect(r.outcome.won)
    }

    @Test func theThrowerWinsWhenSeveralPlayersQualifyAtOnce() {
        var g = game(3)
        close(&g.state, g.ids[0])                                     // Anna: closed all, 10 points
        close(&g.state, g.ids[2], targets: everythingButTwenty)       // Cara about to close the last one
        g.state.pointTotals[g.ids[0]] = 10
        g.state.pointTotals[g.ids[1]] = 20
        g.state.pointTotals[g.ids[2]] = 10
        g.state.currentPlayerIndex = 2

        let r = throwDart(g.state, .twenty, 3)

        #expect(r.state.winnerId == g.ids[2])
    }

    // MARK: - placements

    @Test func placementsRankTheWinnerThenMostClosedThenFewestPoints() {
        var g = game(3)
        close(&g.state, g.ids[0])
        g.state.winnerId = g.ids[0]
        close(&g.state, g.ids[1], targets: [.twenty, .nineteen, .eighteen])
        close(&g.state, g.ids[2], targets: [.twenty, .nineteen, .eighteen])
        g.state.pointTotals[g.ids[1]] = 40
        g.state.pointTotals[g.ids[2]] = 10

        let places = CricketEngine.placements(for: g.state)

        #expect(places[g.ids[0]] == 1)
        #expect(places[g.ids[2]] == 2)
        #expect(places[g.ids[1]] == 3)
    }

    @Test func standardPlacementsStillRankMostPointsFirst() {
        let ids = [UUID(), UUID(), UUID()]
        var state = CricketState(playerIds: ids, scoring: .standard)
        state.winnerId = ids[0]
        state.pointTotals[ids[1]] = 10
        state.pointTotals[ids[2]] = 40

        let places = CricketEngine.placements(for: state)

        #expect(places[ids[2]] == 2)
        #expect(places[ids[1]] == 3)
    }
}
