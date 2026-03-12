//
//  MatchesService.swift
//  Dart Freak
//
//  Service for syncing match results to Supabase
//

import Foundation
import Supabase

@MainActor
class MatchesService: ObservableObject {
    private let supabaseService = SupabaseService.shared
    
    // MARK: - Debug Helper
    
    @MainActor
    private func dbg(_ msg: String) {
        // print("🧩 [MatchDBG] \(msg)")  // Disabled for Phase 8 testing
    }
    
    // MARK: - Date Decoding Helpers
    
    private enum SupabaseDateDecoders {
        static let iso8601WithFractional: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()

        static func makeDecoder() -> JSONDecoder {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { dec in
                let c = try dec.singleValueContainer()

                // Supabase typically returns timestamps as ISO8601 strings
                if let s = try? c.decode(String.self),
                   let d = iso8601WithFractional.date(from: s) {
                    return d
                }

                // Some environments might return unix seconds
                if let t = try? c.decode(Double.self) {
                    return Date(timeIntervalSince1970: t)
                }

                throw DecodingError.dataCorruptedError(
                    in: c,
                    debugDescription: "Unsupported date format for Supabase timestamp"
                )
            }
            return decoder
        }
    }
    
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
            
            // Insert participants into match_participants table for fast queries
            try await insertMatchParticipants(matchId: match.id, players: match.players)
            
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
    
