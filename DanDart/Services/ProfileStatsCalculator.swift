//
//  ProfileStatsCalculator.swift
//  Dart Freak
//
//  Pure profile-stat maths over already-loaded 301/501 matches. No loading, no
//  state, so it can be unit tested. ProfileStatsService feeds it the matches.
//
//  A solo match (one player) is a practice session: it has no opponent, so it is
//  not a win or a loss. Practice is computed separately and kept out of the main
//  widgets and Recent Form.
//

import Foundation

enum ProfileStatsCalculator {

    /// Splits matches into real matches (2+ players, including matches against
    /// Guests) and solo practice sessions.
    static func partition(_ matches: [MatchResult]) -> (matches: [MatchResult], practice: [MatchResult]) {
        (matches.filter { !$0.isPractice }, matches.filter { $0.isPractice })
    }

    static func throwingStats(matches: [MatchResult], userId: UUID) -> ThrowingStats {
        let (avgDarts, rank) = avgDartsPerLeg(matches: matches, userId: userId)
        let bests = personalBests(matches: matches, userId: userId)
        return ThrowingStats(
            threeDartAverageHistory: threeDartAverageHistory(matches: matches, userId: userId),
            avgDartsPerLeg: avgDarts,
            avgDartsRank: rank,
            scoringDistribution: scoringDistribution(matches: matches, userId: userId),
            highestVisit: bests.highestVisit,
            bestCheckout: bests.bestCheckout,
            checkoutPercentage: bests.checkoutPercentage,
            matchCount: matches.filter { match in match.players.contains { $0.id == userId } }.count
        )
    }

    // MARK: - 3-dart average

    static func threeDartAverageHistory(matches: [MatchResult], userId: UUID) -> [ThreeDartDataPoint] {
        matches.compactMap { match in
            guard let player = match.players.first(where: { $0.id == userId }) else { return nil }
            return ThreeDartDataPoint(timestamp: match.timestamp, average: player.averageScore, matchId: match.id)
        }
    }

    // MARK: - Darts per leg

    static func avgDartsPerLeg(matches: [MatchResult], userId: UUID) -> (Double, RankTier) {
        let winningMatches = matches.filter { $0.winnerId == userId }
        guard !winningMatches.isEmpty else { return (0, .unranked) }

        var totalDarts = 0
        var totalLegs = 0
        var totalTierScore = 0
        var rankedWinsCount = 0

        for match in winningMatches {
            guard let player = match.players.first(where: { $0.id == userId }) else { continue }
            totalDarts += player.totalDartsThrown
            totalLegs += match.totalLegsPlayed

            // Rank for this specific winning match
            let dartsPerLegThisMatch = Double(player.totalDartsThrown) / Double(match.totalLegsPlayed)
            let rankTier = RankingHelper.rankForWinningDarts(game: match.gameType, dartsThrown: Int(dartsPerLegThisMatch))
            totalTierScore += RankingHelper.tierScore(for: rankTier)
            rankedWinsCount += 1
        }

        guard totalLegs > 0, rankedWinsCount > 0 else { return (0, .unranked) }

        let averageTierScore = Double(totalTierScore) / Double(rankedWinsCount)
        return (
            Double(totalDarts) / Double(totalLegs),
            RankingHelper.profileRankFromAverageTierScore(averageTierScore)
        )
    }

    // MARK: - Scoring distribution

    static func scoringDistribution(matches: [MatchResult], userId: UUID) -> ScoringDistribution {
        var bucket0_40 = 0
        var bucket41_99 = 0
        var bucket100_139 = 0
        var bucket140_179 = 0
        var bucket180 = 0

        for match in matches {
            guard let player = match.players.first(where: { $0.id == userId }) else { continue }

            for turn in player.turns {
                guard !turn.isBust else { continue }

                switch turn.turnTotal {
                case 0...40: bucket0_40 += 1
                case 41...99: bucket41_99 += 1
                case 100...139: bucket100_139 += 1
                case 140...179: bucket140_179 += 1
                case 180: bucket180 += 1
                default: break
                }
            }
        }

        let total = bucket0_40 + bucket41_99 + bucket100_139 + bucket140_179 + bucket180
        guard total > 0 else { return .empty }

        func percentage(_ count: Int) -> Double { Double(count) / Double(total) * 100 }

        return ScoringDistribution(
            bucket0_40: BucketData(range: "0-40", count: bucket0_40, percentage: percentage(bucket0_40), color: "blue"),
            bucket41_99: BucketData(range: "41-99", count: bucket41_99, percentage: percentage(bucket41_99), color: "green"),
            bucket100_139: BucketData(range: "100-139", count: bucket100_139, percentage: percentage(bucket100_139), color: "yellow"),
            bucket140_179: BucketData(range: "140-179", count: bucket140_179, percentage: percentage(bucket140_179), color: "orange"),
            bucket180: BucketData(range: "180", count: bucket180, percentage: percentage(bucket180), color: "red")
        )
    }

    // MARK: - Personal bests

    static func personalBests(matches: [MatchResult], userId: UUID) -> (highestVisit: Int, bestCheckout: Int, checkoutPercentage: Double) {
        var maxVisit = 0
        var maxCheckout = 0
        var checkoutAttempts = 0
        var successfulCheckouts = 0

        for match in matches {
            guard let player = match.players.first(where: { $0.id == userId }) else { continue }

            for turn in player.turns {
                guard !turn.isBust else { continue }

                let score = turn.turnTotal
                maxVisit = max(maxVisit, score)

                if turn.scoreBefore <= 170 {
                    checkoutAttempts += 1
                    if turn.scoreAfter == 0 {
                        successfulCheckouts += 1
                        maxCheckout = max(maxCheckout, score)
                    }
                }
            }
        }

        let percentage = checkoutAttempts > 0 ? Double(successfulCheckouts) / Double(checkoutAttempts) * 100 : 0
        return (maxVisit, maxCheckout, percentage)
    }

    // MARK: - Recent form

    /// Last 10 matches, newest first. Pass real matches only: practice has no result.
    static func recentForm(matches: [MatchResult], userId: UUID) -> [FormResult] {
        matches
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(10)
            .map { FormResult(matchId: $0.id, isWin: $0.winnerId == userId, timestamp: $0.timestamp) }
    }
}
