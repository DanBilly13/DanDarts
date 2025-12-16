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
    
    // Custom decoder to handle missing legsWon field and isGuest as string (backwards compatibility)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        nickname = try container.decode(String.self, forKey: .nickname)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        
        // Handle isGuest as either Bool or String (for backwards compatibility)
        if let isGuestBool = try? container.decode(Bool.self, forKey: .isGuest) {
            isGuest = isGuestBool
        } else if let isGuestString = try? container.decode(String.self, forKey: .isGuest) {
            isGuest = (isGuestString.lowercased() == "true")
        } else {
            isGuest = false // Default to false if missing
        }
        
        // Handle optional fields that may be missing in minimal player data
        finalScore = try container.decodeIfPresent(Int.self, forKey: .finalScore) ?? 0
        startingScore = try container.decodeIfPresent(Int.self, forKey: .startingScore) ?? 0
        totalDartsThrown = try container.decodeIfPresent(Int.self, forKey: .totalDartsThrown) ?? 0
        turns = try container.decodeIfPresent([MatchTurn].self, forKey: .turns) ?? []
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
            id: player.userId ?? player.id, // Use userId for connected players, player.id for guests
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
    let killerMetadata: KillerDartMetadata? // Killer-specific data
    
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
    
    init(baseValue: Int, multiplier: Int, killerMetadata: KillerDartMetadata? = nil) {
        self.baseValue = baseValue
        self.multiplier = multiplier
        self.value = baseValue * multiplier
        self.killerMetadata = killerMetadata
    }
}

// MARK: - Killer Dart Metadata

struct KillerDartMetadata: Codable, Hashable {
    let outcome: KillerDartOutcome
    let affectedPlayerIds: [UUID] // Empty for miss, contains victim ID(s) for hits
    
    enum KillerDartOutcome: String, Codable {
        case becameKiller // Hit own double, became a killer
        case hitOwnNumber // Killer hit their own number (lost life)
        case hitOpponent // Killer hit opponent's number
        case miss // Didn't hit any relevant number
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
    
