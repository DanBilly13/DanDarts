//
//  MatchSummary.swift
//  Dart Freak
//
//  Lightweight match summary for list display (no turn data)
//

import Foundation

struct MatchSummary: Identifiable, Codable, Hashable {
    let id: UUID
    let gameType: String
    let gameName: String
    let players: [MatchPlayer]  // Reuse MatchPlayer, built with forSummary()
    let winnerId: UUID
    let timestamp: Date
    let duration: TimeInterval
    let matchFormat: Int
    let totalLegsPlayed: Int
    let metadata: [String: String]?
    
    // Computed properties (same as MatchResult)
    var isPractice: Bool {
        players.count == 1
    }
    
    var winner: MatchPlayer? {
        players.first { $0.id == winnerId }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    init(id: UUID = UUID(),
         gameType: String,
         gameName: String,
         players: [MatchPlayer],
         winnerId: UUID,
         timestamp: Date = Date(),
         duration: TimeInterval,
         matchFormat: Int = 1,
         totalLegsPlayed: Int = 1,
         metadata: [String: String]? = nil) {
        self.id = id
        self.gameType = gameType
        self.gameName = gameName
        self.players = players
        self.winnerId = winnerId
        self.timestamp = timestamp
        self.duration = duration
        self.matchFormat = matchFormat
        self.totalLegsPlayed = totalLegsPlayed
        self.metadata = metadata
    }
    
    // Custom Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(gameType)
        hasher.combine(gameName)
        hasher.combine(players)
        hasher.combine(winnerId)
        hasher.combine(timestamp)
        hasher.combine(duration)
        hasher.combine(matchFormat)
        hasher.combine(totalLegsPlayed)
        hasher.combine(metadata?.keys.sorted())
        hasher.combine(metadata?.values.sorted())
    }
    
    // Custom Equatable implementation
    static func == (lhs: MatchSummary, rhs: MatchSummary) -> Bool {
        lhs.id == rhs.id &&
        lhs.gameType == rhs.gameType &&
        lhs.gameName == rhs.gameName &&
        lhs.players == rhs.players &&
        lhs.winnerId == rhs.winnerId &&
        lhs.timestamp == rhs.timestamp &&
        lhs.duration == rhs.duration &&
        lhs.matchFormat == rhs.matchFormat &&
        lhs.totalLegsPlayed == rhs.totalLegsPlayed &&
        lhs.metadata == rhs.metadata
    }
}
