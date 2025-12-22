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
    let players: String // JSONB as string (will be encoded as JSON)
}

struct MatchMetadata: Codable {
    let match_format: Int
    let legs_won: [String: Int]
    let game_metadata: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case match_format
        case legs_won
        case game_metadata
    }
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
    let is_bust: Bool // For Knockout: tracks life losses
    let game_metadata: [String: String]? // Game-specific data (e.g., Halve-It targets)
    
    enum CodingKeys: String, CodingKey {
        case match_id
        case player_order
        case turn_index
        case dart_scores = "throws" // Map to database column name
        case score_before
        case score_after
        case is_bust
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
    ///   - currentUserId: UUID of the current user (optional)
    func saveMatch(
        matchId: UUID,
        gameId: String,
        players: [Player],
        winnerId: UUID?,
        startedAt: Date,
        endedAt: Date,
        turnHistory: [TurnHistory],
        matchFormat: Int,
        legsWon: [UUID: Int],
        gameMetadata: [String: String]? = nil,
        currentUserId: UUID? = nil
    ) async throws -> User? {
        // Debug: Check AuthService state at the start
        print("🔍 saveMatch called. AuthService.shared.currentUser: \(AuthService.shared.currentUser?.displayName ?? "nil")")
        
        // Verify we have an authenticated session
        do {
            let session = try await supabaseService.client.auth.session
            print("✅ Authenticated session found: \(session.user.id)")
        } catch {
            print("❌ No authenticated session - RLS will block this request")
            throw error
        }
        
        // Upload local avatar files to Supabase before saving match
        var updatedPlayers = players
        for (index, player) in players.enumerated() {
            if let avatarURL = player.avatarURL,
               (avatarURL.hasPrefix("/") || avatarURL.contains("/Documents/") || avatarURL.contains("/tmp/")) {
                // This is a local file path - upload it to Supabase
                print("📤 Uploading local avatar for \(player.displayName): \(avatarURL)")
                
                if let imageData = try? Data(contentsOf: URL(fileURLWithPath: avatarURL)) {
                    do {
                        let publicURL = try await uploadPlayerAvatar(imageData: imageData, playerId: player.id)
                        print("✅ Avatar uploaded: \(publicURL)")
                        
                        // Update player's avatarURL to use Supabase URL
                        var updatedPlayer = player
                        updatedPlayer = Player(
                            id: updatedPlayer.id,
                            displayName: updatedPlayer.displayName,
                            nickname: updatedPlayer.nickname,
                            avatarURL: publicURL,
                            isGuest: updatedPlayer.isGuest,
                            totalWins: updatedPlayer.totalWins,
                            totalLosses: updatedPlayer.totalLosses,
                            userId: updatedPlayer.userId
                        )
                        updatedPlayers[index] = updatedPlayer
                    } catch {
                        print("⚠️ Failed to upload avatar for \(player.displayName): \(error)")
                        // Continue with local path - better than failing the whole match save
                    }
                } else {
                    print("⚠️ Failed to load avatar file for \(player.displayName)")
                }
            }
        }
        
        // Use updated players with Supabase avatar URLs
        let playersToSave = updatedPlayers
        
        // 1. Insert match record
        let duration = Int(endedAt.timeIntervalSince(startedAt))
        
        // Create legacy players JSONB (simplified player data)
        let legacyPlayers = playersToSave.map { player in
            var playerDict: [String: Any] = [
                "id": (player.userId ?? player.id).uuidString, // Use userId for connected players, player.id for guests
                "displayName": player.displayName,
                "nickname": player.nickname,
                "isGuest": player.isGuest ? "true" : "false"
            ]
            // Include avatarURL if present (important for match history display)
            if let avatarURL = player.avatarURL {
                playerDict["avatarURL"] = avatarURL
            }
            return playerDict
        }
        let playersJSON = try JSONSerialization.data(withJSONObject: legacyPlayers)
        let playersString = String(data: playersJSON, encoding: .utf8) ?? "[]"
        
        let matchRecord = MatchRecord(
            id: matchId.uuidString,
            game_id: gameId,
            started_at: ISO8601DateFormatter().string(from: startedAt),
            ended_at: ISO8601DateFormatter().string(from: endedAt),
            winner_id: winnerId?.uuidString,
            metadata: MatchMetadata(
                match_format: matchFormat,
                legs_won: legsWon.mapKeys { $0.uuidString },
                game_metadata: gameMetadata
            ),
            // Legacy columns for backward compatibility
            game_type: gameId,
            game_name: gameId.replacingOccurrences(of: "_", with: " ").capitalized,
            duration: duration,
            timestamp: ISO8601DateFormatter().string(from: endedAt),
            players: playersString
        )
        
        // Delete existing match if it exists (handles duplicate IDs)
        try? await supabaseService.client
            .from("matches")
            .delete()
            .eq("id", value: matchId.uuidString)
            .execute()
        
        // Insert match record
        try await supabaseService.client
            .from("matches")
            .insert(matchRecord)
            .execute()
        
        // Delete old child records if this is a re-save (handles duplicates)
        try? await supabaseService.client
            .from("match_players")
            .delete()
            .eq("match_id", value: matchId.uuidString)
            .execute()
        
        try? await supabaseService.client
            .from("match_throws")
            .delete()
            .eq("match_id", value: matchId.uuidString)
            .execute()
        
        // 2. Insert match_players records
        for (index, player) in playersToSave.enumerated() {
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
                is_bust: turn.isBust, // Include life loss flag for Knockout
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
        
        // 4. Update player stats for connected players and get updated user
        var updatedUser: User? = nil
        if let winnerId = winnerId {
            updatedUser = try await updatePlayerStats(winnerId: winnerId, players: playersToSave, currentUserId: currentUserId)
        }
        
        print("✅ Match saved successfully: \(matchId)")
        
        // Return updated user so caller can update AuthService directly
        return updatedUser
    }
    
    // MARK: - Player Stats
    
    /// Update player stats after a match and return updated user if current user was in the match
    private func updatePlayerStats(winnerId: UUID, players: [Player], currentUserId: UUID?) async throws -> User? {
        print("🔍 Updating stats for \(players.count) players. Winner ID: \(winnerId)")
        print("🔍 Current user ID passed: \(currentUserId?.uuidString ?? "nil")")
        var updatedCurrentUser: User? = nil
        
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
            print("📝 Updating user \(userId.uuidString) from \(currentUser.totalWins)W/\(currentUser.totalLosses)L to \(newWins)W/\(newLosses)L")
            
            let response = try await supabaseService.client
                .from("users")
                .update(updateRecord)
                .eq("id", value: userId.uuidString)
                .execute()
            
            print("✅ Updated stats for \(currentUser.displayName): \(newWins)W/\(newLosses)L")
            print("   Response status: \(response.response.statusCode)")
            
            // Create updated user object with new stats
            var updatedUser = currentUser
            updatedUser.totalWins = newWins
            updatedUser.totalLosses = newLosses
            updatedUser.lastSeenAt = Date()
            
            // Store ONLY if this is the authenticated current user
            // This ensures we return YOUR stats, not your opponent's stats
            if let passedUserId = currentUserId {
                print("🔍 Checking if \(userId.uuidString) == \(passedUserId.uuidString)")
                if userId == passedUserId {
                    updatedCurrentUser = updatedUser
                    print("📌 This is the authenticated user - will return their updated data")
                } else {
                    print("⚠️ Not the authenticated user - skipping")
                }
            } else {
                print("⚠️ No currentUserId was passed to updatePlayerStats")
            }
        }
        
        return updatedCurrentUser
    }
    
    // MARK: - Avatar Upload Helper
    
    /// Upload player avatar to Supabase Storage
    /// - Parameters:
    ///   - imageData: The image data to upload
    ///   - playerId: The player's ID (used for filename)
    /// - Returns: The public URL of the uploaded avatar
    private func uploadPlayerAvatar(imageData: Data, playerId: UUID) async throws -> String {
        // Generate unique filename
        let fileExtension = "jpg"
        let fileName = "\(playerId.uuidString)_\(Date().timeIntervalSince1970).\(fileExtension)"
        let filePath = "avatars/\(fileName)"
        
        // Upload to Supabase Storage
        try await supabaseService.client.storage
            .from("avatars")
            .upload(
                filePath,
                data: imageData,
                options: .init(
                    contentType: "image/jpeg",
                    upsert: false
                )
            )
        
        // Get public URL
        let publicURL = try supabaseService.client.storage
            .from("avatars")
            .getPublicURL(path: filePath)
        
        return publicURL.absoluteString
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