    /// Insert match participants into match_participants table
    /// - Parameters:
    ///   - matchId: The match ID
    ///   - players: Array of players in the match
    private func insertMatchParticipants(matchId: UUID, players: [MatchPlayer]) async throws {
        print("🔵 [Participants] Inserting \(players.count) participants for match \(matchId)")
        
        struct MatchParticipantInsert: Codable {
            let matchId: String
            let userId: String
            let isGuest: Bool
            let displayName: String
            
            enum CodingKeys: String, CodingKey {
                case matchId = "match_id"
                case userId = "user_id"
                case isGuest = "is_guest"
                case displayName = "display_name"
            }
        }
        
        let participants = players.map { player in
            print("   - \(player.displayName) (ID: \(player.id), Guest: \(player.isGuest))")
            return MatchParticipantInsert(
                matchId: matchId.uuidString,
                userId: player.id.uuidString,
                isGuest: player.isGuest,
                displayName: player.displayName
            )
        }
        
        do {
            let response = try await supabaseService.client
                .from("match_participants")
                .insert(participants)
                .execute()
            
            print("   ✅ Inserted \(participants.count) participants into match_participants table")
            print("   Response status: \(response.response.statusCode)")
        } catch {
            print("   ❌ Failed to insert match participants: \(error)")
            print("   Error details: \(error.localizedDescription)")
            // Don't throw - this is not critical for match sync
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
                
                // Parse metadata (for Halve-It difficulty, Killer player numbers, etc.)
                var metadata: [String: String]? = nil
                if let metadataDict = json["metadata"] as? [String: Any],
                   let gameMetadata = metadataDict["game_metadata"] as? [String: Any] {
                    metadata = gameMetadata.compactMapValues { $0 as? String }
                }
                
                dbg("[loadMatches] match=\(id.uuidString.prefix(8)) mode=\(json["match_mode"] as? String ?? "NULL") game=\(gameName)")
                dbg("[loadMatches] playersFromMatchesColumn count=\(basicPlayers.count) ids=\(basicPlayers.map{$0.id.uuidString.prefix(8)})")
                
                // Load turn data from match_throws table
                let playersWithTurns = try await loadTurnsForMatch(matchId: id, players: basicPlayers)
                
                dbg("[loadMatches] after loadTurnsForMatch turnsPerPlayer=\(playersWithTurns.map{$0.turns.count})")
                
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
    
    /// Load a single match by ID (optimized for GameEndView)
    func loadMatchById(_ matchId: UUID) async throws -> MatchResult? {
        print("🔍 [LoadMatchById] Fetching match \(matchId.uuidString.prefix(8))...")

        do {
            let response = try await supabaseService.client
                .from("matches")
                .select("""
                    id,
                    game_type,
                    game_name,
                    winner_id,
                    challenger_id,
                    receiver_id,
                    timestamp,
                    duration,
                    started_at,
                    ended_at,
                    players,
                    player_scores,
                    match_format,
                    total_legs_played,
                    metadata
                """)
                .eq("id", value: matchId.uuidString.lowercased())
                .single()
                .execute()

            let decoder = SupabaseDateDecoders.makeDecoder()
            let matchData = try decoder.decode(GameEndMatchData.self, from: response.data)

            print("✅ [LoadMatchById] Found match \(matchId.uuidString.prefix(8))")
            print("   - Game: \(matchData.gameName)")
            print("   - Duration: \(matchData.duration?.description ?? "NULL")")
            print("   - Winner ID: \(matchData.winnerId?.uuidString.prefix(8) ?? "NULL")...")
            
            dbg("[loadMatchById] match=\(matchId.uuidString.prefix(8))")
            dbg("[loadMatchById] embeddedPlayersCount=\(matchData.players?.count ?? 0)")
            dbg("[loadMatchById] challenger_id=\(matchData.challengerId?.uuidString ?? "NULL") receiver_id=\(matchData.receiverId?.uuidString ?? "NULL")")

            // Build players array with fallback strategies
            let players = try await buildPlayersFallback(matchData: matchData)
            
            dbg("[loadMatchById] playersBuiltCount=\(players.count) names=\(players.map{$0.displayName})")

            // Load turn-by-turn data from match_throws table
            let playersWithTurns = try await loadTurnsForMatch(matchId: matchData.id, players: players)

            // Debug: Verify turns were loaded
            let turnCounts = playersWithTurns.map { $0.turns.count }
            let totalTurns = turnCounts.reduce(0, +)
            print("📊 [LoadMatchById] Loaded turns per player: \(turnCounts), total: \(totalTurns)")

            // winner_id may be NULL but MatchResult currently requires a non-optional winnerId
            let winnerId = matchData.winnerId ?? UUID()   // placeholder for NULL winner_id

            // Duration: computed (0 if unavailable)
            let duration = TimeInterval(matchData.computedDurationSeconds ?? 0)

            let match = MatchResult(
                id: matchData.id,
                gameType: matchData.gameType,
                gameName: matchData.gameName,
                players: playersWithTurns,
                winnerId: winnerId,
                timestamp: matchData.timestamp,
                duration: duration,
                matchFormat: matchData.matchFormat ?? 1,
                totalLegsPlayed: matchData.totalLegsPlayed ?? 1,
                metadata: matchData.metadata
            )

            return match

        } catch {
            print("❌ [LoadMatchById] Failed to load match: \(error)")
            return nil
        }
    }

    /// Build players array with fallback strategies for remote matches
    private func buildPlayersFallback(matchData: GameEndMatchData) async throws -> [MatchPlayer] {
        dbg("[buildPlayersFallback] match=\(matchData.id.uuidString.prefix(8)) embedded=\(matchData.players?.count ?? 0)")
        
        // 1) If embedded players exists, use it
        if let embedded = matchData.players, !embedded.isEmpty {
            dbg("[buildPlayersFallback] Using embedded players from matches.players")
            return applyFinalScores(players: embedded, playerScores: matchData.playerScores)
        }

        // 2) Try match_participants table
        let matchId = matchData.id
        let participants = try await loadPlayersForMatch(matchId: matchId)
        dbg("[buildPlayersFallback] match_participants returned \(participants.count) players")
        if !participants.isEmpty {
            return applyFinalScores(players: participants, playerScores: matchData.playerScores)
        }

        // 3) Final fallback: synthesize from challenger/receiver IDs
        let ids = [matchData.challengerId, matchData.receiverId].compactMap { $0 }
        dbg("[buildPlayersFallback] Synthesizing players from challenger/receiver ids count=\(ids.count)")
        if ids.isEmpty {
            return []
        }

        // Try to fetch full profiles from users table
        let profiles = try await loadUserProfiles(userIds: ids)

        var synthetic: [MatchPlayer] = ids.map { id in
            let profile = profiles[id]
            let name = profile?.displayName ?? String(id.uuidString.prefix(8)) + "..."
            return MatchPlayer(
                id: id,
                displayName: name,
                nickname: profile?.nickname ?? "",
                avatarURL: profile?.avatarURL,
                isGuest: false,
                finalScore: 0,
                startingScore: 0,
                totalDartsThrown: 0,
                turns: [],
                legsWon: 0
            )
        }

        synthetic = applyFinalScores(players: synthetic, playerScores: matchData.playerScores)
        return synthetic
    }

    /// Apply final scores from player_scores map to players
    private func applyFinalScores(players: [MatchPlayer], playerScores: [String: Int]?) -> [MatchPlayer] {
        guard let playerScores else { return players }
        return players.map { p in
            // Check if we have a score for this player (try both lowercase and original UUID)
            if let score = playerScores[p.id.uuidString.lowercased()] ?? playerScores[p.id.uuidString] {
                // Create new MatchPlayer with updated finalScore
                return MatchPlayer(
                    id: p.id,
                    displayName: p.displayName,
                    nickname: p.nickname,
                    avatarURL: p.avatarURL,
                    isGuest: p.isGuest,
                    finalScore: score,
                    startingScore: p.startingScore,
                    totalDartsThrown: p.totalDartsThrown,
                    turns: p.turns,
                    legsWon: p.legsWon
                )
            }
            return p
        }
    }

    /// User profile data for match player reconstruction
    private struct UserProfile {
        let displayName: String
        let nickname: String
        let avatarURL: String?
    }

    /// Load user profiles from users table (display_name, nickname, avatar_url)
    private func loadUserProfiles(userIds: [UUID]) async throws -> [UUID: UserProfile] {
        let response = try await supabaseService.client
            .from("users")
            .select("id, display_name, nickname, avatar_url")
            .in("id", values: userIds.map { $0.uuidString.lowercased() })
            .execute()

        guard let rows = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
            return [:]
        }

        var map: [UUID: UserProfile] = [:]
        for r in rows {
            guard
                let idStr = r["id"] as? String,
                let id = UUID(uuidString: idStr),
                let displayName = r["display_name"] as? String
            else { continue }
            
            let nickname = r["nickname"] as? String ?? ""
            let avatarURL = r["avatar_url"] as? String
            
            map[id] = UserProfile(
                displayName: displayName,
                nickname: nickname,
                avatarURL: avatarURL
            )
        }
        return map
    }

    /// Load players from match_participants table (fallback when matches.players is NULL/empty)
    private func loadPlayersForMatch(matchId: UUID) async throws -> [MatchPlayer] {
        let response = try await supabaseService.client
            .from("match_participants")
            .select("user_id, display_name, is_guest")
            .eq("match_id", value: matchId.uuidString.lowercased())
            .execute()

        guard let participantsJson = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
            return []
        }

        return participantsJson.compactMap { json in
            guard
                let userIdString = json["user_id"] as? String,
                let userId = UUID(uuidString: userIdString),
                let displayName = json["display_name"] as? String
            else { return nil }

            let isGuest = json["is_guest"] as? Bool ?? false

            return MatchPlayer(
                id: userId,
                displayName: displayName,
                nickname: "",
                avatarURL: nil,
                isGuest: isGuest,
                finalScore: 0,
                startingScore: 0,
                totalDartsThrown: 0,
                turns: [],
                legsWon: 0
            )
        }
    }
    
