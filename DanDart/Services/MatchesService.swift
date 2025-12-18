//
//  MatchesService.swift
//  DanDart
//
//  Service for syncing match results to Supabase
//

import Foundation
import Supabase

@MainActor
class MatchesService: ObservableObject {
    private let supabaseService = SupabaseService.shared
    
    // MARK: - Test Connection
    
    /// Test basic Supabase connection
    func testConnection() async -> Bool {
        do {
            // Try a simple select query
            let _: [SupabaseMatch] = try await supabaseService.client
                .from("matches")
                .select()
                .limit(1)
                .execute()
                .value
            
            print("✅ Supabase connection test: SUCCESS")
            return true
        } catch {
            print("❌ Supabase connection test: FAILED - \(error)")
            return false
        }
    }
    
    // MARK: - Sync Match to Supabase
    
    /// Sync a match result to Supabase
    /// - Parameter match: The match result to sync
    /// - Returns: The synced match ID
    func syncMatch(_ match: MatchResult) async throws -> UUID {
        print("🔄 Starting match sync: \(match.id)")
        print("   Game: \(match.gameName), Players: \(match.players.count)")
        
        // Test connection first
        let connectionOk = await testConnection()
        if !connectionOk {
            print("   ⚠️ Connection test failed, but will try sync anyway...")
        }
        
        // Convert MatchResult to Supabase format
        let supabaseMatch = SupabaseMatch(
            id: match.id,
            gameType: match.gameType,
            gameName: match.gameName,
            winnerId: match.winnerId,
            timestamp: match.timestamp,
            duration: Int(match.duration), // Convert to seconds
            players: match.players,
            matchFormat: match.matchFormat,
            totalLegsPlayed: match.totalLegsPlayed,
            syncedAt: Date()
        )
        
        // Debug: Log player IDs and current auth user
        print("   Player IDs in match:")
        for player in match.players {
            print("     - \(player.displayName): \(player.id)")
        }
        
        // Check current authenticated user
        do {
            let session = try await supabaseService.client.auth.session
            print("   Current auth user ID: \(session.user.id)")
        } catch {
            print("   ⚠️ No authenticated user session")
        }
        
        do {
            print("   Attempting insert to Supabase...")
            
            // Insert match into Supabase with explicit error handling
            let response = try await supabaseService.client
                .from("matches")
                .insert(supabaseMatch)
                .execute()
            
            print("✅ Match synced to Supabase: \(match.id)")
            print("   Response status: \(response.response.statusCode)")
            return match.id
            
        } catch let error as NSError {
            print("❌ Match sync failed with NSError:")
            print("   Domain: \(error.domain)")
            print("   Code: \(error.code)")
            print("   Description: \(error.localizedDescription)")
            print("   User Info: \(error.userInfo)")
            throw MatchSyncError.syncFailed
        } catch {
            print("❌ Match sync failed: \(error)")
            throw MatchSyncError.syncFailed
        }
    }
    
    // MARK: - Load Matches from Supabase
    