    static let mockSuddenDeath: MatchResult = {
        let player1Id = UUID()
        let player2Id = UUID()
        let player3Id = UUID()
        let player4Id = UUID()
        
        // Player 1 turns (Winner - 3 rounds)
        let player1Turns = [
            MatchTurn(
                turnNumber: 1,
                darts: [MatchDart(baseValue: 20, multiplier: 1), MatchDart(baseValue: 20, multiplier: 1), MatchDart(baseValue: 20, multiplier: 1)],
                scoreBefore: 0,
                scoreAfter: 60,
                isBust: false
            ),
            MatchTurn(
                turnNumber: 2,
                darts: [MatchDart(baseValue: 20, multiplier: 3), MatchDart(baseValue: 20, multiplier: 3), MatchDart(baseValue: 20, multiplier: 3)],
                scoreBefore: 60,
                scoreAfter: 240,
                isBust: false
            ),
            MatchTurn(
                turnNumber: 3,
                darts: [MatchDart(baseValue: 20, multiplier: 3), MatchDart(baseValue: 20, multiplier: 3), MatchDart(baseValue: 20, multiplier: 3)],
                scoreBefore: 240,
                scoreAfter: 420,
                isBust: false
            )
        ]
        
        // Player 2 turns (2nd place - eliminated round 3)
        let player2Turns = [
            MatchTurn(
                turnNumber: 1,
                darts: [MatchDart(baseValue: 20, multiplier: 3), MatchDart(baseValue: 19, multiplier: 1), MatchDart(baseValue: 18, multiplier: 1)],
                scoreBefore: 0,
                scoreAfter: 97,
                isBust: false
            ),
            MatchTurn(
                turnNumber: 2,
                darts: [MatchDart(baseValue: 20, multiplier: 3), MatchDart(baseValue: 20, multiplier: 1), MatchDart(baseValue: 17, multiplier: 1)],
                scoreBefore: 97,
                scoreAfter: 174,
                isBust: false
            ),
            MatchTurn(
                turnNumber: 3,
                darts: [MatchDart(baseValue: 15, multiplier: 1), MatchDart(baseValue: 10, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1)],
                scoreBefore: 174,
                scoreAfter: 204,
                isBust: true // Lost life and eliminated
            )
        ]
        
        // Player 3 turns (3rd place - eliminated round 2)
        let player3Turns = [
            MatchTurn(
                turnNumber: 1,
                darts: [MatchDart(baseValue: 19, multiplier: 3), MatchDart(baseValue: 18, multiplier: 1), MatchDart(baseValue: 17, multiplier: 1)],
                scoreBefore: 0,
                scoreAfter: 92,
                isBust: false
            ),
            MatchTurn(
                turnNumber: 2,
                darts: [MatchDart(baseValue: 10, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1), MatchDart(baseValue: 1, multiplier: 1)],
                scoreBefore: 92,
                scoreAfter: 108,
                isBust: true // Lost life and eliminated
            )
        ]
        
        // Player 4 turns (4th place - eliminated round 1)
        let player4Turns = [
            MatchTurn(
                turnNumber: 1,
                darts: [MatchDart(baseValue: 5, multiplier: 1), MatchDart(baseValue: 1, multiplier: 1), MatchDart(baseValue: 1, multiplier: 1)],
                scoreBefore: 0,
                scoreAfter: 7,
                isBust: true // Lost life and eliminated
            )
        ]
        
        return MatchResult(
            gameType: "sudden_death",
            gameName: "Sudden Death",
            players: [
                MatchPlayer(
                    id: player1Id,
                    displayName: "Daniel Billingham",
                    nickname: "dantheman",
                    avatarURL: "avatar1",
                    isGuest: false,
                    finalScore: 420,
                    startingScore: 0,
                    totalDartsThrown: 9,
                    turns: player1Turns
                ),
                MatchPlayer(
                    id: player2Id,
                    displayName: "Christina Billingham",
                    nickname: "legend",
                    avatarURL: "avatar2",
                    isGuest: false,
                    finalScore: 204,
                    startingScore: 0,
                    totalDartsThrown: 9,
                    turns: player2Turns
                ),
                MatchPlayer(
                    id: player3Id,
                    displayName: "Daniel Andersson",
                    nickname: "killerdan",
                    avatarURL: "avatar3",
                    isGuest: false,
                    finalScore: 108,
                    startingScore: 0,
                    totalDartsThrown: 6,
                    turns: player3Turns
                ),
                MatchPlayer(
                    id: player4Id,
                    displayName: "Guest Player",
                    nickname: "guest",
                    avatarURL: "avatar5",
                    isGuest: true,
                    finalScore: 7,
                    startingScore: 0,
                    totalDartsThrown: 3,
                    turns: player4Turns
                )
            ],
            winnerId: player1Id,
            timestamp: Date(),
            duration: 240,
            matchFormat: 1,
            totalLegsPlayed: 1,
            metadata: ["starting_lives": "1"]
        )
    }()
    
    // MARK: - Mock Knockout Match
    
