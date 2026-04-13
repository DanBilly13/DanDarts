//
//  RankingHelper.swift
//  Dart Freak
//
//  Ranking system for 301/501 games
//  Provides match-level rank and profile rank calculation
//

import Foundation

enum RankTier: String, Codable, CaseIterable {
    case unranked
    case newby
    case intermediate
    case advanced
    case proLevel
    case worldClass
    case immortal
    
    var displayName: String {
        switch self {
        case .unranked: return "None"
        case .newby: return "Rookie"
        case .intermediate: return "Solid"
        case .advanced: return "Club"
        case .proLevel: return "Pro"
        case .worldClass: return "Elite"
        case .immortal: return "Freak"
        }
    }
    
    var iconName: String {
        switch self {
        case .unranked: return "none"
        case .newby: return "rookie"
        case .intermediate: return "solid"
        case .advanced: return "club"
        case .proLevel: return "pro"
        case .worldClass: return "elite"
        case .immortal: return "freak"
        }
    }
}

struct RankingHelper {
    
    // MARK: - Match-Level Rank
    
    /// Calculate rank for a winning performance in 301 or 501
    /// - Parameters:
    ///   - game: Game type ("301" or "501")
    ///   - dartsThrown: Total darts thrown by winner
    /// - Returns: RankTier for this performance
    static func rankForWinningDarts(game: String, dartsThrown: Int) -> RankTier {
        let gameType = game.lowercased().replacingOccurrences(of: "remote ", with: "")
        
        if gameType.contains("301") {
            return rankFor301(dartsThrown: dartsThrown)
        } else if gameType.contains("501") {
            return rankFor501(dartsThrown: dartsThrown)
        } else {
            return .unranked
        }
    }
    
    private static func rankFor301(dartsThrown: Int) -> RankTier {
        switch dartsThrown {
        case ...6: return .immortal
        case 7...9: return .worldClass
        case 10...12: return .proLevel
        case 13...18: return .advanced
        case 19...27: return .intermediate
        default: return .newby
        }
    }
    
    private static func rankFor501(dartsThrown: Int) -> RankTier {
        switch dartsThrown {
        case ...9: return .immortal
        case 10...12: return .worldClass
        case 13...15: return .proLevel
        case 16...21: return .advanced
        case 22...30: return .intermediate
        default: return .newby
        }
    }
    
    // MARK: - Tier Score Conversion
    
    /// Convert RankTier to numeric score for averaging
    /// - Parameter tier: RankTier to convert
    /// - Returns: Numeric score (1-6)
    static func tierScore(for tier: RankTier) -> Int {
        switch tier {
        case .immortal: return 6
        case .worldClass: return 5
        case .proLevel: return 4
        case .advanced: return 3
        case .intermediate: return 2
        case .newby: return 1
        case .unranked: return 0
        }
    }
    
    // MARK: - Profile Rank
    
    /// Calculate profile rank from average tier score
    /// - Parameter averageTierScore: Average of all tier scores from qualifying wins
    /// - Returns: RankTier representing overall profile rank
    static func profileRankFromAverageTierScore(_ averageTierScore: Double) -> RankTier {
        guard averageTierScore > 0 else { return .unranked }
        
        // Map average back to rank tier
        // Use midpoint thresholds between tier scores
        switch averageTierScore {
        case 5.5...: return .immortal      // 5.5+
        case 4.5..<5.5: return .worldClass // 4.5-5.49
        case 3.5..<4.5: return .proLevel   // 3.5-4.49
        case 2.5..<3.5: return .advanced   // 2.5-3.49
        case 1.5..<2.5: return .intermediate // 1.5-2.49
        case 0..<1.5: return .newby        // 0-1.49
        default: return .unranked
        }
    }
    
    // MARK: - Threshold Markers for Visual Bar
    
    /// Get threshold marker positions for Winner Darts Thrown bar
    /// - Parameter game: Game type ("301" or "501")
    /// - Returns: Array of dart counts for threshold markers
    static func thresholdMarkers(for game: String) -> [Int] {
        let gameType = game.lowercased().replacingOccurrences(of: "remote ", with: "")
        
        if gameType.contains("301") {
            return [6, 12, 18, 27]
        } else if gameType.contains("501") {
            return [9, 15, 21, 30]
        } else {
            return []
        }
    }
}