    /// Load all matches for a user
    /// - Parameter userId: User's ID
    /// - Returns: Array of match results
    func loadMatches(userId: UUID) async throws -> [MatchResult] {
        do {
            // Query matches where user participated (check players JSONB array)
            // Note: We filter client-side since JSONB array filtering is complex in Supabase
            let response = try await supabaseService.client
                .from("matches")
                .select("id, game_type, game_name, winner_id, timestamp, duration, players, match_format, total_legs_played, metadata")
                .order("timestamp", ascending: false)
                .execute()
            
            // Parse the response manually to handle JSONB
            guard let jsonArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
                print("❌ Failed to parse response as JSON array")
                return []
            }
            
            print("📊 Supabase query returned \(jsonArray.count) matches")
            
            var matches: [MatchResult] = []
            
            // Filter matches to only include those where the user participated
            for json in jsonArray {
                // Extract fields manually with detailed error logging
                guard let idString = json["id"] as? String else {
                    print("⚠️ Skipping match - missing 'id' field")
                    continue
                }
                guard let id = UUID(uuidString: idString) else {
                    print("⚠️ Skipping match - invalid UUID for 'id': \(idString)")
                    continue
                }
                guard let gameType = json["game_type"] as? String else {
                    print("⚠️ Skipping match \(idString) - missing 'game_type' field")
                    continue
                }
                guard let gameName = json["game_name"] as? String else {
                    print("⚠️ Skipping match \(idString) - missing 'game_name' field")
                    continue
                }
                guard let winnerIdString = json["winner_id"] as? String else {
                    print("⚠️ Skipping match \(idString) - missing 'winner_id' field")
                    continue
                }
                guard let winnerId = UUID(uuidString: winnerIdString) else {
                    print("⚠️ Skipping match \(idString) - invalid UUID for 'winner_id': \(winnerIdString)")
                    continue
                }
                guard let timestampString = json["timestamp"] as? String else {
                    print("⚠️ Skipping match \(idString) - missing 'timestamp' field")
                    continue
                }
                guard let duration = json["duration"] as? Int else {
                    print("⚠️ Skipping match \(idString) - missing 'duration' field")
                    continue
                }
                
                // Parse timestamp - try multiple formats
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                var timestamp = formatter.date(from: timestampString)
                
                // Fallback: try without fractional seconds
                if timestamp == nil {
                    formatter.formatOptions = [.withInternetDateTime]
                    timestamp = formatter.date(from: timestampString)
                }
                
                // Fallback: try basic ISO8601
                if timestamp == nil {
                    let basicFormatter = DateFormatter()
                    basicFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    timestamp = basicFormatter.date(from: timestampString)
                }
                
                guard let timestamp = timestamp else {
                    print("⚠️ Skipping match with invalid timestamp: \(timestampString)")
                    continue
                }
                
                // Parse JSONB players array (basic info only - turns will be loaded separately)
                let basicPlayers: [MatchPlayer]
                var userParticipated = false
                
                if let playersString = json["players"] as? String {
                    // Case 1: players is a JSON string - convert to Data and decode
                    guard let playersJsonData = playersString.data(using: .utf8) else {
                        print("⚠️ Skipping match - could not convert players string to data")
                        continue
                    }
                    let decoder = JSONDecoder()
                    basicPlayers = try decoder.decode([MatchPlayer].self, from: playersJsonData)
                    // For connected users, player.id == user account ID
                    // For guests, player.id is a random UUID and isGuest = true
                    userParticipated = basicPlayers.contains { player in
                        !player.isGuest && player.id == userId
                    }
                    print("🔍 Match \(idString): Players = \(basicPlayers.map { "\($0.displayName) (guest: \($0.isGuest), id: \($0.id))" }), User participated: \(userParticipated)")
                    
                } else if let playersArray = json["players"] as? [[String: Any]] {
                    // Case 2: players is already parsed as an array - serialize and decode
                    let playersJsonData = try JSONSerialization.data(withJSONObject: playersArray)
                    let decoder = JSONDecoder()
                    basicPlayers = try decoder.decode([MatchPlayer].self, from: playersJsonData)
                    // For connected users, player.id == user account ID
                    // For guests, player.id is a random UUID and isGuest = true
                    userParticipated = basicPlayers.contains { player in
                        !player.isGuest && player.id == userId
                    }
                    print("🔍 Match \(idString): Players = \(basicPlayers.map { "\($0.displayName) (guest: \($0.isGuest), id: \($0.id))" }), User participated: \(userParticipated)")
                    
                } else {
                    print("⚠️ Skipping match - players data is neither string nor array")
                    continue
                }
                
                // Skip matches where user didn't participate
                if !userParticipated {
                    print("⏭️ Skipping match - user \(userId) did not participate")
                    continue
                }
                print("✅ Including match - user \(userId) participated")
                
                // Get optional fields
                let matchFormat = json["match_format"] as? Int ?? 1
                let totalLegsPlayed = json["total_legs_played"] as? Int ?? 1
                
                // Parse metadata (for Halve-It difficulty, etc.)
                var metadata: [String: String]? = nil
                if let metadataDict = json["metadata"] as? [String: Any] {
                    metadata = metadataDict.compactMapValues { $0 as? String }
                }
                
                // Load turn data from match_throws table
                let playersWithTurns = try await loadTurnsForMatch(matchId: id, players: basicPlayers)
                
                // Create MatchResult with complete turn data
                let match = MatchResult(
                    id: id,
                    gameType: gameType,
                    gameName: gameName,
                    players: playersWithTurns,
                    winnerId: winnerId,
                    timestamp: timestamp,
                    duration: TimeInterval(duration),
                    matchFormat: matchFormat,
                    totalLegsPlayed: totalLegsPlayed,
                    metadata: metadata
                )
                
                matches.append(match)
            }
            
            print("✅ Loaded \(matches.count) matches from Supabase (with turn data)")
            return matches
            
        } catch {
            print("❌ Load matches failed: \(error)")
            print("   Error details: \(error.localizedDescription)")
            throw MatchSyncError.loadFailed
        }
    }
    
    /// Load turn data for a specific match from match_throws table
    /// - Parameters:
    ///   - matchId: The match ID
    ///   - players: Basic player data (without turns)
    /// - Returns: Players with complete turn data
    private func loadTurnsForMatch(matchId: UUID, players: [MatchPlayer]) async throws -> [MatchPlayer] {
        // Query match_throws table for this match
        let response: Data
        do {
            let result = try await supabaseService.client
                .from("match_throws")
                .select("id,match_id,player_order,turn_index,throws,score_before,score_after,is_bust,game_metadata")
                .eq("match_id", value: matchId.uuidString)
                .order("player_order")
                .order("turn_index")
                .execute()
            response = result.data
        } catch {
            print("⚠️ Failed to query turn data for match \(matchId): \(error)")
            return players
        }
        
        // Parse throws data
        guard let throwsArray = try? JSONSerialization.jsonObject(with: response) as? [[String: Any]] else {
            print("⚠️ No turn data found for match \(matchId), returning players with empty turns")
            return players
        }
        
        // Group throws by player_order
        var playerTurns: [Int: [MatchTurn]] = [:]
        
        for throwJson in throwsArray {
            guard let playerOrder = throwJson["player_order"] as? Int,
                  let turnIndex = throwJson["turn_index"] as? Int,
                  let scoreBefore = throwJson["score_before"] as? Int,
                  let scoreAfter = throwJson["score_after"] as? Int else {
                continue
            }
            
            // Parse throws - handle multiple formats
            let dartScores: [Int]
            if let throwsArray = throwJson["throws"] as? [Int] {
                dartScores = throwsArray
            } else if let throwsArray = throwJson["throws"] as? [Any] {
                dartScores = throwsArray.compactMap { $0 as? Int }
            } else {
                print("⚠️ Skipping turn - could not parse throws data")
                continue
            }
            
            // Get game_metadata (for Halve-It target display and Killer dart metadata)
            var targetDisplay: String? = nil
            var killerDartsMetadataMap: [Int: [String: Any]] = [:] // Map dart index to metadata
            if let gameMetadata = throwJson["game_metadata"] as? [String: Any] {
                // Halve-It target
                if let target = gameMetadata["target_display"] as? String {
                    targetDisplay = target
                }
                // Killer darts metadata (stored as JSON string)
                if let killerDartsJson = gameMetadata["killer_darts"] as? String,
                   let jsonData = killerDartsJson.data(using: .utf8),
                   let dartsArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                    // Build map of dart_index -> metadata
                    for dartMeta in dartsArray {
                        if let dartIndex = dartMeta["dart_index"] as? Int {
                            killerDartsMetadataMap[dartIndex] = dartMeta
                        }
                    }
                }
            }
            
            // Get is_bust flag (for Knockout life losses)
            let isBust = throwJson["is_bust"] as? Bool ?? false
            
            // Convert dart scores to MatchDart objects
            let darts = dartScores.enumerated().map { index, score -> MatchDart in
                // Try to get killer metadata for this dart using the index
                var killerMetadata: KillerDartMetadata? = nil
                if let dartMeta = killerDartsMetadataMap[index] {
                    if let outcomeStr = dartMeta["outcome"] as? String,
                       let outcome = KillerDartMetadata.KillerDartOutcome(rawValue: outcomeStr) {
                        let affectedIds = (dartMeta["affected_player_ids"] as? [String] ?? []).compactMap { UUID(uuidString: $0) }
                        killerMetadata = KillerDartMetadata(outcome: outcome, affectedPlayerIds: affectedIds)
                    }
                }
                
                // For now, assume all are singles (baseValue = score, multiplier = 1)
                // This is a limitation - we lose the double/triple info
                // But for Halve-It, what matters is whether the dart hit the target (value > 0)
                return MatchDart(baseValue: score, multiplier: 1, killerMetadata: killerMetadata)
            }
            
            let turn = MatchTurn(
                turnNumber: turnIndex,
                darts: darts,
                scoreBefore: scoreBefore,
                scoreAfter: scoreAfter,
                isBust: isBust,
                targetDisplay: targetDisplay
            )
            
            if playerTurns[playerOrder] == nil {
                playerTurns[playerOrder] = []
            }
            playerTurns[playerOrder]?.append(turn)
        }
        
        // Reconstruct players with turn data
        var playersWithTurns: [MatchPlayer] = []
        for (index, player) in players.enumerated() {
            let turns = playerTurns[index] ?? []
            let totalDarts = turns.reduce(0) { $0 + $1.darts.count }
            let finalScore = turns.last?.scoreAfter ?? player.finalScore
            let startingScore = turns.first?.scoreBefore ?? player.startingScore
            
            let playerWithTurns = MatchPlayer(
                id: player.id,
                displayName: player.displayName,
                nickname: player.nickname,
                avatarURL: player.avatarURL,
                isGuest: player.isGuest,
                finalScore: finalScore,
                startingScore: startingScore,
                totalDartsThrown: totalDarts,
                turns: turns,
                legsWon: player.legsWon
            )
            
            playersWithTurns.append(playerWithTurns)
        }
        
        return playersWithTurns
    }
    
    // MARK: - Retry Failed Syncs
    
    /// Retry syncing matches that failed previously
    /// - Parameter matches: Array of matches to retry
    /// - Returns: Number of successfully synced matches
    func retrySyncFailedMatches(_ matches: [MatchResult]) async -> Int {
        var successCount = 0
        
        for match in matches {
            do {
                _ = try await syncMatch(match)
                successCount += 1
            } catch {
                print("❌ Retry sync failed for match \(match.id)")
            }
        }
        
        return successCount
    }
}

