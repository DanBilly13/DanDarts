//
//  ScoredThrow.swift
//  DanDart
//
//  Model representing a single dart throw with its score type
//  Used across all dart game modes
//

import Foundation

struct ScoredThrow {
    let baseValue: Int
    let scoreType: ScoreType
    
    var totalValue: Int {
        baseValue * scoreType.multiplier
    }
    
    var displayText: String {
        if scoreType == .single {
            return "\(totalValue)"
        } else {
            return "\(scoreType.prefix)\(baseValue)"
        }
    }
}
