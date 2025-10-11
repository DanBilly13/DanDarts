//
//  User.swift
//  DanDart
//
//  User model for authenticated players
//

import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let displayName: String
    let nickname: String
    let handle: String?
    let avatarURL: String?
    let createdAt: Date
    let lastSeenAt: Date?
    
    // Stats properties (will be fetched separately from player_stats table)
    var totalWins: Int = 0
    var totalLosses: Int = 0
    
    // Coding keys to match Supabase column names
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case nickname
        case handle
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case lastSeenAt = "last_seen_at"
    }
    
    // Computed properties
    var gamesPlayed: Int {
        totalWins + totalLosses
    }
    
    var winRate: Double {
        guard gamesPlayed > 0 else { return 0.0 }
        return Double(totalWins) / Double(gamesPlayed)
    }
    
    var formattedWinRate: String {
        String(format: "%.1f%%", winRate * 100)
    }
    
    var displayHandle: String {
        handle ?? "@\(nickname)"
    }
}

// MARK: - Mock Data for Previews
extension User {
    static let mockUser1 = User(
        id: UUID(),
        displayName: "Dan Billingham",
        nickname: "danbilly",
        handle: "@thearrow",
        avatarURL: nil,
        createdAt: Date().addingTimeInterval(-86400 * 30), // 30 days ago
        lastSeenAt: Date().addingTimeInterval(-3600), // 1 hour ago
        totalWins: 15,
        totalLosses: 8
    )
    
    static let mockUser2 = User(
        id: UUID(),
        displayName: "Sarah Connor",
        nickname: "terminator",
        handle: nil,
        avatarURL: "https://example.com/avatar2.jpg",
        createdAt: Date().addingTimeInterval(-86400 * 60), // 60 days ago
        lastSeenAt: Date().addingTimeInterval(-1800), // 30 minutes ago
        totalWins: 22,
        totalLosses: 12
    )
    
    static let mockUser3 = User(
        id: UUID(),
        displayName: "Mike \"The Dart\" Johnson",
        nickname: "dartmaster",
        handle: "@180king",
        avatarURL: nil,
        createdAt: Date().addingTimeInterval(-86400 * 90), // 90 days ago
        lastSeenAt: Date().addingTimeInterval(-86400), // 1 day ago
        totalWins: 45,
        totalLosses: 23
    )
    
    static let mockUsers = [mockUser1, mockUser2, mockUser3]
}