    /// DEBUG: Minimal throws fetch to isolate PostgrestError 22023
    private func debugMinimalThrowsFetch(matchId: UUID) async {
        dbg("========== [debugMinimalThrowsFetch] START match=\(matchId.uuidString) ==========")
        
        do {
            // IMPORTANT: select ONLY raw columns, no computed fields, no embeds
            let res = try await supabaseService.client
                .from("match_throws")
                .select("id,match_id,player_order,turn_index,throws")
                .eq("match_id", value: matchId.uuidString)
                .order("player_order", ascending: true)
                .order("turn_index", ascending: true)
                .execute()
            
            // Print raw JSON so we can see exactly what PostgREST returned
            if let jsonString = String(data: res.data, encoding: .utf8) {
                dbg("[debugMinimalThrowsFetch] RAW JSON: \(jsonString)")
            } else {
                dbg("[debugMinimalThrowsFetch] Could not decode response as UTF8 string")
            }
            
            dbg("========== [debugMinimalThrowsFetch] END OK ==========")
        } catch {
            dbg("========== [debugMinimalThrowsFetch] END ERROR ==========")
            dbg("[debugMinimalThrowsFetch] error=\(error)")
        }
    }
    
    /// Load turn data for a specific match from match_throws table
    /// - Parameters:
    ///   - matchId: The match ID
    ///   - players: Basic player data (without turns)
    /// - Returns: Players with complete turn data
    private func loadTurnsForMatch(matchId: UUID, players: [MatchPlayer]) async throws -> [MatchPlayer] {
        // print("🔍 [LoadTurnsForMatch] Loading turns for match \(matchId.uuidString.prefix(8))...")
        // print("   Input players: \(players.map { "\($0.displayName)" })")
        dbg("[loadTurnsForMatch] match=\(matchId.uuidString.prefix(8)) inputPlayersCount=\(players.count)")
        
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
            print("⚠️ [LoadTurnsForMatch] Failed to query turn data for match \(matchId): \(error)")
            print("   Error details: \(error.localizedDescription)")
            dbg("[loadTurnsForMatch] CURRENT SELECT STRING: id,match_id,player_order,turn_index,throws,score_before,score_after,is_bust,game_metadata")
            
            // DEBUG: Try minimal query to isolate the issue
            await debugMinimalThrowsFetch(matchId: matchId)
            
            return players
        }
        
