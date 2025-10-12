//
//  Game.swift
//  DanDart
//
//  Game model for dart game types and configurations
//

import Foundation

// MARK: - Game Model

struct Game: Identifiable, Codable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let players: String
    let instructions: String
    
    // Computed properties for backwards compatibility
    var name: String { title }
    var tagline: String { subtitle }
    
    // Custom coding keys to exclude id from JSON decoding
    private enum CodingKeys: String, CodingKey {
        case title, subtitle, players, instructions
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(players)
        hasher.combine(instructions)
    }
    
    // Equatable conformance (required for Hashable)
    static func == (lhs: Game, rhs: Game) -> Bool {
        return lhs.title == rhs.title &&
               lhs.subtitle == rhs.subtitle &&
               lhs.players == rhs.players &&
               lhs.instructions == rhs.instructions
    }
}

// MARK: - Game Loading

extension Game {
    static func loadGames() -> [Game] {
        guard let url = Bundle.main.url(forResource: "darts_games", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let games = try? JSONDecoder().decode([Game].self, from: data) else {
            print("Failed to load games from JSON, using fallback data")
            return fallbackGames
        }
        return games
    }
    
    // Fallback games in case JSON loading fails
    private static let fallbackGames: [Game] = [
        Game(
            title: "301",
            subtitle: "A Classic Countdown Game",
            players: "2 or more",
            instructions: "Each player starts with a score of 301. Players take turns throwing three darts per round and subtract the total from their score. The goal is to reach exactly zero, finishing on a double."
        ),
        Game(
            title: "501",
            subtitle: "The Professional Standard",
            players: "2 or more",
            instructions: "Players start with 501 points and take turns throwing three darts. The objective is to reach exactly zero, with the final dart landing on a double."
        ),
        Game(
            title: "Halve-It",
            subtitle: "Accuracy Under Pressure",
            players: "2 or more",
            instructions: "Select six different targets on the dartboard. For every target hit, add that score to your total. If you fail to hit a target with three darts, you must halve your total score."
        ),
        Game(
            title: "Knockout",
            subtitle: "Beat the Previous Player or Lose a Life",
            players: "2 or more",
            instructions: "The first player throws three darts to set a score. The next player must beat that score, or they lose a life. The winner is the final player left with one or more lives remaining."
        ),
        Game(
            title: "Sudden Death",
            subtitle: "Fast and Ruthless Fun",
            players: "2 or more",
            instructions: "Each player throws three darts per round, and the player with the lowest total is eliminated. The last player standing wins."
        ),
        Game(
            title: "English Cricket",
            subtitle: "Bat and Bowl with Darts",
            players: "2 or more",
            instructions: "The batting team aims to score points by hitting numbers 15–20 and bullseye. The bowling team aims for the bullseye to get wickets. The team with the highest score after both have batted wins."
        ),
        Game(
            title: "Killer",
            subtitle: "Target Others, Protect Yourself",
            players: "2 or more",
            instructions: "Each player gets their own number. Players must first hit their own number's double to become a Killer. Once a Killer, hitting another player's number's double removes one of their lives."
        )
    ]
}

// MARK: - Preview Helpers

#if DEBUG
extension Game {
    static var preview301: Game {
        Game(
            title: "301",
            subtitle: "A Classic Countdown Game",
            players: "2 or more",
            instructions: "Each player starts with a score of 301. Players take turns throwing three darts per round and subtract the total from their score. The goal is to reach exactly zero, finishing on a double."
        )
    }
    
    static var preview501: Game {
        Game(
            title: "501",
            subtitle: "The Professional Standard",
            players: "2 or more",
            instructions: "Players start with 501 points and take turns throwing three darts. The objective is to reach exactly zero, with the final dart landing on a double."
        )
    }
    
    static var previewHalveIt: Game {
        Game(
            title: "Halve-It",
            subtitle: "Accuracy Under Pressure",
            players: "2 or more",
            instructions: "Select six different targets on the dartboard. For every target hit, add that score to your total. If you fail to hit a target with three darts, you must halve your total score."
        )
    }
}
#endif