    static let mockKnockout: MatchResult = {
        let player1Id = UUID()
        let player2Id = UUID()
        let player3Id = UUID()
        let player4Id = UUID()
        
        // Player 1 (Winner - Green) - Lost 0 lives
        let player1Turns = [
            MatchTurn(turnNumber: 1, darts: [MatchDart(baseValue: 20, multiplier: 3), MatchDart(baseValue: 20, multiplier: 3), MatchDart(baseValue: 20, multiplier: 3)], scoreBefore: 0, scoreAfter: 180, isBust: false),
            MatchTurn(turnNumber: 2, darts: [MatchDart(baseValue: 20, multiplier: 3), MatchDart(baseValue: 20, multiplier: 2), MatchDart(baseValue: 20, multiplier: 1)], scoreBefore: 0, scoreAfter: 120, isBust: false),
            MatchTurn(turnNumber: 3, darts: [MatchDart(baseValue: 20, multiplier: 3), MatchDart(baseValue: 20, multiplier: 3), MatchDart(baseValue: 15, multiplier: 1)], scoreBefore: 0, scoreAfter: 135, isBust: false)
        ]
        
        // Player 2 (2nd - Red) - Lost 1 life in round 1
        let player2Turns = [
            MatchTurn(turnNumber: 1, darts: [MatchDart(baseValue: 20, multiplier: 1), MatchDart(baseValue: 20, multiplier: 1), MatchDart(baseValue: 20, multiplier: 1)], scoreBefore: 0, scoreAfter: 60, isBust: true), // Lost life
            MatchTurn(turnNumber: 2, darts: [MatchDart(baseValue: 20, multiplier: 3), MatchDart(baseValue: 20, multiplier: 1), MatchDart(baseValue: 20, multiplier: 1)], scoreBefore: 0, scoreAfter: 100, isBust: false),
            MatchTurn(turnNumber: 3, darts: [MatchDart(baseValue: 20, multiplier: 3), MatchDart(baseValue: 20, multiplier: 2), MatchDart(baseValue: 5, multiplier: 1)], scoreBefore: 0, scoreAfter: 105, isBust: false)
        ]
        
        // Player 3 (3rd - Orange) - Lost 2 lives (rounds 1 and 2), eliminated after round 2
        let player3Turns = [
            MatchTurn(turnNumber: 1, darts: [MatchDart(baseValue: 15, multiplier: 1), MatchDart(baseValue: 15, multiplier: 1), MatchDart(baseValue: 10, multiplier: 1)], scoreBefore: 0, scoreAfter: 40, isBust: true), // Lost life
            MatchTurn(turnNumber: 2, darts: [MatchDart(baseValue: 20, multiplier: 1), MatchDart(baseValue: 15, multiplier: 1), MatchDart(baseValue: 10, multiplier: 1)], scoreBefore: 0, scoreAfter: 45, isBust: true) // Lost life, eliminated
        ]
        
        // Player 4 (4th - Blue) - Lost 2 lives (rounds 1 and 2), eliminated after round 2
        let player4Turns = [
            MatchTurn(turnNumber: 1, darts: [MatchDart(baseValue: 10, multiplier: 1), MatchDart(baseValue: 10, multiplier: 1), MatchDart(baseValue: 10, multiplier: 1)], scoreBefore: 0, scoreAfter: 30, isBust: true), // Lost life
            MatchTurn(turnNumber: 2, darts: [MatchDart(baseValue: 15, multiplier: 1), MatchDart(baseValue: 10, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1)], scoreBefore: 0, scoreAfter: 30, isBust: true) // Lost life, eliminated
        ]
        
        return MatchResult(
            id: UUID(),
            gameType: "Knockout",
            gameName: "Knockout",
            players: [
                MatchPlayer(id: player1Id, displayName: "Alice", nickname: "@alice", avatarURL: nil, isGuest: true, finalScore: 2, startingScore: 2, totalDartsThrown: 0, turns: player1Turns, legsWon: 0),
                MatchPlayer(id: player2Id, displayName: "Bob", nickname: "@bob", avatarURL: nil, isGuest: true, finalScore: 1, startingScore: 2, totalDartsThrown: 0, turns: player2Turns, legsWon: 0),
                MatchPlayer(id: player3Id, displayName: "Charlie", nickname: "@charlie", avatarURL: nil, isGuest: true, finalScore: 0, startingScore: 2, totalDartsThrown: 0, turns: player3Turns, legsWon: 0),
                MatchPlayer(id: player4Id, displayName: "Diana", nickname: "@diana", avatarURL: nil, isGuest: true, finalScore: 0, startingScore: 2, totalDartsThrown: 0, turns: player4Turns, legsWon: 0)
            ],
            winnerId: player1Id,
            timestamp: Date(),
            duration: 180,
            matchFormat: 1,
            totalLegsPlayed: 1,
            metadata: ["starting_lives": "2"]
        )
    }()
    
    // MARK: - Mock Killer Match
    
