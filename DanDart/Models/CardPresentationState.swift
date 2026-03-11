//
//  CardPresentationState.swift
//  DanDart
//
//  UI presentation state for PlayerChallengeCard
//  Maps from authoritative RemoteMatchStatus for rendering
//

import Foundation

/// UI presentation state for PlayerChallengeCard
/// This is a presentation-only enum, not stored in database
/// Derived from authoritative RemoteMatchStatus at render time
enum CardPresentationState {
    case pending        // Receiver view: incoming challenge
    case sent           // Challenger view: waiting for response
    case declined       // Challenger view: receiver declined (brief, 2s)
    case ready          // Match accepted, ready to join
    case lobby          // In lobby, waiting for match start
    case inProgress     // Match in progress
    case expired        // Challenge/join window expired
    case cancelled      // Match cancelled
    case completed      // Match finished
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .sent: return "Sent"
        case .declined: return "Declined"
        case .ready: return "Ready"
        case .lobby: return "Lobby"
        case .inProgress: return "In Progress"
        case .expired: return "Expired"
        case .cancelled: return "Cancelled"
        case .completed: return "Completed"
        }
    }
}
