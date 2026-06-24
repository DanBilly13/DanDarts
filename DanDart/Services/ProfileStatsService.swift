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
    
    // Freshness tracking (used by the gate in calculateStatsIfNeeded)
    private let cacheTTL: TimeInterval = 60
    private var lastCalculatedUserId: UUID?
    private var lastCalculatedAt: Date?
    private var isCalculating: Bool = false
    
    private var snapshotFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_stats.json")
    }
    
    private struct Snapshot: Codable {
        let userId: UUID
        let computedAt: Date
        let threeDartAverageHistory: [ThreeDartDataPoint]
        let avgDartsPerLeg: Double
        let avgDartsRank: RankTier
        let scoringDistribution: ScoringDistribution
        let highestVisit: Int
        let bestCheckout: Int
        let checkoutPercentage: Double
        let recentForm: [FormResult]
    }
    
    private init() {
        loadPersistedSnapshot()
    }
    
    // MARK: - Persistence
    
    /// Persist the currently computed stats to disk, scoped to the user.
    private func persistSnapshot(userId: UUID) {
        let snapshot = Snapshot(
            userId: userId,
            computedAt: Date(),
            threeDartAverageHistory: threeDartAverageHistory,
            avgDartsPerLeg: avgDartsPerLeg,
            avgDartsRank: avgDartsRank,
            scoringDistribution: scoringDistribution,
            highestVisit: highestVisit,
            bestCheckout: bestCheckout,
            checkoutPercentage: checkoutPercentage,
            recentForm: recentForm
        )
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(snapshot).write(to: snapshotFileURL)
        } catch {
            print("❌ [ProfileStatsService] Failed to persist snapshot: \(error)")
        }
    }
    
    /// Load a persisted snapshot on launch, but only adopt it if it belongs
    /// to the currently signed-in user (prevents showing another user's stats).
    private func loadPersistedSnapshot() {
        guard let data = try? Data(contentsOf: snapshotFileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(Snapshot.self, from: data) else { return }
        guard snapshot.userId == AuthService.shared.currentUser?.id else { return }
        
        threeDartAverageHistory = snapshot.threeDartAverageHistory
        avgDartsPerLeg = snapshot.avgDartsPerLeg
        avgDartsRank = snapshot.avgDartsRank
        scoringDistribution = snapshot.scoringDistribution
        highestVisit = snapshot.highestVisit
        bestCheckout = snapshot.bestCheckout
        checkoutPercentage = snapshot.checkoutPercentage
        recentForm = snapshot.recentForm
        lastCalculatedUserId = snapshot.userId
        lastCalculatedAt = snapshot.computedAt
    }
    
    /// Clear persisted + in-memory stats (e.g. on sign out / account switch).
    func clearPersistedStats() {
        try? FileManager.default.removeItem(at: snapshotFileURL)
        lastCalculatedUserId = nil
        lastCalculatedAt = nil
        resetStats()
    }
    
    /// Calculate stats only when needed: skips if the same user's stats were
    /// computed within `cacheTTL`. Pass `force: true` to bypass the gate
    /// (e.g. after a match completes).
    func calculateStatsIfNeeded(userId: UUID, force: Bool = false) async {
        if !force,
           lastCalculatedUserId == userId,
           let last = lastCalculatedAt,
           Date().timeIntervalSince(last) < cacheTTL {
            return
        }
        await calculateStats(userId: userId)
    }
    
    func calculateStats(userId: UUID) async {
        // Coalesce concurrent calls (e.g. .task firing alongside a notification).
        guard !isCalculating else { return }
        isCalculating = true
        defer { isCalculating = false }
        
        // Only show the loading state on a first-ever load (no data yet).
        // Subsequent refreshes update in place, silently.
        let showLoading = (lastCalculatedAt == nil)
        if showLoading { isLoading = true }
        defer { if showLoading { isLoading = false } }
        
        do {
            let countdownMatches = try await loadCountdownMatches(userId: userId)
            
            calculate3DartAverageHistory(matches: countdownMatches, userId: userId)
            calculateAvgDartsPerLeg(matches: countdownMatches, userId: userId)
            calculateScoringDistribution(matches: countdownMatches, userId: userId)
            calculatePersonalBests(matches: countdownMatches, userId: userId)
            calculateRecentForm(matches: countdownMatches, userId: userId)
            
            lastCalculatedUserId = userId
            lastCalculatedAt = Date()
            persistSnapshot(userId: userId)
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
        
        let matches = await withTaskGroup(of: MatchResult?.self) { group in
            for summary in countdownSummaries {
                group.addTask {
                    try? await self.matchHistoryService.loadFullDetail(matchId: summary.id)
                }
            }
            var results: [MatchResult] = []
            for await match in group {
                if let match { results.append(match) }
            }
            return results
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
        var totalTierScore = 0
        var rankedWinsCount = 0
        
        for match in winningMatches {
            guard let player = match.players.first(where: { $0.id == userId }) else { continue }
            totalDarts += player.totalDartsThrown
            totalLegs += match.totalLegsPlayed
            
            // Calculate rank for this specific winning match
            let dartsPerLegThisMatch = Double(player.totalDartsThrown) / Double(match.totalLegsPlayed)
            let rankTier = RankingHelper.rankForWinningDarts(game: match.gameType, dartsThrown: Int(dartsPerLegThisMatch))
            let tierScore = RankingHelper.tierScore(for: rankTier)
            
            totalTierScore += tierScore
            rankedWinsCount += 1
        }
        
        guard totalLegs > 0 else {
            avgDartsPerLeg = 0
            avgDartsRank = .unranked
            return
        }
        
        // Calculate average darts per leg for display
        avgDartsPerLeg = Double(totalDarts) / Double(totalLegs)
        
        // Calculate rank using same method as profile rank (average tier score approach)
        guard rankedWinsCount > 0 else {
            avgDartsRank = .unranked
            return
        }
        
        let averageTierScore = Double(totalTierScore) / Double(rankedWinsCount)
        avgDartsRank = RankingHelper.profileRankFromAverageTierScore(averageTierScore)
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
