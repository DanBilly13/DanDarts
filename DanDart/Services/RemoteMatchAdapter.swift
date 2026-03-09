//
//  RemoteMatchAdapter.swift
//  DanDart
//
//  Adapter to convert RemoteMatch objects to MatchResult for unified history
//

import Foundation

class RemoteMatchAdapter {
    private let supabaseService = SupabaseService.shared
    
    /// Convert a completed RemoteMatch to MatchResult for unified history display
    /// - Parameters:
    ///   - remoteMatch: The remote match to convert
    ///   - challenger: The challenger user
    ///   - receiver: The receiver user
    /// - Returns: MatchResult if conversion successful, nil if match incomplete
    func convertToMatchResult(
        remoteMatch: RemoteMatch,
        challenger: User,
        receiver: User
    ) async -> MatchResult? {
        // Only convert completed matches with winner
        guard remoteMatch.status == .completed,
              let winnerId = remoteMatch.winnerId,
              let endedAt = remoteMatch.endedAt else {
            print("⚠️ [RemoteMatchAdapter] Cannot convert incomplete match: status=\(remoteMatch.status?.rawValue ?? "nil"), winnerId=\(remoteMatch.winnerId?.uuidString.prefix(8) ?? "nil")")
            return nil
        }
        
        // Map fields from RemoteMatch to MatchResult
        let id = remoteMatch.id
        let gameType = remoteMatch.gameType // "301" or "501"
        let gameName = remoteMatch.gameName // "301" or "501"
        let timestamp = endedAt
        let duration = endedAt.timeIntervalSince(remoteMatch.createdAt)
        let matchFormat = remoteMatch.matchFormat
        
        // CRITICAL: Add remote flag to metadata
        let metadata = ["isRemote": "true"]
        
        // Get final scores from playerScores (server-authoritative)
        let challengerScore = remoteMatch.playerScores?[challenger.id] ?? 0
        let receiverScore = remoteMatch.playerScores?[receiver.id] ?? 0
        
        // Determine starting score based on game type
        let startingScore: Int
        if gameType == "301" {
            startingScore = 301
        } else if gameType == "501" {
            startingScore = 501
        } else {
            startingScore = 501 // Default fallback
        }
        
        // Create basic MatchPlayer objects (without turn data)
        let basicChallenger = MatchPlayer(
            id: challenger.id,
            displayName: challenger.displayName,
            nickname: challenger.nickname,
            avatarURL: challenger.avatarURL,
            isGuest: false,
            finalScore: challengerScore,
            startingScore: startingScore,
            totalDartsThrown: 0,
            turns: [],
            legsWon: 0
        )
        
        let basicReceiver = MatchPlayer(
            id: receiver.id,
            displayName: receiver.displayName,
            nickname: receiver.nickname,
            avatarURL: receiver.avatarURL,
            isGuest: false,
            finalScore: receiverScore,
            startingScore: startingScore,
            totalDartsThrown: 0,
            turns: [],
            legsWon: 0
        )
        
        // Load turn data from match_throws table
        let basicPlayers = [basicChallenger, basicReceiver]
        let playersWithTurns = await loadTurnsForRemoteMatch(matchId: id, players: basicPlayers)
        
        // Use players with turn data
        let players = playersWithTurns
        
        // Calculate total legs played (default to 1 for now)
        // TODO: Calculate from actual legs data if available in future
        let totalLegsPlayed = 1
        
        // Create and return MatchResult
        let matchResult = MatchResult(
            id: id,
            gameType: gameType,
            gameName: gameName,
            players: players,
            winnerId: winnerId,
            timestamp: timestamp,
            duration: duration,
            matchFormat: matchFormat,
            totalLegsPlayed: totalLegsPlayed,
            metadata: metadata
        )
        
        print("✅ [RemoteMatchAdapter] Converted remote match \(id.uuidString.prefix(8))... to MatchResult with \(players.first?.turns.count ?? 0) turns")
        return matchResult
    }
    
    /// Load turn data for a remote match from match_throws table
    /// - Parameters:
    ///   - matchId: The match ID
    ///   - players: Basic player data (without turns)
    /// - Returns: Players with complete turn data
    private func loadTurnsForRemoteMatch(matchId: UUID, players: [MatchPlayer]) async -> [MatchPlayer] {
        print("🔍 [RemoteMatchAdapter] Loading turns for match \(matchId.uuidString.prefix(8))...")
        
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
            print("⚠️ [RemoteMatchAdapter] Failed to query turn data: \(error)")
            print("   Error details: \(error.localizedDescription)")
            return players
        }
        
        // Parse throws data
        guard let throwsArray = try? JSONSerialization.jsonObject(with: response) as? [[String: Any]] else {
            print("⚠️ [RemoteMatchAdapter] No turn data found, returning players with empty turns")
            return players
        }
        
        print("📊 [RemoteMatchAdapter] Found \(throwsArray.count) throw records")
        
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
                print("⚠️ [RemoteMatchAdapter] Skipping turn - could not parse throws data")
                continue
            }
            
            // Get game_metadata (for Halve-It target display)
            var targetDisplay: String? = nil
            if let gameMetadata = throwJson["game_metadata"] as? [String: Any] {
                if let target = gameMetadata["target_display"] as? String {
                    targetDisplay = target
                }
            }
            
            // Get is_bust flag (for Knockout life losses)
            let isBust = throwJson["is_bust"] as? Bool ?? false
            
            // Convert dart scores to MatchDart objects
            let darts = dartScores.map { score -> MatchDart in
                // For remote matches, we store total score per dart
                // Assume singles for now (limitation of current data model)
                return MatchDart(baseValue: score, multiplier: 1, killerMetadata: nil)
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
        
        print("✅ [RemoteMatchAdapter] Loaded \(playerTurns.values.flatMap { $0 }.count) total turns for \(players.count) players")
        return playersWithTurns
    }
}
