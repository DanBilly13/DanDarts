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
    case sent // UI-only state for outgoing pending challenges (not in database)
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

struct RemoteMatch: Identifiable, Equatable, Decodable {
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
    
    // Lobby presence tracking
    let challengerLobbyJoinedAt: Date?
    let receiverLobbyJoinedAt: Date?
    let lobbyCountdownStartedAt: Date?
    let lobbyCountdownSeconds: Int?
    
    // Game state
    var lastVisitPayload: LastVisitPayload?
    var playerScores: [UUID: Int]? // Server-authoritative scores {player_id: score}
    var turnIndexInLeg: Int? // Server-authoritative turn counter (0-indexed, display as +1)
    
    // Match metadata
    let createdAt: Date
    let updatedAt: Date
    
    // Termination tracking (optional)
    let endedBy: UUID?
    let endedReason: String?
    let winnerId: UUID? // Winner of the match (set when status = completed)
    let endedAt: Date?
    
    // Debug counter for Phase 2 testing (DEBUG only)
    var debugCounter: Int?
    
    // MARK: - Equatable Conformance
    
    /// Custom equality that compares only game-state fields, ignoring timestamps
    /// to prevent unnecessary SwiftUI updates when server timestamps change
    static func == (lhs: RemoteMatch, rhs: RemoteMatch) -> Bool {
        lhs.id == rhs.id &&
        lhs.status == rhs.status &&
        lhs.currentPlayerId == rhs.currentPlayerId &&
        lhs.playerScores == rhs.playerScores &&
        lhs.turnIndexInLeg == rhs.turnIndexInLeg &&
        lhs.lastVisitPayload == rhs.lastVisitPayload &&
        lhs.endedBy == rhs.endedBy &&
        lhs.endedReason == rhs.endedReason &&
        lhs.winnerId == rhs.winnerId &&
        lhs.challengerLobbyJoinedAt == rhs.challengerLobbyJoinedAt &&
        lhs.receiverLobbyJoinedAt == rhs.receiverLobbyJoinedAt &&
        lhs.lobbyCountdownStartedAt == rhs.lobbyCountdownStartedAt &&
        lhs.lobbyCountdownSeconds == rhs.lobbyCountdownSeconds
        // Note: Ignoring createdAt, updatedAt, debugCounter to prevent churn
    }
    
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
        let now = Date()
        
        // For sent challenges, use join_window_expires_at (30 seconds for testing)
        if let expiresAt = joinWindowExpiresAt, status == .sent {
            let expired = now > expiresAt
            print("🔍 isExpired check - status: sent, joinWindowExpiresAt: \(expiresAt), now: \(now), expired: \(expired)")
            return expired
        }
        
        // If we have a join window, it applies to states where we're waiting on something time-bound
        if let expiresAt = joinWindowExpiresAt, status == .ready || status == .lobby {
            let expired = now > expiresAt
            print("🔍 isExpired check - status: \(status?.rawValue ?? "nil"), joinWindowExpiresAt: \(expiresAt), now: \(now), expired: \(expired)")
            return expired
        }
        // Otherwise fall back to the broader challenge expiry (typically for pending inbound)
        if let expiresAt = challengeExpiresAt, status == .pending {
            let expired = now > expiresAt
            print("🔍 isExpired check - status: pending, challengeExpiresAt: \(expiresAt), now: \(now), expired: \(expired)")
            return expired
        }
        
