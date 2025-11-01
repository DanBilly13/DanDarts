//
//  MatchResult.swift
//  DanDart
//
//  Model for storing completed match data locally
//

import Foundation

// MARK: - Match Result Model

struct MatchResult: Identifiable, Codable, Hashable {
    let id: UUID
    let gameType: String // e.g., "301", "501", "Cricket"
    let gameName: String // Full game name for display
    let players: [MatchPlayer]
    let winnerId: UUID
    let timestamp: Date
    let duration: TimeInterval // in seconds
    let matchFormat: Int // Total legs in match (1, 3, 5, or 7)
    let totalLegsPlayed: Int // Actual number of legs played
    let metadata: [String: String]? // Game-specific metadata (e.g., Halve-It difficulty)
    
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
         duration: TimeInterval,
         matchFormat: Int = 1,
         totalLegsPlayed: Int = 1,
         metadata: [String: String]? = nil) {
        self.id = id
        self.gameType = gameType
        self.gameName = gameName
        self.players = players
        self.winnerId = winnerId
        self.timestamp = timestamp
        self.duration = duration
        self.matchFormat = matchFormat
        self.totalLegsPlayed = totalLegsPlayed
        self.metadata = metadata
    }
    
    // Custom Hashable implementation (only hash stored properties)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(gameType)
        hasher.combine(gameName)
        hasher.combine(players)
        hasher.combine(winnerId)
        hasher.combine(timestamp)
        hasher.combine(duration)
        hasher.combine(matchFormat)
        hasher.combine(totalLegsPlayed)
        hasher.combine(metadata?.keys.sorted())
        hasher.combine(metadata?.values.sorted())
    }
    
    // Custom Equatable implementation
    static func == (lhs: MatchResult, rhs: MatchResult) -> Bool {
        lhs.id == rhs.id &&
        lhs.gameType == rhs.gameType &&
        lhs.gameName == rhs.gameName &&
        lhs.players == rhs.players &&
        lhs.winnerId == rhs.winnerId &&
        lhs.timestamp == rhs.timestamp &&
        lhs.duration == rhs.duration &&
        lhs.matchFormat == rhs.matchFormat &&
        lhs.totalLegsPlayed == rhs.totalLegsPlayed &&
        lhs.metadata == rhs.metadata
    }
}

// MARK: - Match Player Model

struct MatchPlayer: Identifiable, Codable, Hashable {
    let id: UUID
    let displayName: String
    let nickname: String
    let avatarURL: String?
    let isGuest: Bool
    let finalScore: Int
    let startingScore: Int
    let totalDartsThrown: Int
    let turns: [MatchTurn]
    let legsWon: Int // Number of legs won in multi-leg match
    
    // Coding keys for snake_case conversion
    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case nickname
        case avatarURL
        case isGuest
        case finalScore
        case startingScore
        case totalDartsThrown
        case turns
        case legsWon
    }
    
    // Custom decoder to handle missing legsWon field (backwards compatibility)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        nickname = try container.decode(String.self, forKey: .nickname)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        isGuest = try container.decode(Bool.self, forKey: .isGuest)
        finalScore = try container.decode(Int.self, forKey: .finalScore)
        startingScore = try container.decode(Int.self, forKey: .startingScore)
        totalDartsThrown = try container.decode(Int.self, forKey: .totalDartsThrown)
        turns = try container.decode([MatchTurn].self, forKey: .turns)
        // Default to 0 if legsWon is missing (for old matches)
        legsWon = try container.decodeIfPresent(Int.self, forKey: .legsWon) ?? 0
    }
    
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
         turns: [MatchTurn],
         legsWon: Int = 0) {
        self.id = id
        self.displayName = displayName
        self.nickname = nickname
        self.avatarURL = avatarURL
        self.isGuest = isGuest
        self.finalScore = finalScore
        self.startingScore = startingScore
        self.totalDartsThrown = totalDartsThrown
        self.turns = turns
        self.legsWon = legsWon
    }
    
    /// Create MatchPlayer from Player with game data
    static func from(player: Player,
                    finalScore: Int,
                    startingScore: Int,
                    totalDartsThrown: Int,
                    turns: [MatchTurn],
                    legsWon: Int = 0) -> MatchPlayer {
        return MatchPlayer(
            id: player.id,
            displayName: player.displayName,
            nickname: player.nickname,
            avatarURL: player.avatarURL,
            isGuest: player.isGuest,
            finalScore: finalScore,
            startingScore: startingScore,
            totalDartsThrown: totalDartsThrown,
            turns: turns,
            legsWon: legsWon
        )
    }
}

// MARK: - Match Turn Model

struct MatchTurn: Identifiable, Codable, Hashable {
    let id: UUID
    let turnNumber: Int
    let darts: [MatchDart]
    let scoreBefore: Int
    let scoreAfter: Int
    let isBust: Bool
    let targetDisplay: String? // For Halve-It: "15", "D20", "BULL", etc.
    
    var turnTotal: Int {
        darts.reduce(0) { $0 + $1.value }
    }
    
    // Custom decoder for backwards compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        turnNumber = try container.decode(Int.self, forKey: .turnNumber)
        darts = try container.decode([MatchDart].self, forKey: .darts)
        scoreBefore = try container.decode(Int.self, forKey: .scoreBefore)
        scoreAfter = try container.decode(Int.self, forKey: .scoreAfter)
        isBust = try container.decode(Bool.self, forKey: .isBust)
        // Default to nil if targetDisplay is missing (for old matches and non-Halve-It games)
        targetDisplay = try container.decodeIfPresent(String.self, forKey: .targetDisplay)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, turnNumber, darts, scoreBefore, scoreAfter, isBust, targetDisplay
    }
    
    init(id: UUID = UUID(),
         turnNumber: Int,
         darts: [MatchDart],
         scoreBefore: Int,
         scoreAfter: Int,
         isBust: Bool,
         targetDisplay: String? = nil) {
        self.id = id
        self.turnNumber = turnNumber
        self.darts = darts
        self.scoreBefore = scoreBefore
        self.scoreAfter = scoreAfter
        self.isBust = isBust
        self.targetDisplay = targetDisplay
    }
}

// MARK: - Match Dart Model

struct MatchDart: Codable, Hashable {
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
