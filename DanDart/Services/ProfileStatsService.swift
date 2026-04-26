//
//  ProfileStatsService.swift
//  Dart Freak
//
//  Service for calculating profile statistics from match history
//  Only processes 301/501 countdown games (local and remote)
//

import Foundation
import SwiftUI

@MainActor
class ProfileStatsService: ObservableObject {
    static let shared = ProfileStatsService()
    
    @Published var threeDartAverageHistory: [ThreeDartDataPoint] = []
    @Published var avgDartsPerLeg: Double = 0
    @Published var avgDartsRank: RankTier = .unranked
    @Published var scoringDistribution: ScoringDistribution = .empty
    @Published var highestVisit: Int = 0
    @Published var bestCheckout: Int = 0
    @Published var checkoutPercentage: Double = 0
    @Published var recentForm: [FormResult] = []
    @Published var isLoading: Bool = false
    
    private let matchHistoryService = MatchHistoryService.shared
    
    private init() {}
    
    func calculateStats(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let countdownMatches = try await loadCountdownMatches(userId: userId)
            
            calculate3DartAverageHistory(matches: countdownMatches, userId: userId)
            calculateAvgDartsPerLeg(matches: countdownMatches, userId: userId)
            calculateScoringDistribution(matches: countdownMatches, userId: userId)
            calculatePersonalBests(matches: countdownMatches, userId: userId)
            calculateRecentForm(matches: countdownMatches, userId: userId)
            
        } catch {
            print("❌ [ProfileStatsService] Failed to calculate stats: \(error)")
            resetStats()
        }
    }
    
    private func loadCountdownMatches(userId: UUID) async throws -> [MatchResult] {
        await matchHistoryService.refreshSummaries(userId: userId)
        
        let countdownSummaries = matchHistoryService.summaries.filter { summary in
            let gameType = summary.gameType.lowercased()
            return gameType.contains("301") || gameType.contains("501")
        }
        
        var matches: [MatchResult] = []
        for summary in countdownSummaries {
            if let match = try? await matchHistoryService.loadFullDetail(matchId: summary.id) {
                matches.append(match)
            }
        }
        
        return matches.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func calculate3DartAverageHistory(matches: [MatchResult], userId: UUID) {
        var dataPoints: [ThreeDartDataPoint] = []
        
        for match in matches {
            guard let player = match.players.first(where: { $0.id == userId }) else { continue }
            
            let average = player.averageScore
            
            let dataPoint = ThreeDartDataPoint(
                timestamp: match.timestamp,
                average: average,
                matchId: match.id
            )
            dataPoints.append(dataPoint)
        }
        
        threeDartAverageHistory = dataPoints
    }
    
    private func calculateAvgDartsPerLeg(matches: [MatchResult], userId: UUID) {
        let winningMatches = matches.filter { $0.winnerId == userId }
        
        guard !winningMatches.isEmpty else {
            avgDartsPerLeg = 0
            avgDartsRank = .unranked
            return
        }
        
        var totalDarts = 0
        var totalLegs = 0
        
        for match in winningMatches {
            guard let player = match.players.first(where: { $0.id == userId }) else { continue }
            totalDarts += player.totalDartsThrown
            totalLegs += match.totalLegsPlayed
        }
        
        guard totalLegs > 0 else {
            avgDartsPerLeg = 0
            avgDartsRank = .unranked
            return
        }
        
        avgDartsPerLeg = Double(totalDarts) / Double(totalLegs)
        
        let gameType = winningMatches.first?.gameType ?? "301"
        avgDartsRank = RankingHelper.rankForWinningDarts(game: gameType, dartsThrown: Int(avgDartsPerLeg))
    }
    
    private func calculateScoringDistribution(matches: [MatchResult], userId: UUID) {
        var bucket0_40 = 0
        var bucket41_99 = 0
        var bucket100_139 = 0
        var bucket140_179 = 0
        var bucket180 = 0
        
        for match in matches {
            guard let player = match.players.first(where: { $0.id == userId }) else { continue }
            
            for turn in player.turns {
                guard !turn.isBust else { continue }
                
                let score = turn.turnTotal
                
                switch score {
                case 0...40:
                    bucket0_40 += 1
                case 41...99:
                    bucket41_99 += 1
                case 100...139:
                    bucket100_139 += 1
                case 140...179:
                    bucket140_179 += 1
                case 180:
                    bucket180 += 1
                default:
                    break
                }
            }
        }
        
        let total = bucket0_40 + bucket41_99 + bucket100_139 + bucket140_179 + bucket180
        
        guard total > 0 else {
            scoringDistribution = .empty
            return
        }
        
        let pct0_40 = Double(bucket0_40) / Double(total) * 100
        let pct41_99 = Double(bucket41_99) / Double(total) * 100
        let pct100_139 = Double(bucket100_139) / Double(total) * 100
        let pct140_179 = Double(bucket140_179) / Double(total) * 100
        let pct180 = Double(bucket180) / Double(total) * 100
        
        scoringDistribution = ScoringDistribution(
            bucket0_40: BucketData(range: "0-40", count: bucket0_40, percentage: pct0_40, color: "blue"),
            bucket41_99: BucketData(range: "41-99", count: bucket41_99, percentage: pct41_99, color: "green"),
            bucket100_139: BucketData(range: "100-139", count: bucket100_139, percentage: pct100_139, color: "yellow"),
            bucket140_179: BucketData(range: "140-179", count: bucket140_179, percentage: pct140_179, color: "orange"),
            bucket180: BucketData(range: "180", count: bucket180, percentage: pct180, color: "red")
        )
    }
    
    private func calculatePersonalBests(matches: [MatchResult], userId: UUID) {
        var maxVisit = 0
        var maxCheckout = 0
        var checkoutAttempts = 0
        var successfulCheckouts = 0
        
        for match in matches {
            guard let player = match.players.first(where: { $0.id == userId }) else { continue }
            
            for turn in player.turns {
                guard !turn.isBust else { continue }
                
                let score = turn.turnTotal
                
                if score > maxVisit {
                    maxVisit = score
                }
                
                if turn.scoreBefore <= 170 {
                    checkoutAttempts += 1
                    
                    if turn.scoreAfter == 0 {
                        successfulCheckouts += 1
                        if score > maxCheckout {
                            maxCheckout = score
                        }
                    }
                }
            }
        }
        
        highestVisit = maxVisit
        bestCheckout = maxCheckout
        
        if checkoutAttempts > 0 {
            checkoutPercentage = Double(successfulCheckouts) / Double(checkoutAttempts) * 100
        } else {
            checkoutPercentage = 0
        }
    }
    
    private func calculateRecentForm(matches: [MatchResult], userId: UUID) {
        let sortedMatches = matches.sorted { $0.timestamp > $1.timestamp }
        let last10 = Array(sortedMatches.prefix(10))
        
        recentForm = last10.map { match in
            FormResult(
                matchId: match.id,
                isWin: match.winnerId == userId,
                timestamp: match.timestamp
            )
        }
    }
    
    private func resetStats() {
        threeDartAverageHistory = []
        avgDartsPerLeg = 0
        avgDartsRank = .unranked
        scoringDistribution = .empty
        highestVisit = 0
        bestCheckout = 0
        checkoutPercentage = 0
        recentForm = []
    }
}
