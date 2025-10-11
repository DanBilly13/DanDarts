//
//  Game.swift
//  DanDart
//
//  Game model for dart game types and configurations
//

import Foundation

// MARK: - GameType Enum

enum GameType: String, CaseIterable, Codable {
    case game301 = "301"
    case game501 = "501"
    case halveIt = "halve_it"
    case knockout = "knockout"
    case suddenDeath = "sudden_death"
    case cricket = "cricket"
    case killer = "killer"
    
    var displayName: String {
        switch self {
        case .game301:
            return "301"
        case .game501:
            return "501"
        case .halveIt:
            return "Halve-It"
        case .knockout:
            return "Knockout"
        case .suddenDeath:
            return "Sudden Death"
        case .cricket:
            return "English Cricket"
        case .killer:
            return "Killer"
        }
    }
}

// MARK: - Game Model

struct Game: Identifiable, Codable {
    let id: UUID
    let name: String
    let tagline: String
    let type: GameType
    let instructions: String
    let minPlayers: Int
    let maxPlayers: Int
    let difficulty: GameDifficulty
    
    init(
        id: UUID = UUID(),
        name: String,
        tagline: String,
        type: GameType,
        instructions: String,
        minPlayers: Int,
        maxPlayers: Int,
        difficulty: GameDifficulty
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.type = type
        self.instructions = instructions
        self.minPlayers = minPlayers
        self.maxPlayers = maxPlayers
        self.difficulty = difficulty
    }
}

// MARK: - Game Difficulty

enum GameDifficulty: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    
    var displayName: String {
        switch self {
        case .beginner:
            return "Beginner"
        case .intermediate:
            return "Intermediate"
        case .advanced:
            return "Advanced"
        }
    }
}

// MARK: - Mock Data

extension Game {
    static let mockGames: [Game] = [
        Game(
            name: "301",
            tagline: "A Classic Countdown Game",
            type: .game301,
            instructions: "Each player starts with a score of 301. Players take turns throwing three darts per round and subtract the total from their score. The goal is to reach exactly zero, finishing on a double. If a score goes below zero or ends on one, the turn is a bust and the score reverts to its previous total. The first player to reach exactly zero wins.",
            minPlayers: 2,
            maxPlayers: 8,
            difficulty: .beginner
        ),
        
        Game(
            name: "501",
            tagline: "The Professional Standard",
            type: .game501,
            instructions: "Players start with 501 points and take turns throwing three darts. Each turn's total is subtracted from the player's score. The objective is to reach exactly zero, with the final dart landing on a double. If a player scores below zero or one, they bust and return to their previous score. The first player to finish on zero wins. This is the format used in most professional darts tournaments.",
            minPlayers: 2,
            maxPlayers: 8,
            difficulty: .intermediate
        ),
        
        Game(
            name: "Halve-It",
            tagline: "Accuracy Under Pressure",
            type: .halveIt,
            instructions: "A popular darts game that can be played with a large group. Select six different targets on the dartboard, and each player takes turns trying to hit those targets. For every target hit, add that score to your total. If you fail to hit a target with three darts, you must halve your total score. The winner is the player with the highest score at the end of the game. Make the game easier or harder depending on your group.",
            minPlayers: 2,
            maxPlayers: 8,
            difficulty: .intermediate
        ),
        
        Game(
            name: "Knockout",
            tagline: "Beat the Previous Player or Lose a Life",
            type: .knockout,
            instructions: "Determine the throwing order by throwing one dart each at the bullseye — closest goes first. Before the game begins, decide how many lives each player gets. The first player throws three darts to set a score. The next player must beat that score, or they lose a life. Continue in order, with each player trying to outscore the last. The winner is the final player left with one or more lives remaining.",
            minPlayers: 2,
            maxPlayers: 8,
            difficulty: .beginner
        ),
        
        Game(
            name: "Sudden Death",
            tagline: "Fast and Ruthless Fun",
            type: .suddenDeath,
            instructions: "A quick and exciting game, perfect for groups. Each player throws three darts per round, and the player with the lowest total is eliminated. Play continues round by round until only one player remains. The last player standing wins.",
            minPlayers: 2,
            maxPlayers: 8,
            difficulty: .advanced
        ),
        
        Game(
            name: "English Cricket",
            tagline: "Bat and Bowl with Darts",
            type: .cricket,
            instructions: "English Cricket features a batter and a bowler, similar to traditional cricket. The game can be played one-on-one or with teams. The batting team aims to score as many points as possible by hitting the scoring numbers (15–20 and bullseye). The bowling team aims for the bullseye — an outer bullseye is worth one wicket, a bullseye two wickets. Once the bowling team reaches ten wickets, that marks the end of the batting team's innings. Then teams switch roles. The team with the highest score after both have batted wins.",
            minPlayers: 2,
            maxPlayers: 8,
            difficulty: .intermediate
        ),
        
        Game(
            name: "Killer",
            tagline: "Target Others, Protect Yourself",
            type: .killer,
            instructions: "To start, each player throws one dart to determine their number (1–20). No two players can share the same number. Players must first hit their own number's double to become a Killer. Once a Killer, hitting another player's number's double removes one of their lives. You can lose your own lives by accidentally hitting your number while attacking others. To regain lives, hit your own number again. The last player with one or more lives wins.",
            minPlayers: 2,
            maxPlayers: 8,
            difficulty: .advanced
        )
    ]
    
    // MARK: - Convenience Methods
    
    static func game(for type: GameType) -> Game? {
        return mockGames.first { $0.type == type }
    }
    
    static var beginnerGames: [Game] {
        return mockGames.filter { $0.difficulty == .beginner }
    }
    
    static var intermediateGames: [Game] {
        return mockGames.filter { $0.difficulty == .intermediate }
    }
    
    static var advancedGames: [Game] {
        return mockGames.filter { $0.difficulty == .advanced }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension Game {
    static let preview301 = mockGames[0]
    static let preview501 = mockGames[1]
    static let previewHalveIt = mockGames[2]
}
#endif