        print("🔍 isExpired check - no expiry date found, status: \(status?.rawValue ?? "nil")")
        return false
    }
    
    var timeRemaining: TimeInterval? {
        if let expiresAt = joinWindowExpiresAt, status == .sent || status == .ready || status == .lobby {
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
    
    // MARK: - Lobby Presence Computed Properties
    
    var bothPlayersInLobby: Bool {
        challengerLobbyJoinedAt != nil && receiverLobbyJoinedAt != nil
    }
    
    var countdownStarted: Bool {
        lobbyCountdownStartedAt != nil
    }
    
    var countdownRemaining: TimeInterval? {
        guard let countdownStart = lobbyCountdownStartedAt else { return nil }
        let duration = TimeInterval(lobbyCountdownSeconds ?? 5)
        let elapsed = Date().timeIntervalSince(countdownStart)
        return max(0, duration - elapsed)
    }
    
    var countdownElapsed: Bool {
        guard let remaining = countdownRemaining else { return false }
        return remaining <= 0
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
        case playerScores = "player_scores"
        case turnIndexInLeg = "turn_index_in_leg"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case endedBy = "ended_by"
        case endedReason = "ended_reason"
        case winnerId = "winner_id"
        case endedAt = "ended_at"
        case debugCounter = "debug_counter"
        case challengerLobbyJoinedAt = "challenger_lobby_joined_at"
        case receiverLobbyJoinedAt = "receiver_lobby_joined_at"
        case lobbyCountdownStartedAt = "lobby_countdown_started_at"
        case lobbyCountdownSeconds = "lobby_countdown_seconds"
    }
    
    // MARK: - Initializers
    
    /// Memberwise initializer for programmatic creation (mock data, tests)
    init(
        id: UUID,
        matchMode: String,
        gameType: String,
        gameName: String,
        matchFormat: Int,
        challengerId: UUID,
        receiverId: UUID,
        status: RemoteMatchStatus?,
        currentPlayerId: UUID?,
        challengeExpiresAt: Date?,
        joinWindowExpiresAt: Date?,
        lastVisitPayload: LastVisitPayload?,
        playerScores: [UUID: Int]? = nil,
        turnIndexInLeg: Int? = nil,
        createdAt: Date,
        updatedAt: Date,
        endedBy: UUID? = nil,
        endedReason: String? = nil,
        winnerId: UUID? = nil,
        endedAt: Date? = nil,
        debugCounter: Int? = nil,
        challengerLobbyJoinedAt: Date? = nil,
        receiverLobbyJoinedAt: Date? = nil,
        lobbyCountdownStartedAt: Date? = nil,
        lobbyCountdownSeconds: Int? = nil
    ) {
        self.id = id
        self.matchMode = matchMode
        self.gameType = gameType
        self.gameName = gameName
        self.matchFormat = matchFormat
        self.challengerId = challengerId
        self.receiverId = receiverId
        self.status = status
        self.currentPlayerId = currentPlayerId
        self.challengeExpiresAt = challengeExpiresAt
        self.joinWindowExpiresAt = joinWindowExpiresAt
        self.lastVisitPayload = lastVisitPayload
        self.playerScores = playerScores
        self.turnIndexInLeg = turnIndexInLeg
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.endedBy = endedBy
        self.endedReason = endedReason
        self.winnerId = winnerId
        self.endedAt = endedAt
        self.debugCounter = debugCounter
        self.challengerLobbyJoinedAt = challengerLobbyJoinedAt
        self.receiverLobbyJoinedAt = receiverLobbyJoinedAt
        self.lobbyCountdownStartedAt = lobbyCountdownStartedAt
        self.lobbyCountdownSeconds = lobbyCountdownSeconds
    }
    
    // MARK: - Custom Decodable Implementation
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try c.decode(UUID.self, forKey: .id)
        matchMode = try c.decode(String.self, forKey: .matchMode)
        gameType = try c.decode(String.self, forKey: .gameType)
        gameName = try c.decode(String.self, forKey: .gameName)
        matchFormat = try c.decode(Int.self, forKey: .matchFormat)
        challengerId = try c.decode(UUID.self, forKey: .challengerId)
        receiverId = try c.decode(UUID.self, forKey: .receiverId)
        status = try c.decodeIfPresent(RemoteMatchStatus.self, forKey: .status)
        currentPlayerId = try c.decodeIfPresent(UUID.self, forKey: .currentPlayerId)
        challengeExpiresAt = try c.decodeIfPresent(Date.self, forKey: .challengeExpiresAt)
        joinWindowExpiresAt = try c.decodeIfPresent(Date.self, forKey: .joinWindowExpiresAt)
        lastVisitPayload = try c.decodeIfPresent(LastVisitPayload.self, forKey: .lastVisitPayload)
        turnIndexInLeg = try c.decodeIfPresent(Int.self, forKey: .turnIndexInLeg)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        endedBy = try c.decodeIfPresent(UUID.self, forKey: .endedBy)
        endedReason = try c.decodeIfPresent(String.self, forKey: .endedReason)
        winnerId = try c.decodeIfPresent(UUID.self, forKey: .winnerId)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        debugCounter = try c.decodeIfPresent(Int.self, forKey: .debugCounter)
        challengerLobbyJoinedAt = try c.decodeIfPresent(Date.self, forKey: .challengerLobbyJoinedAt)
        receiverLobbyJoinedAt = try c.decodeIfPresent(Date.self, forKey: .receiverLobbyJoinedAt)
        lobbyCountdownStartedAt = try c.decodeIfPresent(Date.self, forKey: .lobbyCountdownStartedAt)
        lobbyCountdownSeconds = try c.decodeIfPresent(Int.self, forKey: .lobbyCountdownSeconds)
        
        // ✅ Robust decode for player_scores (JSON object with string keys)
        if let raw = try c.decodeIfPresent([String: Int].self, forKey: .playerScores) {
            var mapped: [UUID: Int] = [:]
            mapped.reserveCapacity(raw.count)
            for (k, v) in raw {
                if let uuid = UUID(uuidString: k) {
                    mapped[uuid] = v
                }
            }
            playerScores = mapped.isEmpty ? nil : mapped
        } else {
            playerScores = nil
        }
    }
}

