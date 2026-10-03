//
//  ProfileStatsCalculatorTests.swift
//  DanDartTests
//
//  Solo practice must stay out of the main Profile widgets and Recent Form, and be
//  computed on its own for the Practice Sessions section.
//

import Foundation
import Testing
@testable import DanDart

struct ProfileStatsCalculatorTests {

    private let me = UUID()
    private let opponent = UUID()

    private func visit(_ darts: [MatchDart], turn: Int) -> MatchTurn {
        MatchTurn(
            turnNumber: turn,
            darts: darts,
            scoreBefore: 301,
            scoreAfter: 301 - darts.reduce(0) { $0 + $1.value },
            isBust: false
        )
    }

    private func player(_ id: UUID, darts: [MatchDart], finalScore: Int = 0) -> MatchPlayer {
        MatchPlayer(
            id: id,
            displayName: "P",
            nickname: "p",
            avatarURL: nil,
            isGuest: false,
            finalScore: finalScore,
            startingScore: 301,
            totalDartsThrown: darts.count,
            turns: [visit(darts, turn: 1)]
        )
    }

    private func match(players: [MatchPlayer], winner: UUID, at seconds: TimeInterval) -> MatchResult {
        MatchResult(
            gameType: "301",
            gameName: "301",
            players: players,
            winnerId: winner,
            timestamp: Date(timeIntervalSince1970: seconds),
            duration: 60
        )
    }

    private var t20x3: [MatchDart] { Array(repeating: MatchDart(baseValue: 20, multiplier: 3), count: 3) } // a 180
    private var s20x3: [MatchDart] { Array(repeating: MatchDart(baseValue: 20, multiplier: 1), count: 3) } // a 60

    private var realMatch: MatchResult {
        match(players: [player(me, darts: t20x3), player(opponent, darts: s20x3, finalScore: 100)], winner: me, at: 1000)
    }

    private var practiceSession: MatchResult {
        match(players: [player(me, darts: s20x3)], winner: me, at: 2000)
    }

    // MARK: - partition

    @Test func aSoloMatchIsPracticeAndATwoPlayerMatchIsNot() {
        let split = ProfileStatsCalculator.partition([realMatch, practiceSession])

        #expect(split.matches.count == 1)
        #expect(split.practice.count == 1)
        #expect(split.practice.first?.players.count == 1)
    }

    @Test func aMatchAgainstAGuestIsNotPractice() {
        let guest = MatchPlayer(
            id: UUID(), displayName: "Guest", nickname: "", avatarURL: nil, isGuest: true,
            finalScore: 120, startingScore: 301, totalDartsThrown: 3, turns: []
        )
        let vsGuest = match(players: [player(me, darts: t20x3), guest], winner: me, at: 1000)

        let split = ProfileStatsCalculator.partition([vsGuest])

        #expect(split.matches.count == 1)
        #expect(split.practice.isEmpty)
    }

    // MARK: - main vs practice

    @Test func practiceNeverReachesTheMainWidgets() {
        let split = ProfileStatsCalculator.partition([realMatch, practiceSession])
        let main = ProfileStatsCalculator.throwingStats(matches: split.matches, userId: me)

        #expect(main.threeDartAverageHistory.map(\.matchId) == split.matches.map(\.id))
        #expect(main.scoringDistribution.totalVisits == 1)
        #expect(main.scoringDistribution.bucket180.count == 1)
        #expect(main.highestVisit == 180)
        #expect(main.matchCount == 1)
    }

    @Test func practiceIsComputedSeparatelyFromTheSameData() {
        let split = ProfileStatsCalculator.partition([realMatch, practiceSession])
        let practice = ProfileStatsCalculator.throwingStats(matches: split.practice, userId: me)

        #expect(practice.matchCount == 1)
        #expect(practice.threeDartAverageHistory.map(\.matchId) == split.practice.map(\.id))
        #expect(practice.scoringDistribution.totalVisits == 1)
        #expect(practice.scoringDistribution.bucket41_99.count == 1) // the 60
        #expect(practice.scoringDistribution.bucket180.count == 0)
        #expect(practice.highestVisit == 60)
    }

    @Test func noPracticeLeavesThePracticeStatsEmpty() {
        let split = ProfileStatsCalculator.partition([realMatch])
        let practice = ProfileStatsCalculator.throwingStats(matches: split.practice, userId: me)

        #expect(practice.matchCount == 0)
        #expect(practice.threeDartAverageHistory.isEmpty)
        #expect(practice.avgDartsRank == .unranked)
    }

    // MARK: - recent form

    @Test func recentFormFromRealMatchesCountsWinsAndLosses() {
        let lost = match(players: [player(me, darts: s20x3, finalScore: 100), player(opponent, darts: t20x3)], winner: opponent, at: 3000)
        let form = ProfileStatsCalculator.recentForm(matches: [realMatch, lost], userId: me)

        #expect(form.map(\.isWin) == [false, true]) // newest first
    }

    @Test func recentFormIsCappedAtTenNewestFirst() {
        let many = (0..<12).map { match(players: [player(me, darts: t20x3), player(opponent, darts: s20x3, finalScore: 100)], winner: me, at: Double($0)) }
        let form = ProfileStatsCalculator.recentForm(matches: many, userId: me)

        #expect(form.count == 10)
        #expect(form.first?.timestamp == Date(timeIntervalSince1970: 11))
    }
}
