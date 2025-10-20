//
//  MatchResult.swift
//  DanDart
//
//  Model for storing completed match data locally
//

import Foundation

// MARK: - Match Result Model

struct MatchResult: Identifiable, Codable {
    let id: UUID
    let gameType: String // e.g., "301", "501", "Cricket"
    let gameName: String // Full game name for display
    let players: [MatchPlayer]
    let winnerId: UUID
    let timestamp: Date
    let duration: TimeInterval // in seconds
    
    // Computed properties
    var winner: MatchPlayer? {
        players.first { $0.id == winnerId }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    init(id: UUID = UUID(),
         gameType: String,
         gameName: String,
         players: [MatchPlayer],
         winnerId: UUID,
         timestamp: Date = Date(),
         duration: TimeInterval) {
        self.id = id
        self.gameType = gameType
        self.gameName = gameName
        self.players = players
        self.winnerId = winnerId
        self.timestamp = timestamp
        self.duration = duration
    }
}

// MARK: - Match Player Model

struct MatchPlayer: Identifiable, Codable {
    let id: UUID
    let displayName: String
    let nickname: String
    let avatarURL: String?
    let isGuest: Bool
    let finalScore: Int
    let startingScore: Int
    let totalDartsThrown: Int
    let turns: [MatchTurn]
    
    // Computed properties
    var averageScore: Double {
        guard totalDartsThrown > 0 else { return 0.0 }
        let totalScored = startingScore - finalScore
        return Double(totalScored) / Double(totalDartsThrown) * 3 // Average per 3 darts
    }
    
    var formattedAverage: String {
        return String(format: "%.1f", averageScore)
    }
    
    init(id: UUID,
         displayName: String,
         nickname: String,
         avatarURL: String?,
         isGuest: Bool,
         finalScore: Int,
         startingScore: Int,
         totalDartsThrown: Int,
         turns: [MatchTurn]) {
        self.id = id
        self.displayName = displayName
        self.nickname = nickname
        self.avatarURL = avatarURL
        self.isGuest = isGuest
        self.finalScore = finalScore
        self.startingScore = startingScore
        self.totalDartsThrown = totalDartsThrown
        self.turns = turns
    }
    
    /// Create MatchPlayer from Player with game data
    static func from(player: Player,
                    finalScore: Int,
                    startingScore: Int,
                    totalDartsThrown: Int,
                    turns: [MatchTurn]) -> MatchPlayer {
        return MatchPlayer(
            id: player.id,
            displayName: player.displayName,
            nickname: player.nickname,
            avatarURL: player.avatarURL,
            isGuest: player.isGuest,
            finalScore: finalScore,
            startingScore: startingScore,
            totalDartsThrown: totalDartsThrown,
            turns: turns
        )
    }
}

// MARK: - Match Turn Model

struct MatchTurn: Identifiable, Codable {
    let id: UUID
    let turnNumber: Int
    let darts: [MatchDart]
    let scoreBefore: Int
    let scoreAfter: Int
    let isBust: Bool
    
    var turnTotal: Int {
        darts.reduce(0) { $0 + $1.value }
    }
    
    init(id: UUID = UUID(),
         turnNumber: Int,
         darts: [MatchDart],
         scoreBefore: Int,
         scoreAfter: Int,
         isBust: Bool) {
        self.id = id
        self.turnNumber = turnNumber
        self.darts = darts
        self.scoreBefore = scoreBefore
        self.scoreAfter = scoreAfter
        self.isBust = isBust
    }
}

// MARK: - Match Dart Model

struct MatchDart: Codable {
    let baseValue: Int
    let multiplier: Int // 1=single, 2=double, 3=triple
    let value: Int // total value (baseValue * multiplier)
    
    var displayText: String {
        if multiplier == 1 {
            return "\(value)"
        } else if multiplier == 2 {
            return "D\(baseValue)"
        } else if multiplier == 3 {
            return "T\(baseValue)"
        }
        return "\(value)"
    }
    
    init(baseValue: Int, multiplier: Int) {
        self.baseValue = baseValue
        self.multiplier = multiplier
        self.value = baseValue * multiplier
    }
}

// MARK: - Mock Data

extension MatchResult {
    static let mock301: MatchResult = {
        let winnerId = UUID()
        let loserId = UUID()
        
        return MatchResult(
            gameType: "301",
            gameName: "301",
            players: [
                MatchPlayer(
                    id: winnerId,
                    displayName: "Dan Billingham",
                    nickname: "danbilly",
                    avatarURL: "avatar1",
                    isGuest: false,
                    finalScore: 0, // Winner - finished the game
                    startingScore: 301,
                    totalDartsThrown: 18,
                    turns: []
                ),
                MatchPlayer(
                    id: loserId,
                    displayName: "Diana Prince",
                    nickname: "wonderwoman",
                    avatarURL: "avatar4",
                    isGuest: false,
                    finalScore: 45, // Loser - 45 points remaining
                    startingScore: 301,
                    totalDartsThrown: 18,
                    turns: []
                )
            ],
            winnerId: winnerId, // Set to first player's ID
            timestamp: Date(),
            duration: 180
        )
    }()
}
