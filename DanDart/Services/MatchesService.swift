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
            // Query matches where user is a participant
            let supabaseMatches: [SupabaseMatch] = try await supabaseService.client
                .from("matches")
                .select()
                .order("timestamp", ascending: false)
                .execute()
                .value
            
            // Convert to MatchResult
            let matches = supabaseMatches.map { $0.toMatchResult() }
            
            print("✅ Loaded \(matches.count) matches from Supabase")
            return matches
            
        } catch {
            print("❌ Load matches failed: \(error)")
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
    let syncedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case gameType = "game_type"
        case gameName = "game_name"
        case winnerId = "winner_id"
        case timestamp
        case duration
        case players
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
            duration: TimeInterval(duration)
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