        // Parse throws data
        guard let throwsArray = try? JSONSerialization.jsonObject(with: response) as? [[String: Any]] else {
            print("⚠️ [LoadTurnsForMatch] No turn data found for match \(matchId), returning players with empty turns")
            return players
        }
        
        // print("📊 [LoadTurnsForMatch] Found \(throwsArray.count) throw records")
        dbg("[loadTurnsForMatch] match=\(matchId.uuidString.prefix(8)) throwsRows=\(throwsArray.count)")
        
        // Group throws by player_order
        var playerTurns: [Int: [MatchTurn]] = [:]
        
        for throwJson in throwsArray {
            guard let playerOrder = throwJson["player_order"] as? Int,
                  let turnIndex = throwJson["turn_index"] as? Int,
                  let scoreBefore = throwJson["score_before"] as? Int,
                  let scoreAfter = throwJson["score_after"] as? Int else {
                print("⚠️ [LoadTurnsForMatch] Skipping turn - missing required fields")
                continue
            }
            
            // Parse throws - handle multiple formats
            let dartScores: [Int]
            if let throwsArray = throwJson["throws"] as? [Int] {
                dartScores = throwsArray
            } else if let throwsArray = throwJson["throws"] as? [Any] {
                dartScores = throwsArray.compactMap { $0 as? Int }
            } else {
                print("⚠️ [LoadTurnsForMatch] Skipping turn - could not parse throws data")
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
        
        // print("📊 [LoadTurnsForMatch] Grouped turns by player_order:")
        // for (order, turns) in playerTurns.sorted(by: { $0.key < $1.key }) {
        //     print("   player_order \(order): \(turns.count) turns")
        // }
        
        dbg("[loadTurnsForMatch] match=\(matchId.uuidString.prefix(8)) groupedOrders=\(playerTurns.keys.sorted()) counts=\(playerTurns.keys.sorted().map{ playerTurns[$0]?.count ?? 0 })")
        if players.isEmpty && !throwsArray.isEmpty {
            dbg("[loadTurnsForMatch][⚠️] Players EMPTY but throwsRows=\(throwsArray.count) -> UI will be blank.")
        }
        
        // Reconstruct players with turn data
        var playersWithTurns: [MatchPlayer] = []
        for (index, player) in players.enumerated() {
            let turns = playerTurns[index] ?? []
            // print("   Mapping player[\(index)] '\(player.displayName)' to player_order \(index): \(turns.count) turns")
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
        
        // print("✅ [LoadTurnsForMatch] Returning \(playersWithTurns.count) players with turns")
        return playersWithTurns
    }
    
    // MARK: - Optimized Query Methods (Using match_participants table)
    
    /// Load head-to-head matches between two users (OPTIMIZED)
    /// Uses match_participants table for fast filtering
    /// - Parameters:
    ///   - userId: Current user's ID
    ///   - friendId: Friend's user ID
    ///   - limit: Maximum number of matches to return (default 50)
    /// - Returns: Array of match results
    func loadHeadToHeadMatchesOptimized(userId: UUID, friendId: UUID, limit: Int = 50) async throws -> [MatchResult] {
        let startTime = Date()
        print("🚀 [H2H Optimized] Loading matches between \(userId) and \(friendId)")
        
        do {
            // Step 1: Find match IDs where BOTH users participated (using match_participants table)
            let participantsResponse = try await supabaseService.client
                .from("match_participants")
                .select("match_id")
                .eq("user_id", value: userId.uuidString)
                .eq("is_guest", value: false)
                .execute()
            
            guard let userMatchesJson = try? JSONSerialization.jsonObject(with: participantsResponse.data) as? [[String: Any]] else {
                print("✅ [H2H Optimized] No matches found for user")
                return []
            }
            
            let userMatchIds = Set(userMatchesJson.compactMap { ($0["match_id"] as? String).flatMap(UUID.init) })
            
            // Get friend's match IDs
            let friendParticipantsResponse = try await supabaseService.client
                .from("match_participants")
                .select("match_id")
                .eq("user_id", value: friendId.uuidString)
                .eq("is_guest", value: false)
                .execute()
            
            guard let friendMatchesJson = try? JSONSerialization.jsonObject(with: friendParticipantsResponse.data) as? [[String: Any]] else {
                print("✅ [H2H Optimized] No matches found for friend")
                return []
            }
            
            let friendMatchIds = Set(friendMatchesJson.compactMap { ($0["match_id"] as? String).flatMap(UUID.init) })
            
            // Find intersection (matches where BOTH participated)
            let commonMatchIds = Array(userMatchIds.intersection(friendMatchIds))
            
            guard !commonMatchIds.isEmpty else {
                print("✅ [H2H Optimized] No head-to-head matches found")
                return []
            }
            
            print("   Found \(commonMatchIds.count) head-to-head match IDs")
            
            // Step 2: Load match details for these IDs (with limit)
            let limitedMatchIds = Array(commonMatchIds.prefix(limit))
            let matches = try await loadMatchesByIds(limitedMatchIds)
            
            let duration = Date().timeIntervalSince(startTime)
            print("✅ [H2H Optimized] Loaded \(matches.count) matches in \(String(format: "%.2f", duration))s")
            
            return matches.sorted { $0.timestamp > $1.timestamp }
            
        } catch {
            print("❌ [H2H Optimized] Load failed: \(error)")
            throw MatchSyncError.loadFailed
        }
    }
    
    /// Load matches by specific match IDs with batched turn data loading
    /// - Parameter matchIds: Array of match IDs to load
    /// - Returns: Array of match results with turn data
    private func loadMatchesByIds(_ matchIds: [UUID]) async throws -> [MatchResult] {
        guard !matchIds.isEmpty else { return [] }
        
        print("   Loading \(matchIds.count) matches by ID...")
        
        // Step 1: Load match metadata (WITHOUT players column to avoid double-encoded JSON issue)
        let matchIdsStrings = matchIds.map { $0.uuidString }
        let matchesResponse = try await supabaseService.client
            .from("matches")
            .select("id, game_type, game_name, winner_id, timestamp, duration, match_format, total_legs_played, metadata")
            .in("id", values: matchIdsStrings)
            .execute()
        
        guard let matchesJson = try? JSONSerialization.jsonObject(with: matchesResponse.data) as? [[String: Any]] else {
            print("   No matches found")
            return []
        }
        
        // Step 1b: Load participants for these matches from match_participants table
        let participantsResponse = try await supabaseService.client
            .from("match_participants")
            .select("match_id, user_id, is_guest, display_name")
            .in("match_id", values: matchIdsStrings)
            .execute()
        
        guard let participantsJson = try? JSONSerialization.jsonObject(with: participantsResponse.data) as? [[String: Any]] else {
            print("   No participants found")
            return []
        }
        
        // Group participants by match_id
        var participantsByMatch: [UUID: [[String: Any]]] = [:]
        for participantJson in participantsJson {
            guard let matchIdString = participantJson["match_id"] as? String,
                  let matchId = UUID(uuidString: matchIdString) else {
                continue
            }
            
            if participantsByMatch[matchId] == nil {
                participantsByMatch[matchId] = []
            }
            participantsByMatch[matchId]?.append(participantJson)
        }
        
        print("   Loaded \(participantsJson.count) participants from match_participants table")
        dbg("[loadMatchesByIds] Loaded participants for \(participantsByMatch.count) matches")
        
        // Step 2: Batch-load ALL turn data for these matches in ONE query
        let turnsResponse = try await supabaseService.client
            .from("match_throws")
            .select("id,match_id,player_order,turn_index,throws,score_before,score_after,is_bust,game_metadata")
            .in("match_id", values: matchIdsStrings)
            .order("player_order")
            .order("turn_index")
            .execute()
        
        guard let turnsJson = try? JSONSerialization.jsonObject(with: turnsResponse.data) as? [[String: Any]] else {
            print("   No turn data found")
            return []
        }
        
        print("   Loaded \(turnsJson.count) turns in batch")
        
        // Step 3: Group turns by match_id
        var turnsByMatch: [UUID: [[String: Any]]] = [:]
        for turnJson in turnsJson {
            guard let matchIdString = turnJson["match_id"] as? String,
                  let matchId = UUID(uuidString: matchIdString) else {
                continue
            }
            
            if turnsByMatch[matchId] == nil {
                turnsByMatch[matchId] = []
            }
            turnsByMatch[matchId]?.append(turnJson)
        }
        
        // Step 4: Build MatchResult objects with turns
        var matches: [MatchResult] = []
        
        for json in matchesJson {
            guard let idString = json["id"] as? String,
                  let id = UUID(uuidString: idString) else {
                continue
            }
            
            guard let gameType = json["game_type"] as? String else {
                continue
            }
            
            guard let gameName = json["game_name"] as? String else {
                continue
            }
            
            guard let winnerIdString = json["winner_id"] as? String,
                  let winnerId = UUID(uuidString: winnerIdString) else {
                continue
            }
            
            guard let timestampString = json["timestamp"] as? String else {
                continue
            }
            
            let duration = json["duration"] as? Int
            let participantsData = participantsByMatch[id] ?? []
            let turnsForMatch = turnsByMatch[id] ?? []
            
            // Parse timestamp - support both formats (with and without fractional seconds)
            // Remote matches: 2026-03-12T13:07:10.529551+00:00
            // Local matches: 2026-03-11T07:57:35+00:00
            let timestamp: Date
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let parsedDate = fractionalFormatter.date(from: timestampString) {
                timestamp = parsedDate
            } else if let parsedDate = ISO8601DateFormatter().date(from: timestampString) {
                timestamp = parsedDate
            } else {
                continue
            }
            
            let matchFormat = json["match_format"] as? Int ?? 1
            let totalLegsPlayed = json["total_legs_played"] as? Int ?? 1
            
            // Build players from match_participants data
            var basicPlayers = participantsData.compactMap { participantJson -> MatchPlayer? in
                guard let userIdString = participantJson["user_id"] as? String,
                      let userId = UUID(uuidString: userIdString),
                      let displayName = participantJson["display_name"] as? String else {
                    return nil
                }
                
                let isGuest = participantJson["is_guest"] as? Bool ?? false
                
                return MatchPlayer(
                    id: userId,
                    displayName: displayName,
                    nickname: "",
                    avatarURL: nil,
                    isGuest: isGuest,
                    finalScore: 0,
                    startingScore: 0,
                    totalDartsThrown: 0,
                    turns: [],
                    legsWon: 0
                )
            }
            
            if basicPlayers.isEmpty {
                continue
            }
            
            dbg("[loadMatchesByIds] match=\(id.uuidString.prefix(8)) participantsRows=\(participantsData.count) basicPlayers=\(basicPlayers.count)")
            
            // FALLBACK: If no participants (old local matches), try to load from matches.players column
            if basicPlayers.isEmpty {
                dbg("[loadMatchesByIds][WARN] match=\(id.uuidString.prefix(8)) participants=0, trying matches.players fallback")
                
                // Try to parse players from the matches.players column (stored as JSON string)
                if let playersString = json["players"] as? String,
                   let playersData = playersString.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    if let embeddedPlayers = try? decoder.decode([MatchPlayer].self, from: playersData) {
                        basicPlayers = embeddedPlayers
                        dbg("[loadMatchesByIds][WARN] matches.players fallback SUCCESS count=\(basicPlayers.count)")
                    } else {
                        dbg("[loadMatchesByIds][ERROR] matches.players fallback FAILED - could not decode")
                    }
                }
            }
            
            // Get metadata
            var metadata: [String: String] = [:]
            if let gameMetadata = json["metadata"] as? [String: Any] {
                metadata = gameMetadata.compactMapValues { $0 as? String }
            }
            
            // Get turns for this match
            let matchTurns = turnsByMatch[id] ?? []
            dbg("[loadMatchesByIds] match=\(id.uuidString.prefix(8)) turnsRows=\(matchTurns.count)")
            let playersWithTurns = buildPlayersWithTurns(players: basicPlayers, turnsJson: matchTurns)
            dbg("[loadMatchesByIds] match=\(id.uuidString.prefix(8)) returned turnsPerPlayer=\(playersWithTurns.map{$0.turns.count}) players=\(playersWithTurns.map{$0.displayName})")
            
            let match = MatchResult(
                id: id,
                gameType: gameType,
                gameName: gameName,
                players: playersWithTurns,
                winnerId: winnerId,
                timestamp: timestamp,
                duration: TimeInterval(duration ?? 0),
                matchFormat: matchFormat,
                totalLegsPlayed: totalLegsPlayed,
                metadata: metadata
            )
            
            matches.append(match)
        }
        
        return matches
    }
    
    /// Build players with turn data from JSON
    private func buildPlayersWithTurns(players: [MatchPlayer], turnsJson: [[String: Any]]) -> [MatchPlayer] {
        // Group turns by player_order
        var playerTurns: [Int: [MatchTurn]] = [:]
        
        for turnJson in turnsJson {
            guard let playerOrder = turnJson["player_order"] as? Int,
                  let turnIndex = turnJson["turn_index"] as? Int,
                  let scoreBefore = turnJson["score_before"] as? Int,
                  let scoreAfter = turnJson["score_after"] as? Int else {
                continue
            }
            
            // Parse throws
            let dartScores: [Int]
            if let throwsArray = turnJson["throws"] as? [Int] {
                dartScores = throwsArray
            } else if let throwsArray = turnJson["throws"] as? [Any] {
                dartScores = throwsArray.compactMap { $0 as? Int }
            } else {
                continue
            }
            
            // Get metadata
            var targetDisplay: String? = nil
            var killerDartsMetadataMap: [Int: [String: Any]] = [:]
            if let gameMetadata = turnJson["game_metadata"] as? [String: Any] {
                if let target = gameMetadata["target_display"] as? String {
                    targetDisplay = target
                }
                if let killerDartsJson = gameMetadata["killer_darts"] as? String,
                   let jsonData = killerDartsJson.data(using: .utf8),
                   let dartsArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                    for dartMeta in dartsArray {
                        if let dartIndex = dartMeta["dart_index"] as? Int {
                            killerDartsMetadataMap[dartIndex] = dartMeta
                        }
                    }
                }
            }
            
            let isBust = turnJson["is_bust"] as? Bool ?? false
            
            // Convert to MatchDart objects
            let darts = dartScores.enumerated().map { index, score -> MatchDart in
                var killerMetadata: KillerDartMetadata? = nil
                if let dartMeta = killerDartsMetadataMap[index] {
                    if let outcomeStr = dartMeta["outcome"] as? String,
                       let outcome = KillerDartMetadata.KillerDartOutcome(rawValue: outcomeStr) {
                        let affectedIds = (dartMeta["affected_player_ids"] as? [String] ?? []).compactMap { UUID(uuidString: $0) }
                        killerMetadata = KillerDartMetadata(outcome: outcome, affectedPlayerIds: affectedIds)
                    }
                }
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
    
    /// Parse players array from JSON (handles double-encoded JSON)
    private func parsePlayersFromJson(_ playersData: Any?) -> [MatchPlayer] {
        guard let playersData = playersData else { return [] }
        
        var playersArray: [[String: Any]] = []
        
        // Try to parse as array directly
        if let array = playersData as? [[String: Any]] {
            playersArray = array
        }
        // Try to parse as JSON string (double-encoded)
        else if let jsonString = playersData as? String,
                let jsonData = jsonString.data(using: .utf8),
                let array = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
            playersArray = array
        }
        
        return playersArray.compactMap { playerJson in
            guard let idString = playerJson["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let displayName = playerJson["displayName"] as? String else {
                return nil
            }
            
            let nickname = playerJson["nickname"] as? String ?? ""
            let avatarURL = playerJson["avatarURL"] as? String
            let isGuestString = playerJson["isGuest"] as? String
            let isGuest = (isGuestString == "true") || (playerJson["isGuest"] as? Bool == true)
            let legsWon = playerJson["legsWon"] as? Int ?? 0
            
            return MatchPlayer(
                id: id,
                displayName: displayName,
                nickname: nickname,
                avatarURL: avatarURL,
                isGuest: isGuest,
                finalScore: 0,
                startingScore: 0,
                totalDartsThrown: 0,
                turns: [],
                legsWon: legsWon
            )
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

// MARK: - GameEnd Match Data

/// Lightweight match data for GameEndView (tolerates NULL fields)
struct GameEndMatchData: Decodable {
    let id: UUID
    let gameType: String
    let gameName: String
    let winnerId: UUID?               // may be NULL
    let timestamp: Date

    let duration: Int?                // may be NULL
    let startedAt: Date?              // may be NULL
    let endedAt: Date?                // may be NULL

    let players: [MatchPlayer]?       // may be NULL
    let playerScores: [String: Int]?  // remote matches store this

    let matchFormat: Int?
    let totalLegsPlayed: Int?

    // Codable-safe: only string->string metadata
    let metadata: [String: String]?

    // Remote match player IDs
    let challengerId: UUID?
    let receiverId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, timestamp, duration, players, metadata
        case gameType = "game_type"
        case gameName = "game_name"
        case winnerId = "winner_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case playerScores = "player_scores"
        case matchFormat = "match_format"
        case totalLegsPlayed = "total_legs_played"
        case challengerId = "challenger_id"
        case receiverId = "receiver_id"
    }

    /// Compute duration from timestamps if not stored
    var computedDurationSeconds: Int? {
        if let duration { return duration }
        if let start = startedAt, let end = endedAt {
            return Int(end.timeIntervalSince(start))
        }
        return nil
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
