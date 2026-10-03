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
    /// Solo practice sessions, kept out of everything above (they are not a win or a loss).
    @Published var practice: ThrowingStats = .empty
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
        /// Optional so snapshots written before Practice Sessions existed still decode.
        let practice: ThrowingStats?
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
            recentForm: recentForm,
            practice: practice
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
        practice = snapshot.practice ?? .empty
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
            
            // Real matches (2+ players, Guests included) feed the main widgets and
            // Recent Form. Solo practice is computed on its own.
            let (realMatches, practiceMatches) = ProfileStatsCalculator.partition(countdownMatches)
            let main = ProfileStatsCalculator.throwingStats(matches: realMatches, userId: userId)
            
            threeDartAverageHistory = main.threeDartAverageHistory
            avgDartsPerLeg = main.avgDartsPerLeg
            avgDartsRank = main.avgDartsRank
            scoringDistribution = main.scoringDistribution
            highestVisit = main.highestVisit
            bestCheckout = main.bestCheckout
            checkoutPercentage = main.checkoutPercentage
            recentForm = ProfileStatsCalculator.recentForm(matches: realMatches, userId: userId)
            practice = ProfileStatsCalculator.throwingStats(matches: practiceMatches, userId: userId)
            
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
    
    private func resetStats() {
        threeDartAverageHistory = []
        avgDartsPerLeg = 0
        avgDartsRank = .unranked
        scoringDistribution = .empty
        highestVisit = 0
        bestCheckout = 0
        checkoutPercentage = 0
        recentForm = []
        practice = .empty
    }
}
