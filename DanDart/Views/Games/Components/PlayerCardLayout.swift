//
//  PlayerCardLayout.swift
//  Dart Freak
//
//  Reusable layout utility for player card spacing and sizing
//  Used in: Killer, Sudden Death
//

import SwiftUI

struct PlayerCardLayout {
    let playerCount: Int
    
    /// Spacing between player cards based on player count
    var spacing: CGFloat {
        switch playerCount {
        case 2: return 24
        case 3: return 24
        case 4: return 24
        case 5: return 4
        case 6: return -6
        case 7: return -8
        case 8: return -8
        default: return 32
        }
    }
    
    /// Card width based on player count
    var cardWidth: CGFloat {
        switch playerCount {
        case 2: return 100
        case 3: return 80
        case 4: return 72
        case 5: return 64
        case 6: return 64
        default: return 64
        }
    }
}
