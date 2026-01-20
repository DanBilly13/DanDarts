//
//  Visit.swift
//  Dart Freak
//
//  Model to store visit data for undo functionality
//

import Foundation

struct Visit {
    let playerID: UUID
    let playerName: String
    let dartsThrown: [ScoredThrow]
    let scoreChange: Int        // Points scored this visit
    let previousScore: Int      // Score before this visit
    let newScore: Int          // Score after this visit
    let currentPlayerIndex: Int // Player index before this visit
    
    init(
        playerID: UUID,
        playerName: String,
        dartsThrown: [ScoredThrow],
        scoreChange: Int,
        previousScore: Int,
        newScore: Int,
        currentPlayerIndex: Int
    ) {
        self.playerID = playerID
        self.playerName = playerName
        self.dartsThrown = dartsThrown
        self.scoreChange = scoreChange
        self.previousScore = previousScore
        self.newScore = newScore
        self.currentPlayerIndex = currentPlayerIndex
    }
}
