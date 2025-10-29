//
//  Player.swift
//  DanDart
//
//  Player model for game participants (guests and connected users)
//

import Foundation

// MARK: - Player Model

struct Player: Identifiable, Codable {
    let id: UUID
    let displayName: String
    let nickname: String
    let avatarURL: String?
    let isGuest: Bool
    let totalWins: Int
    let totalLosses: Int
    let userId: UUID? // User ID for connected players (nil for guests)
    
    // Computed properties
    var totalGames: Int {
        totalWins + totalLosses
    }
    
    var winRate: Double {
        guard totalGames > 0 else { return 0.0 }
        return Double(totalWins) / Double(totalGames)
    }
    
    var winRatePercentage: String {
        return String(format: "%.1f%%", winRate * 100)
    }
    
    // Initializer for creating new players
    init(id: UUID = UUID(), displayName: String, nickname: String, avatarURL: String? = nil, isGuest: Bool = true, totalWins: Int = 0, totalLosses: Int = 0, userId: UUID? = nil) {
        self.id = id
        self.displayName = displayName
        self.nickname = nickname
        self.avatarURL = avatarURL
        self.isGuest = isGuest
        self.totalWins = totalWins
        self.totalLosses = totalLosses
        self.userId = userId
    }
}

// MARK: - Player Extensions

extension Player {
    /// Create a guest player with just a display name
    static func createGuest(displayName: String, nickname: String? = nil, avatarURL: String? = nil) -> Player {
        let finalNickname = nickname ?? displayName.lowercased().replacingOccurrences(of: " ", with: "")
        return Player(
            displayName: displayName,
            nickname: finalNickname,
            avatarURL: avatarURL, // Only use provided avatarURL, don't auto-assign
            isGuest: true
        )
    }
    
    /// Create a guest player with specific avatar
    static func createGuestWithAvatar(displayName: String, nickname: String, avatarURL: String) -> Player {
        return Player(
            displayName: displayName,
            nickname: nickname,
            avatarURL: avatarURL,
            isGuest: true
        )
    }
    
    /// Create a connected player (from User model)
    /// Note: Temporarily commented out to avoid circular dependency
    /*
    static func fromUser(_ user: User) -> Player {
        return Player(
            id: UUID(), // Generate new UUID for Player (different from User.id)
            displayName: user.displayName,
            nickname: user.nickname,
            avatarURL: user.avatarURL,
            isGuest: false,
            totalWins: user.totalWins,
            totalLosses: user.totalLosses
        )
    }
    */
    
    /// Update player stats after a game
    func withUpdatedStats(won: Bool) -> Player {
        return Player(
            id: self.id,
            displayName: self.displayName,
            nickname: self.nickname,
            avatarURL: self.avatarURL,
            isGuest: self.isGuest,
            totalWins: won ? self.totalWins + 1 : self.totalWins,
            totalLosses: won ? self.totalLosses : self.totalLosses + 1
        )
    }
}

// MARK: - Mock Data

extension Player {
    /// Mock guest players for testing
    static let mockGuest1 = Player(
        displayName: "Alice Wonderland",
        nickname: "alice",
        avatarURL: "avatar1",
        isGuest: true,
        totalWins: 15,
        totalLosses: 8
    )
    
    static let mockGuest2 = Player(
        displayName: "Bob Westwood",
        nickname: "bob",
        avatarURL: "avatar2",
        isGuest: true,
        totalWins: 12,
        totalLosses: 11
    )
    
    static let mockGuest3 = Player(
        displayName: "Charlie Baker",
        nickname: "charlie",
        avatarURL: "avatar3",
        isGuest: true,
        totalWins: 0,
        totalLosses: 0
    )
    
    /// Mock connected players for testing
    static let mockConnected1 = Player(
        displayName: "Diana Prince",
        nickname: "wonderwoman",
        avatarURL: "avatar4",
        isGuest: false,
        totalWins: 28,
        totalLosses: 15
    )
    
    static let mockConnected2 = Player(
        displayName: "Bruce Wayne",
        nickname: "batman",
        avatarURL: "avatar1",
        isGuest: false,
        totalWins: 35,
        totalLosses: 12
    )
    
    static let mockConnected3 = Player(
        displayName: "Clark Kent",
        nickname: "superman",
        avatarURL: "avatar2",
        isGuest: false,
        totalWins: 42,
        totalLosses: 8
    )
    
    /// Array of all mock players for testing
    static let mockPlayers: [Player] = [
        mockGuest1,
        mockGuest2,
        mockGuest3,
        mockConnected1,
        mockConnected2,
        mockConnected3
    ]
    
    /// Array of mock guest players only
    static let mockGuestPlayers: [Player] = [
        mockGuest1,
        mockGuest2,
        mockGuest3
    ]
    
    /// Array of mock connected players only
    static let mockConnectedPlayers: [Player] = [
        mockConnected1,
        mockConnected2,
        mockConnected3
    ]
}

// MARK: - Player Hashable Conformance

extension Player: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(displayName)
        hasher.combine(nickname)
        hasher.combine(isGuest)
    }
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        return lhs.id == rhs.id &&
               lhs.displayName == rhs.displayName &&
               lhs.nickname == rhs.nickname &&
               lhs.isGuest == rhs.isGuest
    }
}