// MARK: - Supabase Match Model

/// Match model for Supabase (flattened structure)
struct SupabaseMatch: Codable {
    let id: UUID
    let gameType: String
    let gameName: String
    let winnerId: UUID
    let timestamp: Date
    let duration: Int // seconds
    let players: [MatchPlayer]
    let matchFormat: Int // Total legs in match (1, 3, 5, or 7)
    let totalLegsPlayed: Int // Actual number of legs played
    let syncedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case gameType = "game_type"
        case gameName = "game_name"
        case winnerId = "winner_id"
        case timestamp
        case duration
        case players
        case matchFormat = "match_format"
        case totalLegsPlayed = "total_legs_played"
        case syncedAt = "synced_at"
    }
    
    /// Convert to MatchResult
    func toMatchResult() -> MatchResult {
        return MatchResult(
            id: id,
            gameType: gameType,
            gameName: gameName,
            players: players,
            winnerId: winnerId,
            timestamp: timestamp,
            duration: TimeInterval(duration),
            matchFormat: matchFormat,
            totalLegsPlayed: totalLegsPlayed
        )
    }
}

// MARK: - Errors

enum MatchSyncError: LocalizedError {
    case syncFailed
    case loadFailed
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .syncFailed:
            return "Failed to sync match to server"
        case .loadFailed:
            return "Failed to load matches from server"
        case .notAuthenticated:
            return "You must be signed in to sync matches"
        }
    }
}
