//
//  MatchStorageManager.swift
//  DanDart
//
//  Manager for saving and loading match results to/from local JSON storage
//

import Foundation

@MainActor
class MatchStorageManager {
    static let shared = MatchStorageManager()
    
    private let fileManager = FileManager.default
    private let matchesFileName = "matches.json"
    private let playerStatsFileName = "player_stats.json"
    private let failedSyncsFileName = "failed_syncs.json"
    
    private let matchesService = MatchesService()
    
    private init() {
        // Ensure documents directory exists
        createDocumentsDirectoryIfNeeded()
    }
    
    // MARK: - File URLs
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var matchesFileURL: URL {
        documentsDirectory.appendingPathComponent(matchesFileName)
    }
    
    private var playerStatsFileURL: URL {
        documentsDirectory.appendingPathComponent(playerStatsFileName)
    }
    
    private var failedSyncsFileURL: URL {
        documentsDirectory.appendingPathComponent(failedSyncsFileName)
    }
    
    // MARK: - Directory Setup
    
    private func createDocumentsDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: documentsDirectory.path) {
            try? fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Match Storage
    
    /// Save a match result to local storage and sync to Supabase
    func saveMatch(_ match: MatchResult) {
        // 1. Save to local storage first
        var matches = loadMatches()
        matches.append(match)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(matches)
            try data.write(to: matchesFileURL)
            print("✅ Match saved locally: \(match.id)")
        } catch {
            print("❌ Error saving match locally: \(error.localizedDescription)")
            return
        }
        
        // Note: Sync is now handled by MatchService.saveMatch() in ViewModels
        // This provides better control over turn data and prevents duplicate syncs
        // Local storage is used as a backup for failed syncs
        if isMemberMatch(match) {
            print("ℹ️ Member match saved locally - sync handled by ViewModel")
        } else {
            print("ℹ️ Guest match - keeping in local storage only: \(match.id)")
        }
    }
    
    /// Load all matches from local storage
    func loadMatches() -> [MatchResult] {
        guard fileManager.fileExists(atPath: matchesFileURL.path) else {
            print("ℹ️ No matches file found, returning empty array")
            return []
        }
        
        do {
            let data = try Data(contentsOf: matchesFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let matches = try decoder.decode([MatchResult].self, from: data)
            print("✅ Loaded \(matches.count) matches")
            return matches
        } catch {
            print("❌ Error loading matches: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Load a specific match by ID
    func loadMatch(byId matchId: UUID) -> MatchResult? {
        let matches = loadMatches()
        return matches.first { $0.id == matchId }
    }
    
    /// Get matches for a specific game type
    func getMatches(forGameType gameType: String) -> [MatchResult] {
        return loadMatches().filter { $0.gameType == gameType }
    }
    
    /// Get recent matches (last N matches)
    func getRecentMatches(limit: Int = 10) -> [MatchResult] {
        let matches = loadMatches()
        return Array(matches.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }
    
    /// Delete a specific match
    func deleteMatch(withId id: UUID) {
        var matches = loadMatches()
        matches.removeAll { $0.id == id }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(matches)
            try data.write(to: matchesFileURL)
            print("✅ Match deleted successfully: \(id)")
        } catch {
            print("❌ Error deleting match: \(error.localizedDescription)")
        }
    }
    
    /// Delete all matches (use with caution!)
    func deleteAllMatches() {
        do {
            if fileManager.fileExists(atPath: matchesFileURL.path) {
                try fileManager.removeItem(at: matchesFileURL)
                print("✅ All matches deleted")
            }
        } catch {
            print("❌ Error deleting all matches: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if a match contains only member players (no guests)
    /// - Parameter match: The match to check
    /// - Returns: True if all players are members (have user IDs), false if any are guests
    private func isMemberMatch(_ match: MatchResult) -> Bool {
        // A match is a "member match" if ALL players are connected users (not guests)
        return match.players.allSatisfy { !$0.isGuest }
    }
    
    // MARK: - Player Stats Storage
    
    /// Update player stats after a match
    func updatePlayerStats(for players: [MatchPlayer], winnerId: UUID) {
        var stats = loadPlayerStats()
        
        for player in players {
            let playerId = player.id.uuidString
            var playerStat = stats[playerId] ?? PlayerStats(
                playerId: player.id,
                displayName: player.displayName,
                nickname: player.nickname,
                avatarURL: player.avatarURL,
                isGuest: player.isGuest
            )
            
            // Update stats
            playerStat.gamesPlayed += 1
            if player.id == winnerId {
                playerStat.wins += 1
            } else {
                playerStat.losses += 1
            }
            
            stats[playerId] = playerStat
        }
        
        savePlayerStats(stats)
    }
    
    /// Load player stats from local storage
    func loadPlayerStats() -> [String: PlayerStats] {
        guard fileManager.fileExists(atPath: playerStatsFileURL.path) else {
            print("ℹ️ No player stats file found, returning empty dictionary")
            return [:]
        }
        
        do {
            let data = try Data(contentsOf: playerStatsFileURL)
            let decoder = JSONDecoder()
            let stats = try decoder.decode([String: PlayerStats].self, from: data)
            print("✅ Loaded stats for \(stats.count) players")
            return stats
        } catch {
            print("❌ Error loading player stats: \(error.localizedDescription)")
            return [:]
        }
    }
    
    /// Save player stats to local storage
    private func savePlayerStats(_ stats: [String: PlayerStats]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(stats)
            try data.write(to: playerStatsFileURL)
            print("✅ Player stats saved successfully")
        } catch {
            print("❌ Error saving player stats: \(error.localizedDescription)")
        }
    }
    
    /// Get stats for a specific player
    func getPlayerStats(forPlayerId id: UUID) -> PlayerStats? {
        let stats = loadPlayerStats()
        return stats[id.uuidString]
    }
    
    /// Get all player stats sorted by wins
    func getAllPlayerStats() -> [PlayerStats] {
        let stats = loadPlayerStats()
        return Array(stats.values).sorted { $0.wins > $1.wins }
    }
    
    // MARK: - Failed Syncs Management
    
    /// Add a match to the failed syncs queue
    private func addToFailedSyncs(_ match: MatchResult) {
        var failedSyncs = loadFailedSyncs()
        
        // Avoid duplicates
        if !failedSyncs.contains(where: { $0.id == match.id }) {
            failedSyncs.append(match)
            saveFailedSyncs(failedSyncs)
        }
    }
    
    /// Load failed syncs from local storage
    private func loadFailedSyncs() -> [MatchResult] {
        guard fileManager.fileExists(atPath: failedSyncsFileURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: failedSyncsFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let matches = try decoder.decode([MatchResult].self, from: data)
            return matches
        } catch {
            print("❌ Error loading failed syncs: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Save failed syncs to local storage
    private func saveFailedSyncs(_ matches: [MatchResult]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(matches)
            try data.write(to: failedSyncsFileURL)
        } catch {
            print("❌ Error saving failed syncs: \(error.localizedDescription)")
        }
    }
    
    /// Retry syncing all failed matches
    func retryFailedSyncs() async -> Int {
        let failedMatches = loadFailedSyncs()
        guard !failedMatches.isEmpty else {
            print("ℹ️ No failed syncs to retry")
            return 0
        }
        
        print("🔄 Retrying \(failedMatches.count) failed syncs...")
        let successCount = await matchesService.retrySyncFailedMatches(failedMatches)
        
        // Remove successfully synced matches from failed queue
        if successCount > 0 {
            var remaining = failedMatches
            // This is simplified - in production you'd track which ones succeeded
            remaining.removeFirst(min(successCount, remaining.count))
            saveFailedSyncs(remaining)
        }
        
        print("✅ Successfully synced \(successCount)/\(failedMatches.count) matches")
        return successCount
    }
}

// MARK: - Player Stats Model

struct PlayerStats: Codable {
    let playerId: UUID
    let displayName: String
    let nickname: String
    let avatarURL: String?
    let isGuest: Bool
    var gamesPlayed: Int = 0
    var wins: Int = 0
    var losses: Int = 0
    
    var winRate: Double {
        guard gamesPlayed > 0 else { return 0.0 }
        return Double(wins) / Double(gamesPlayed)
    }
    
    var winRatePercentage: String {
        return String(format: "%.1f%%", winRate * 100)
    }
}

// MARK: - Testing Helper

extension MatchStorageManager {
    /// Add mock matches for testing (call this once to populate test data)
    func seedTestMatches() {
        // Create test players
        let player1 = MatchPlayer(
            id: UUID(),
            displayName: "Dan Billingham",
            nickname: "danbilly",
            avatarURL: "avatar1",
            isGuest: false,
            finalScore: 0,
            startingScore: 301,
            totalDartsThrown: 18,
            turns: []
        )
        
        let player2 = MatchPlayer(
            id: UUID(),
            displayName: "Bob Smith",
            nickname: "bobsmith",
            avatarURL: "avatar2",
            isGuest: false,
            finalScore: 45,
            startingScore: 301,
            totalDartsThrown: 18,
            turns: []
        )
        
        let player3 = MatchPlayer(
            id: UUID(),
            displayName: "Alice Jones",
            nickname: "alicej",
            avatarURL: "avatar3",
            isGuest: false,
            finalScore: 127,
            startingScore: 501,
            totalDartsThrown: 24,
            turns: []
        )
        
        // Create test matches with different dates
        let match1 = MatchResult(
            gameType: "301",
            gameName: "301",
            players: [player1, player2],
            winnerId: player1.id,
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            duration: 180
        )
        
        let match2 = MatchResult(
            gameType: "501",
            gameName: "501",
            players: [player1, player3],
            winnerId: player3.id,
            timestamp: Date().addingTimeInterval(-86400), // 1 day ago
            duration: 240
        )
        
        let match3 = MatchResult(
            gameType: "Cricket",
            gameName: "English Cricket",
            players: [player2, player3],
            winnerId: player2.id,
            timestamp: Date().addingTimeInterval(-172800), // 2 days ago
            duration: 300
        )
        
        let match4 = MatchResult(
            gameType: "301",
            gameName: "301",
            players: [player1, player2],
            winnerId: player2.id,
            timestamp: Date().addingTimeInterval(-259200), // 3 days ago
            duration: 150
        )
        
        // Save all test matches
        saveMatch(match1)
        saveMatch(match2)
        saveMatch(match3)
        saveMatch(match4)
        
        print("✅ Seeded 4 test matches")
    }
}
