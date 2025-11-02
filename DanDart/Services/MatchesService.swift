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
            // Query matches - RLS policy will filter to matches where user participated
            let response = try await supabaseService.client
                .from("matches")
                .select("id, game_type, game_name, winner_id, timestamp, duration, players, match_format, total_legs_played")
                .order("timestamp", ascending: false)
                .execute()
            
            // Parse the response manually to handle JSONB
            guard let jsonArray = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
                print("❌ Failed to parse response as JSON array")
                return []
            }
            
            var matches: [MatchResult] = []
            
            for json in jsonArray {
                // Extract fields manually
                guard let idString = json["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let gameType = json["game_type"] as? String,
                      let gameName = json["game_name"] as? String,
                      let winnerIdString = json["winner_id"] as? String,
                      let winnerId = UUID(uuidString: winnerIdString),
                      let timestampString = json["timestamp"] as? String,
                      let duration = json["duration"] as? Int else {
                    print("⚠️ Skipping match with missing required fields")
                    continue
                }
                
                // Parse timestamp
                let formatter = ISO8601DateFormatter()
                guard let timestamp = formatter.date(from: timestampString) else {
                    print("⚠️ Skipping match with invalid timestamp")
                    continue
                }
                
                // Parse JSONB players array
                // Note: Supabase returns JSONB as either a parsed object or a string depending on the query
                let players: [MatchPlayer]
                
                if let playersString = json["players"] as? String {
                    // Case 1: players is a JSON string - convert to Data and decode
                    guard let playersJsonData = playersString.data(using: .utf8) else {
                        print("⚠️ Skipping match - could not convert players string to data")
                        continue
                    }
                    let decoder = JSONDecoder()
                    players = try decoder.decode([MatchPlayer].self, from: playersJsonData)
                    
                } else if let playersArray = json["players"] as? [[String: Any]] {
                    // Case 2: players is already parsed as an array - serialize and decode
                    let playersJsonData = try JSONSerialization.data(withJSONObject: playersArray)
                    let decoder = JSONDecoder()
                    players = try decoder.decode([MatchPlayer].self, from: playersJsonData)
                    
                } else {
                    print("⚠️ Skipping match - players data is neither string nor array")
                    continue
                }
                
                // Get optional fields
                let matchFormat = json["match_format"] as? Int ?? 1
                let totalLegsPlayed = json["total_legs_played"] as? Int ?? 1
                
                // Create MatchResult
                let match = MatchResult(
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
                
                matches.append(match)
            }
            
            print("✅ Loaded \(matches.count) matches from Supabase")
            return matches
            
        } catch {
            print("❌ Load matches failed: \(error)")
            print("   Error details: \(error.localizedDescription)")
            throw MatchSyncError.loadFailed
        }
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
