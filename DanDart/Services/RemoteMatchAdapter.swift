//
//  RemoteMatchAdapter.swift
//  DanDart
//
//  Adapter to convert RemoteMatch objects to MatchResult for unified history
//

import Foundation

class RemoteMatchAdapter {
    
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
    ) -> MatchResult? {
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
        
        // Create MatchPlayer objects from challenger and receiver
        // Note: Turns array will be empty initially (Phase 6.3 will add turn data)
        let challengerPlayer = MatchPlayer(
            id: challenger.id,
            displayName: challenger.displayName,
            nickname: challenger.nickname,
            avatarURL: challenger.avatarURL,
            isGuest: false,
            finalScore: challengerScore,
            startingScore: startingScore,
            totalDartsThrown: 0, // Unknown without turn data
            turns: [], // Empty initially - Phase 6.3 will populate
            legsWon: 0 // Default to 0 for now
        )
        
        let receiverPlayer = MatchPlayer(
            id: receiver.id,
            displayName: receiver.displayName,
            nickname: receiver.nickname,
            avatarURL: receiver.avatarURL,
            isGuest: false,
            finalScore: receiverScore,
            startingScore: startingScore,
            totalDartsThrown: 0, // Unknown without turn data
            turns: [], // Empty initially - Phase 6.3 will populate
            legsWon: 0 // Default to 0 for now
        )
        
        // Create players array (challenger first, receiver second)
        let players = [challengerPlayer, receiverPlayer]
        
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
        
        print("✅ [RemoteMatchAdapter] Converted remote match \(id.uuidString.prefix(8))... to MatchResult")
        return matchResult
    }
}
