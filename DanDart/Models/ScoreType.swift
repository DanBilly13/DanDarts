//
//  ScoreType.swift
//  DanDart
//
//  Enum representing dart scoring types (single, double, triple)
//  Used across all dart game modes
//

import Foundation

enum ScoreType: String, CaseIterable {
    case single = "Single"
    case double = "Double"
    case triple = "Triple"
    
    var multiplier: Int {
        switch self {
        case .single: return 1
        case .double: return 2
        case .triple: return 3
        }
    }
    
    var prefix: String {
        switch self {
        case .single: return ""
        case .double: return "D"
        case .triple: return "T"
        }
    }
}
