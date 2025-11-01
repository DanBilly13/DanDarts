//
//  MatchService.swift
//  DanDart
//
//  Service for saving and loading matches from Supabase
//

import Foundation

// MARK: - Codable Models for Supabase

struct MatchRecord: Codable {
    let id: String
    let game_id: String
    let started_at: String
    let ended_at: String
    let winner_id: String?
    let metadata: MatchMetadata
    
    // Legacy columns for backward compatibility
    let game_type: String
    let game_name: String
    let duration: Int
    let timestamp: String
}

struct MatchMetadata: Codable {
    let match_format: Int
    let legs_won: [String: Int]
}

struct MatchPlayerRecord: Codable {
    let match_id: String
    let player_user_id: String?
    let guest_name: String?
    let player_order: Int
}

struct MatchThrowRecord: Codable {
    let match_id: String
    let player_order: Int
    let turn_index: Int
    let dart_scores: [Int]
    let score_before: Int
    let score_after: Int
    let game_metadata: [String: String]? // Game-specific data (e.g., Halve-It targets)
    
    enum CodingKeys: String, CodingKey {
        case match_id
        case player_order
        case turn_index
        case dart_scores = "throws" // Map to database column name
        case score_before
        case score_after
        case game_metadata
    }
}

struct PlayerStatsRecord: Codable {
    let user_id: String
    let games_played: Int
    let wins: Int
    let losses: Int
    let last_updated: String
}

@MainActor
class MatchService: ObservableObject {
    private let supabaseService = SupabaseService.shared
    
    // MARK: - Match Saving
    
    /// Save a completed match to Supabase
    /// - Parameters:
    ///   - matchId: UUID of the match
    ///   - gameId: Game type (e.g., "301", "501")
    ///   - players: Array of players in the match
    ///   - winnerId: UUID of the winning player (nil for guest winners)
    ///   - startedAt: When the match started
    ///   - endedAt: When the match ended
    ///   - turnHistory: Array of all turns played
    ///   - matchFormat: Number of legs (1, 3, 5, or 7)
    ///   - legsWon: Dictionary of player ID to legs won
    func saveMatch(
        matchId: UUID,
        gameId: String,
        players: [Player],
        winnerId: UUID?,
        startedAt: Date,
        endedAt: Date,
        turnHistory: [TurnHistory],
        matchFormat: Int,
        legsWon: [UUID: Int]
    ) async throws {
        // 1. Insert match record
        let duration = Int(endedAt.timeIntervalSince(startedAt))
        let matchRecord = MatchRecord(
            id: matchId.uuidString,
            game_id: gameId,
            started_at: ISO8601DateFormatter().string(from: startedAt),
            ended_at: ISO8601DateFormatter().string(from: endedAt),
            winner_id: winnerId?.uuidString,
            metadata: MatchMetadata(
                match_format: matchFormat,
                legs_won: legsWon.mapKeys { $0.uuidString }
            ),
            // Legacy columns for backward compatibility
            game_type: gameId,
            game_name: gameId.replacingOccurrences(of: "_", with: " ").capitalized,
            duration: duration,
            timestamp: ISO8601DateFormatter().string(from: endedAt)
        )
        
        try await supabaseService.client
            .from("matches")
            .insert(matchRecord)
            .execute()
        
        // 2. Insert match_players records
        for (index, player) in players.enumerated() {
            let playerRecord = MatchPlayerRecord(
                match_id: matchId.uuidString,
                player_user_id: player.userId?.uuidString,
                guest_name: player.userId == nil ? player.displayName : nil,
                player_order: index
            )
            
            try await supabaseService.client
                .from("match_players")
                .insert(playerRecord)
                .execute()
        }
        
        // 3. Insert match_throws records (bulk insert)
        var throwRecords: [MatchThrowRecord] = []
        
        for turn in turnHistory {
            // Find player order
            guard let playerOrder = players.firstIndex(where: { $0.id == turn.playerId }) else {
                continue
            }
            
            let throwRecord = MatchThrowRecord(
                match_id: matchId.uuidString,
                player_order: playerOrder,
                turn_index: turn.turnNumber,
                dart_scores: turn.darts.map { $0.totalValue },
                score_before: turn.scoreBefore,
                score_after: turn.scoreAfter,
                game_metadata: turn.gameMetadata // Include game-specific data
            )
            
            throwRecords.append(throwRecord)
        }
        
        if !throwRecords.isEmpty {
            try await supabaseService.client
                .from("match_throws")
                .insert(throwRecords)
                .execute()
        }
        
        // 4. Update player stats for connected players
        if let winnerId = winnerId {
            try await updatePlayerStats(winnerId: winnerId, players: players)
        }
        
        print("✅ Match saved successfully: \(matchId)")
    }
    
    // MARK: - Player Stats
    
    /// Update player stats after a match
    private func updatePlayerStats(winnerId: UUID, players: [Player]) async throws {
        print("🔍 Updating stats for \(players.count) players. Winner ID: \(winnerId)")
        for player in players {
            print("🔍 Player: \(player.displayName), userId: \(player.userId?.uuidString ?? "nil"), isGuest: \(player.isGuest)")
            guard let userId = player.userId else {
                print("⚠️ Skipping \(player.displayName) - no userId (guest player)")
                continue
            } // Skip guests
            
            let isWinner = userId == winnerId
            
            // Fetch current user stats
            let currentUser: User = try await supabaseService.client
                .from("users")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            // Increment wins or losses
            let newWins = currentUser.totalWins + (isWinner ? 1 : 0)
            let newLosses = currentUser.totalLosses + (isWinner ? 0 : 1)
            
            // Create update record
            struct UserStatsUpdate: Encodable {
                let total_wins: Int
                let total_losses: Int
                let last_seen_at: String
            }
            
            let updateRecord = UserStatsUpdate(
                total_wins: newWins,
                total_losses: newLosses,
                last_seen_at: ISO8601DateFormatter().string(from: Date())
            )
            
            // Update user stats in users table
            try await supabaseService.client
                .from("users")
                .update(updateRecord)
                .eq("id", value: userId.uuidString)
                .execute()
            
            print("✅ Updated stats for \(currentUser.displayName): \(newWins)W/\(newLosses)L")
        }
    }
    
    // MARK: - Match Loading
    
    /// Load matches for a specific user
    func loadMatches(userId: UUID, limit: Int = 50) async throws -> [MatchResult] {
        // Query matches where user participated
        let response = try await supabaseService.client
            .from("matches")
            .select("""
                id,
                game_id,
                started_at,
                ended_at,
                winner_id,
                metadata,
                match_players(player_user_id, guest_name, player_order)
            """)
            .or("winner_id.eq.\(userId.uuidString),match_players.player_user_id.eq.\(userId.uuidString)")
            .order("ended_at", ascending: false)
            .limit(limit)
            .execute()
        
        // Parse response into MatchResult objects
        // TODO: Implement MatchResult parsing
        
        return []
    }
}

// MARK: - Helper Extensions

extension Dictionary where Key == UUID {
    func mapKeys<T>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
}