    static let mockKiller: MatchResult = {
        let player1Id = UUID()
        let player2Id = UUID()
        let player3Id = UUID()
        
        // Player 1 (Winner) - Number 4
        let player1Turns = [
            // Round 1: Hit D4 (became killer), hit opponent's 12, miss
            MatchTurn(turnNumber: 1, darts: [
                MatchDart(baseValue: 4, multiplier: 2, killerMetadata: KillerDartMetadata(outcome: .becameKiller, affectedPlayerIds: [])),
                MatchDart(baseValue: 12, multiplier: 1, killerMetadata: KillerDartMetadata(outcome: .hitOpponent, affectedPlayerIds: [player2Id])),
                MatchDart(baseValue: 20, multiplier: 1, killerMetadata: KillerDartMetadata(outcome: .miss, affectedPlayerIds: []))
            ], scoreBefore: 0, scoreAfter: 0, isBust: false),
            // Round 2: Hit opponent's 12 with triple (3 lives), miss, miss
            MatchTurn(turnNumber: 2, darts: [
                MatchDart(baseValue: 12, multiplier: 3, killerMetadata: KillerDartMetadata(outcome: .hitOpponent, affectedPlayerIds: [player2Id, player2Id, player2Id])),
                MatchDart(baseValue: 20, multiplier: 1, killerMetadata: KillerDartMetadata(outcome: .miss, affectedPlayerIds: [])),
                MatchDart(baseValue: 19, multiplier: 1, killerMetadata: KillerDartMetadata(outcome: .miss, affectedPlayerIds: []))
            ], scoreBefore: 0, scoreAfter: 0, isBust: false)
        ]
        
        // Player 2 (2nd) - Number 12 - Lost all lives
        let player2Turns = [
            // Round 1: Hit D12 (became killer), miss, miss
            MatchTurn(turnNumber: 1, darts: [
                MatchDart(baseValue: 12, multiplier: 2, killerMetadata: KillerDartMetadata(outcome: .becameKiller, affectedPlayerIds: [])),
                MatchDart(baseValue: 20, multiplier: 1, killerMetadata: KillerDartMetadata(outcome: .miss, affectedPlayerIds: [])),
                MatchDart(baseValue: 18, multiplier: 1, killerMetadata: KillerDartMetadata(outcome: .miss, affectedPlayerIds: []))
            ], scoreBefore: 0, scoreAfter: 0, isBust: false)
            // Eliminated after round 1 (lost 4 lives total from player1's throws)
        ]
        
        // Player 3 (3rd) - Number 7 - Never became killer
        let player3Turns = [
            // Round 1: All misses
            MatchTurn(turnNumber: 1, darts: [
                MatchDart(baseValue: 20, multiplier: 1, killerMetadata: KillerDartMetadata(outcome: .miss, affectedPlayerIds: [])),
                MatchDart(baseValue: 19, multiplier: 1, killerMetadata: KillerDartMetadata(outcome: .miss, affectedPlayerIds: [])),
                MatchDart(baseValue: 18, multiplier: 1, killerMetadata: KillerDartMetadata(outcome: .miss, affectedPlayerIds: []))
            ], scoreBefore: 0, scoreAfter: 0, isBust: false),
            // Round 2: Hit D7 (became killer), hit own number (lost life), miss
            MatchTurn(turnNumber: 2, darts: [
                MatchDart(baseValue: 7, multiplier: 2, killerMetadata: KillerDartMetadata(outcome: .becameKiller, affectedPlayerIds: [])),
                MatchDart(baseValue: 7, multiplier: 1, killerMetadata: KillerDartMetadata(outcome: .hitOwnNumber, affectedPlayerIds: [player3Id])),
                MatchDart(baseValue: 20, multiplier: 1, killerMetadata: KillerDartMetadata(outcome: .miss, affectedPlayerIds: []))
            ], scoreBefore: 0, scoreAfter: 0, isBust: false)
        ]
        
        // Create metadata
        var metadata: [String: String] = [
            "starting_lives": "3",
            "player_\(player1Id.uuidString)": "4",
            "player_\(player2Id.uuidString)": "12",
            "player_\(player3Id.uuidString)": "7"
        ]
        
        return MatchResult(
            id: UUID(),
            gameType: "Killer",
            gameName: "Killer",
            players: [
                MatchPlayer(id: player1Id, displayName: "Dan Billingham", nickname: "@danbilly", avatarURL: "avatar1", isGuest: false, finalScore: 0, startingScore: 0, totalDartsThrown: 6, turns: player1Turns, legsWon: 0),
                MatchPlayer(id: player2Id, displayName: "Alice", nickname: "@alice", avatarURL: "avatar2", isGuest: true, finalScore: 0, startingScore: 0, totalDartsThrown: 3, turns: player2Turns, legsWon: 0),
                MatchPlayer(id: player3Id, displayName: "Bob", nickname: "@bob", avatarURL: "avatar3", isGuest: true, finalScore: 0, startingScore: 0, totalDartsThrown: 6, turns: player3Turns, legsWon: 0)
            ],
            winnerId: player1Id,
            timestamp: Date(),
            duration: 180,
            matchFormat: 1,
            totalLegsPlayed: 1,
            metadata: metadata
        )
    }()
}

