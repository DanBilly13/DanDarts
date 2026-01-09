//
//  Game.swift
//  Dart Freak
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
    
    // Custom initializer to allow creating Game instances
    init(title: String, subtitle: String, players: String, instructions: String) {
        self.title = title
        self.subtitle = subtitle
        self.players = players
        self.instructions = instructions
    }
    
    // Decodable initializer for JSON decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decode(String.self, forKey: .title)
        self.subtitle = try container.decode(String.self, forKey: .subtitle)
        self.players = try container.decode(String.self, forKey: .players)
        self.instructions = try container.decode(String.self, forKey: .instructions)
    }
    
    // Computed properties for backwards compatibility
    var name: String { title }
    var tagline: String { subtitle }
    
    /// Canonical cover image asset name for this game.
    /// Uses the convention: "<slug>", where slug is the lowercased
    /// title with spaces replaced by hyphens. The `game-cover` group
    /// in the asset catalog is organizational only and not part of
    /// the runtime image name.
    var coverImageName: String {
        let slug = title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return slug
    }
    
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
        guard let url = Bundle.main.url(forResource: "darts_games", withExtension: "json") else {
#if DEBUG
            fatalError("❌ darts_games.json not found in bundle. Ensure it is added to the DanDart target and Copy Bundle Resources.")
#else
            return []
#endif
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Game].self, from: data)
        } catch {
#if DEBUG
            fatalError("❌ Failed to decode darts_games.json: \(error)")
#else
            return []
#endif
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension Game {
    static var preview301: Game {
        Game(
            title: "301",
            subtitle: "A Classic Countdown Game",
            players: "2-8",
            instructions: "You start with a score of 301. On your turn (called a visit), throw three darts and subtract the total from your score.\n\nYour goal is to reach exactly zero, finishing on a double.\n\nIf your score drops below zero, or you're left on 1, the turn is a bust and your score returns to what it was before you threw.\n\nThe first player to check out on zero wins.\n\nA perfect game?\nThe fewest visits you can finish 301 in is two — incredibly rare:\n\n- Visit 1: 180 (T20 T20 T20)\n- Visit 2: 121 checkout (T20, 11, D20)"
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
