//
//  RemoteMatch.swift
//  DanDart
//
//  Remote match models for live multiplayer
//

import Foundation

// Note: User type is defined in User.swift and will be available at runtime

// MARK: - Remote Match Status

enum RemoteMatchStatus: String, Codable, CaseIterable {
    case pending
    case sent
    case ready
    case lobby
    case inProgress = "in_progress"
    case completed
    case expired
    case cancelled
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .sent: return "Sent"
        case .ready: return "Ready"
        case .lobby: return "Lobby"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .expired: return "Expired"
        case .cancelled: return "Cancelled"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .ready, .lobby, .inProgress: return true
        case .pending, .sent, .completed, .expired, .cancelled: return false
        }
    }
    
    var isFinished: Bool {
        switch self {
        case .completed, .expired, .cancelled: return true
        case .pending, .sent, .ready, .lobby, .inProgress: return false
        }
    }
}

// MARK: - Remote Match Model

struct RemoteMatch: Identifiable, Codable {
    let id: UUID
    let matchMode: String // 'local' | 'remote'
    let gameType: String // '301' | '501'
    let gameName: String
    let matchFormat: Int // 1, 3, 5, or 7 legs
    
    // Remote-specific fields
    let challengerId: UUID
    let receiverId: UUID
    var status: RemoteMatchStatus?
    var currentPlayerId: UUID?
    
    // Expiry timestamps
    let challengeExpiresAt: Date?
    let joinWindowExpiresAt: Date?
    
    // Game state
    var lastVisitPayload: LastVisitPayload?
    
    // Match metadata
    let createdAt: Date
    let updatedAt: Date
    
    // Computed properties
    var isChallenger: Bool {
        // Will be set by service when loading
        false
    }
    
    var isReceiver: Bool {
        // Will be set by service when loading
        false
    }
    
    var opponentId: UUID {
        // Will be determined by service based on current user
        challengerId
    }
    
    var isExpired: Bool {
        // If we have a join window, it applies to states where we're waiting on something time-bound
        if let expiresAt = joinWindowExpiresAt, status == .ready || status == .lobby || status == .sent {
            return Date() > expiresAt
        }
        // Otherwise fall back to the broader challenge expiry (typically for pending inbound)
        if let expiresAt = challengeExpiresAt, status == .pending {
            return Date() > expiresAt
        }
        return false
    }
    
    var timeRemaining: TimeInterval? {
        if let expiresAt = joinWindowExpiresAt, status == .ready || status == .lobby || status == .sent {
            return max(0, expiresAt.timeIntervalSinceNow)
        }
        if let expiresAt = challengeExpiresAt, status == .pending {
            return max(0, expiresAt.timeIntervalSinceNow)
        }
        return nil
    }
    
    var formattedTimeRemaining: String {
        guard let remaining = timeRemaining else { return "" }
        
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case matchMode = "match_mode"
        case gameType = "game_type"
        case gameName = "game_name"
        case matchFormat = "match_format"
        case challengerId = "challenger_id"
        case receiverId = "receiver_id"
        case status = "remote_status"
        case currentPlayerId = "current_player_id"
        case challengeExpiresAt = "challenge_expires_at"
        case joinWindowExpiresAt = "join_window_expires_at"
        case lastVisitPayload = "last_visit_payload"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Last Visit Payload

struct LastVisitPayload: Codable {
    let playerId: UUID
    let darts: [Int] // Array of dart scores
    let scoreBefore: Int
    let scoreAfter: Int
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case darts
        case scoreBefore = "score_before"
        case scoreAfter = "score_after"
        case timestamp
    }
}

// MARK: - Remote Match Lock

struct RemoteMatchLock: Codable {
    let userId: UUID
    let matchId: UUID
    let lockStatus: String // 'ready' | 'in_progress'
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case matchId = "match_id"
        case lockStatus = "lock_status"
        case updatedAt = "updated_at"
    }
}

// MARK: - Push Token

struct PushToken: Codable {
    let userId: UUID
    let token: String
    let platform: String // 'ios' | 'android'
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case token
        case platform
        case updatedAt = "updated_at"
    }
}

// MARK: - Remote Match with Players

struct RemoteMatchWithPlayers: Identifiable {
    let match: RemoteMatch
    let challenger: User
    let receiver: User
    let currentUserId: UUID
    
    var id: UUID { match.id }
    
    var opponent: User {
        currentUserId == match.challengerId ? receiver : challenger
    }
    
    var isMyTurn: Bool {
        match.currentPlayerId == currentUserId
    }
    
    var myRole: PlayerRole {
        currentUserId == match.challengerId ? .challenger : .receiver
    }
    
    enum PlayerRole {
        case challenger // Red
        case receiver   // Green
        
        var color: String {
            switch self {
            case .challenger: return "player1" // Red
            case .receiver: return "player2"   // Green
            }
        }
        
        var displayName: String {
            switch self {
            case .challenger: return "Challenger"
            case .receiver: return "Receiver"
            }
        }
    }
}

// MARK: - Remote Match Error

enum RemoteMatchError: Error {
    case notAuthenticated
    case notAuthorized
    case invalidStatus
    case matchExpired
    case alreadyHasActiveMatch
    case lockCreationFailed
    case databaseError(String)
    case edgeFunctionError(String)
}

// MARK: - Edge Function Response Types

struct EmptyResponse: Decodable {
    // Empty response for Edge Functions that don't return data
}

// MARK: - Mock Data

extension RemoteMatch {
    static let mockPending = RemoteMatch(
        id: UUID(),
        matchMode: "remote",
        gameType: "301",
        gameName: "301",
        matchFormat: 3,
        challengerId: UUID(),
        receiverId: UUID(),
        status: .pending,
        currentPlayerId: nil,
        challengeExpiresAt: Date().addingTimeInterval(86400), // 24 hours
        joinWindowExpiresAt: nil,
        lastVisitPayload: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    static let mockReady = RemoteMatch(
        id: UUID(),
        matchMode: "remote",
        gameType: "501",
        gameName: "501",
        matchFormat: 1,
        challengerId: UUID(),
        receiverId: UUID(),
        status: .ready,
        currentPlayerId: nil,
        challengeExpiresAt: nil,
        joinWindowExpiresAt: Date().addingTimeInterval(300), // 5 minutes
        lastVisitPayload: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    static let mockInProgress = RemoteMatch(
        id: UUID(),
        matchMode: "remote",
        gameType: "301",
        gameName: "301",
        matchFormat: 5,
        challengerId: UUID(),
        receiverId: UUID(),
        status: .inProgress,
        currentPlayerId: UUID(),
        challengeExpiresAt: nil,
        joinWindowExpiresAt: nil,
        lastVisitPayload: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
}
