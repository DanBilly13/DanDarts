//
//  User.swift
//  DanDart
//
//  User model for authenticated players
//

import Foundation

/// Authentication provider type
enum AuthProvider: String, Codable {
    case email = "email"
    case google = "google"
}

struct User: Codable, Identifiable {
    let id: UUID
    var displayName: String
    var nickname: String
    var email: String?
    var handle: String?
    var avatarURL: String?
    var authProvider: AuthProvider?
    let createdAt: Date
    var lastSeenAt: Date?
    
    // Stats properties (will be fetched separately from player_stats table)
    var totalWins: Int = 0
    var totalLosses: Int = 0
    
    // Coding keys to match Supabase column names
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case nickname
        case email
        case handle
        case avatarURL = "avatar_url"
        case authProvider = "auth_provider"
        case createdAt = "created_at"
        case lastSeenAt = "last_seen_at"
        case totalWins = "total_wins"
        case totalLosses = "total_losses"
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
    
    /// Convert User to Player for use in components that expect Player type
    func toPlayer() -> Player {
        return Player(
            id: UUID(), // Generate new player ID (different from user ID)
            displayName: displayName,
            nickname: nickname,
            avatarURL: avatarURL,
            isGuest: false,
            totalWins: totalWins,
            totalLosses: totalLosses,
            userId: id // Link to user account for stats tracking
        )
    }
}

// MARK: - Mock Data for Previews
extension User {
    static let mockUser1 = User(
        id: UUID(),
        displayName: "Dan Billingham",
        nickname: "danbilly",
        email: "dan@example.com",
        handle: "@thearrow",
        avatarURL: "avatar1",
        authProvider: .email,
        createdAt: Date().addingTimeInterval(-86400 * 30), // 30 days ago
        lastSeenAt: Date().addingTimeInterval(-3600), // 1 hour ago
        totalWins: 15,
        totalLosses: 8
    )
    
    static let mockUser2 = User(
        id: UUID(),
        displayName: "Sarah Connor",
        nickname: "terminator",
        email: "sarah@gmail.com",
        handle: nil,
        avatarURL: "avatar2",
        authProvider: .google,
        createdAt: Date().addingTimeInterval(-86400 * 60), // 60 days ago
        lastSeenAt: Date().addingTimeInterval(-1800), // 30 minutes ago
        totalWins: 22,
        totalLosses: 12
    )
    
    static let mockUser3 = User(
        id: UUID(),
        displayName: "Mike \"The Dart\" Johnson",
        nickname: "dartmaster",
        email: "mike@example.com",
        handle: "@180king",
        avatarURL: "avatar3",
        authProvider: .email,
        createdAt: Date().addingTimeInterval(-86400 * 90), // 90 days ago
        lastSeenAt: Date().addingTimeInterval(-86400), // 1 day ago
        totalWins: 45,
        totalLosses: 23
    )
    
    static let mockUsers = [mockUser1, mockUser2, mockUser3]
}