// MARK: - Last Visit Payload

struct LastVisitPayload: Codable, Equatable {
    let playerId: UUID
    let darts: [Int] // Array of dart scores
    let scoreBefore: Int
    let scoreAfter: Int
    let timestamp: String  // Server sends ISO8601 string, not Date
    
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
    
    // MARK: - Expiration Logic with User Context
    
    var isExpired: Bool {
        let now = Date()
        
        // For pending challenges, check if incoming or outgoing
        if match.status == .pending {
            // Outgoing challenge (I'm the challenger) - use join window (30s for testing)
            if match.challengerId == currentUserId {
                if let expiresAt = match.joinWindowExpiresAt {
                    let expired = now > expiresAt
                    print("🔍 isExpired check - OUTGOING pending (sent), joinWindowExpiresAt: \(expiresAt), now: \(now), expired: \(expired)")
                    return expired
                }
            }
            // Incoming challenge (I'm the receiver) - use challenge expiry (24h)
            else {
                if let expiresAt = match.challengeExpiresAt {
                    let expired = now > expiresAt
                    print("🔍 isExpired check - INCOMING pending, challengeExpiresAt: \(expiresAt), now: \(now), expired: \(expired)")
                    return expired
                }
            }
        }
        
        // For other statuses, delegate to match's isExpired
        return match.isExpired
    }
    
    var timeRemaining: TimeInterval? {
        // For pending challenges, check if incoming or outgoing
        if match.status == .pending {
            // Outgoing (I'm challenger) - use join window
            if match.challengerId == currentUserId {
                if let expiresAt = match.joinWindowExpiresAt {
                    return max(0, expiresAt.timeIntervalSinceNow)
                }
            }
            // Incoming (I'm receiver) - use challenge expiry
            else {
                if let expiresAt = match.challengeExpiresAt {
                    return max(0, expiresAt.timeIntervalSinceNow)
                }
            }
        }
        
        // For other statuses, delegate to match's timeRemaining
        return match.timeRemaining
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
        updatedAt: Date(),
        endedBy: nil,
        endedReason: nil,
        winnerId: nil
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
        updatedAt: Date(),
        endedBy: nil,
        endedReason: nil,
        winnerId: nil
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
        updatedAt: Date(),
        endedBy: nil,
        endedReason: nil,
        winnerId: nil
    )
}

// MARK: - Presentation Status Extension

extension RemoteMatch {
    /// Freeze status transitions during enter-flow so the row doesn't jump sections.
    /// Use this for UI grouping/filtering ONLY, not for business logic.
    nonisolated func presentationStatus(remoteMatchService: RemoteMatchService) -> RemoteMatchStatus {
        // Note: This is called from filtering context, so we use the service's helper
        // which properly handles MainActor isolation
        return status ?? .pending
    }
}
