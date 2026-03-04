//
//  CountdownEngine.swift
//  DanDart
//
//  Pure rules engine for Countdown games (301/501)
//  NO SwiftUI, NO @Published, NO networking, NO side effects
//  Rules ported 1:1 from CountdownViewModel.swift
//

import Foundation

// MARK: - State (immutable input/output)

struct CountdownState {
    var startingScore: Int
    var scores: [UUID: Int]
    var playerIds: [UUID]
    var currentPlayerIndex: Int
    var currentLeg: Int
    var legsWon: [UUID: Int]
    var matchFormat: Int
    var isEnded: Bool
    var winnerId: UUID?
    
    var currentPlayerId: UUID {
        playerIds[currentPlayerIndex]
    }
}

// MARK: - Events (for UI to handle)

enum CountdownEvent {
    case busted(playerId: UUID)
    case scored(playerId: UUID, before: Int, after: Int)
    case legWon(winnerId: UUID)
    case matchWon(winnerId: UUID)
}

// MARK: - Engine (pure functions only)

enum CountdownEngine {
    
    /// Apply a visit (3 darts) and return new state + events
    /// Rules ported 1:1 from CountdownViewModel.saveScore() lines 322-482
    static func applyVisit(
        state: CountdownState,
        playerId: UUID,
        darts: [ScoredThrow]
    ) -> (newState: CountdownState, events: [CountdownEvent]) {
        
        // Guard: game already ended
        guard !state.isEnded else {
            return (state, [])
        }
        
        // Guard: empty throw
        guard !darts.isEmpty else {
            return (state, [])
        }
        
        var newState = state
        var events: [CountdownEvent] = []
        
        let throwTotal = darts.reduce(0) { $0 + $1.totalValue }
        let currentScore = state.scores[playerId] ?? state.startingScore
        let newScore = currentScore - throwTotal
        
        // BUST RULES (from CountdownViewModel.swift:330-340)
        let isBustTurn = newScore < 0 || newScore == 1
        
        // Must finish on double (from CountdownViewModel.swift:334-338)
        let finishedOnDouble = (newScore == 0) && (darts.last?.scoreType == .double)
        
        if isBustTurn || (newScore == 0 && !finishedOnDouble) {
            // BUST - score stays same, switch player
            events.append(.busted(playerId: playerId))
            newState.currentPlayerIndex = nextPlayerIndex(state: state)
            return (newState, events)
        }
        
        // Valid score - update
        newState.scores[playerId] = newScore
        events.append(.scored(playerId: playerId, before: currentScore, after: newScore))
        
        // Check for leg winner (from CountdownViewModel.swift:412-450)
        if newScore == 0 {
            newState.legsWon[playerId, default: 0] += 1
            events.append(.legWon(winnerId: playerId))
            
            // Check for match winner
            let legsNeededToWin = (state.matchFormat / 2) + 1
            let playerLegs = newState.legsWon[playerId] ?? 0
            
            if playerLegs >= legsNeededToWin {
                // MATCH WON
                newState.isEnded = true
                newState.winnerId = playerId
                events.append(.matchWon(winnerId: playerId))
                return (newState, events)
            }
            
            // Leg won but match continues - don't switch player
            return (newState, events)
        }
        
        // Normal turn - switch to next player
        newState.currentPlayerIndex = nextPlayerIndex(state: state)
        
        return (newState, events)
    }
    
    /// Get next player index (rotation)
    private static func nextPlayerIndex(state: CountdownState) -> Int {
        (state.currentPlayerIndex + 1) % state.playerIds.count
    }
}
