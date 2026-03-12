//
//  H2HDebugData.swift
//  DanDart
//
//  Debug data structures for head-to-head match inspection
//

import Foundation

#if DEBUG

// MARK: - Main Debug Data Container

struct H2HDebugData {
    // Player stats
    var currentUserWins: Int
    var currentUserLosses: Int
    var friendWins: Int
    var friendLosses: Int
    
    // H2H summary shown by app
    var displayedCurrentUserWins: Int
    var displayedFriendWins: Int
    var displayedTotalMatches: Int
    
    // Raw match details
    var allMatchDetails: [MatchDebugDetail]
    
    // Category splits
    var local301Only: CategoryStats
    var remote301Only: CategoryStats
    var combined301: CategoryStats
    
    // Excluded matches
    var excludedMatches: [ExcludedMatchDetail]
}

// MARK: - Match Debug Detail

struct MatchDebugDetail: Identifiable {
    var id: UUID { matchId }
    var matchId: UUID
    var createdAt: Date?
    var gameType: String
    var gameName: String
    var matchMode: String?
    var remoteStatus: String?
    var winnerId: UUID?
    var duration: Int?
    var participantIds: [UUID]
    var participantNames: [String]
    var source: DataSource
    var includedInH2H: Bool
    var exclusionReason: String?
    
    var formattedCreatedAt: String {
        guard let date = createdAt else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Category Stats

struct CategoryStats {
    var currentUserWins: Int
    var friendWins: Int
    var totalMatches: Int
    var matchIds: [UUID]
    
    static var empty: CategoryStats {
        CategoryStats(currentUserWins: 0, friendWins: 0, totalMatches: 0, matchIds: [])
    }
}

// MARK: - Excluded Match Detail

struct ExcludedMatchDetail: Identifiable {
    var id: UUID { matchId }
    var matchId: UUID
    var reason: String
    var gameType: String?
    var gameName: String?
    var createdAt: Date?
    var source: DataSource
    
    var formattedCreatedAt: String {
        guard let date = createdAt else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Data Source Enum

enum DataSource: String {
    case local = "Local"
    case supabase = "Supabase"
    case merged = "Merged"
}

#endif
