//
//  RemoteGameStateAdapter.swift
//  DanDart
//
//  Adapter layer to map remote match data to local game UI expectations
//  Provides clear data transformation between backend match object and UI state
//

import Foundation

/// Adapter that transforms remote match data into UI-friendly state
/// Ensures consistent player identity (Challenger = Red, Receiver = Green)
struct RemoteGameStateAdapter {
    // MARK: - Properties
    
    let match: RemoteMatch
    let challenger: User
    let receiver: User
    let currentUserId: UUID
    
    // MARK: - Player Identity (Persistent Colors)
    
    /// Player 1 is always the Challenger (Red)
    var player1: User {
        challenger
    }
    
    /// Player 2 is always the Receiver (Green)
    var player2: User {
        receiver
    }
    
    /// Player 1 display name
    var player1DisplayName: String {
        challenger.displayName
    }
    
    /// Player 2 display name
    var player2DisplayName: String {
        receiver.displayName
    }
    
    /// Current user's role
    var myRole: PlayerRole {
        currentUserId == match.challengerId ? .challenger : .receiver
    }
    
    /// Opponent user
    var opponent: User {
        currentUserId == match.challengerId ? receiver : challenger
    }
    
    // MARK: - Turn State
    
    /// Is it Player 1's (Challenger's) turn?
    var isPlayer1Turn: Bool {
        guard let currentPlayerId = match.currentPlayerId else { return false }
        return currentPlayerId == match.challengerId
    }
    
    /// Is it Player 2's (Receiver's) turn?
    var isPlayer2Turn: Bool {
        guard let currentPlayerId = match.currentPlayerId else { return false }
        return currentPlayerId == match.receiverId
    }
    
    /// Is it the current user's turn?
    var isMyTurn: Bool {
        guard let currentPlayerId = match.currentPlayerId else { return false }
        return currentPlayerId == currentUserId
    }
    
    /// Current player index (0 = Player 1, 1 = Player 2)
    /// Returns nil when currentPlayerId is unknown (e.g., before first turn)
    var currentPlayerIndex: Int? {
        guard match.currentPlayerId != nil else { return nil }
        return isPlayer1Turn ? 0 : 1
    }
    
    // MARK: - Last Visit Data
    
    /// Last visit value (for reveal animation)
    /// Note: Calculated by summing darts array. If backend provides a total field in future, use that instead.
    var lastVisitValue: Int? {
        guard let payload = match.lastVisitPayload else { return nil }
        // Sum individual dart values (assumption: backend doesn't provide pre-calculated total)
        return payload.darts.reduce(0, +)
    }
    
    /// Last visit darts
    var lastVisitDarts: [Int]? {
        match.lastVisitPayload?.darts
    }
    
    /// Last visit player ID
    var lastVisitPlayerId: UUID? {
        match.lastVisitPayload?.playerId
    }
    
    /// Score before last visit
    var lastVisitScoreBefore: Int? {
        match.lastVisitPayload?.scoreBefore
    }
    
    /// Score after last visit
    var lastVisitScoreAfter: Int? {
        match.lastVisitPayload?.scoreAfter
    }
    
    // MARK: - Interaction State
    
    /// Can the current user interact with the game?
    /// (Active player only, and not during saving state)
    func canInteract(isSaving: Bool) -> Bool {
        guard !isSaving else { return false }
        return isMyTurn
    }
    
    /// Overlay state for the current user
    func overlayState(isSaving: Bool) -> OverlayState {
        if isSaving {
            // Both players see "Saving {player}'s visit" overlay
            return .saving
        } else if !isMyTurn {
            // Inactive player sees lockout overlay
            return .inactiveLockout
        } else {
            // Active player, no overlay
            return .none
        }
    }
    
    /// Overlay state enum for UI display
    enum OverlayState {
        case none              // No overlay (active player, not saving)
        case inactiveLockout   // "Waiting for {opponent}" overlay
        case saving            // "Saving {player}'s visit" overlay (shown to both players)
        
        var isVisible: Bool {
            self != .none
        }
    }
    
    // MARK: - Player Role
    
    enum PlayerRole {
        case challenger // Player 1 - Red
        case receiver   // Player 2 - Green
        
        var colorName: String {
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
        
        var playerNumber: Int {
            switch self {
            case .challenger: return 1
            case .receiver: return 2
            }
        }
    }
}

// MARK: - Convenience Extensions

extension RemoteGameStateAdapter {
    /// Create players array in correct order for UI
    /// Always returns [Challenger, Receiver] for consistent color assignment
    func createPlayersArray() -> [Player] {
        let challengerPlayer = Player(
            id: challenger.id,
            displayName: challenger.displayName,
            nickname: challenger.nickname,
            avatarURL: challenger.avatarURL,
            isGuest: false,
            totalWins: challenger.totalWins,
            totalLosses: challenger.totalLosses,
            userId: challenger.id
        )
        
        let receiverPlayer = Player(
            id: receiver.id,
            displayName: receiver.displayName,
            nickname: receiver.nickname,
            avatarURL: receiver.avatarURL,
            isGuest: false,
            totalWins: receiver.totalWins,
            totalLosses: receiver.totalLosses,
            userId: receiver.id
        )
        
        // Always return in order: [Challenger (Red), Receiver (Green)]
        return [challengerPlayer, receiverPlayer]
    }
    
    /// Get player by index (0 = Challenger, 1 = Receiver)
    func player(at index: Int) -> User? {
        switch index {
        case 0: return challenger
        case 1: return receiver
        default: return nil
        }
    }
    
    /// Get player index for a given user ID
    func playerIndex(for userId: UUID) -> Int? {
        if userId == match.challengerId {
            return 0
        } else if userId == match.receiverId {
            return 1
        }
        return nil
    }
}

// MARK: - Debug Description

extension RemoteGameStateAdapter: CustomDebugStringConvertible {
    var debugDescription: String {
        """
        RemoteGameStateAdapter:
          Match ID: \(match.id)
          Status: \(match.status?.rawValue ?? "nil")
          Player 1 (Challenger/Red): \(challenger.displayName)
          Player 2 (Receiver/Green): \(receiver.displayName)
          Current Turn: Player \(currentPlayerIndex.map { "\($0 + 1)" } ?? "unknown") (\(isPlayer1Turn ? challenger.displayName : receiver.displayName))
          My Role: \(myRole.displayName)
          Is My Turn: \(isMyTurn)
          Last Visit: \(lastVisitValue?.description ?? "none")
        """
    }
}
