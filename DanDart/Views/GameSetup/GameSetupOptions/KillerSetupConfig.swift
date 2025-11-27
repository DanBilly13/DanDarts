//
//  KillerSetupConfig.swift
//  DanDart
//
//  Configuration for Killer game setup
//

import SwiftUI

struct KillerSetupConfig: GameSetupConfigurable {
    let game: Game
    let playerLimit: Int = 6
    let optionLabel: String = "Lives"
    let defaultSelection: Int = 1 // 5 Lives (most common)
    
    // Lives options: 3, 5, or 7
    private let livesOptions = [3, 5, 7]
    
    func optionView(selection: Binding<Int>) -> AnyView {
        AnyView(
            SegmentedControl(options: [0, 1, 2], selection: selection) { index in
                let lives = livesOptions[index]
                return "\(lives) \(lives == 1 ? "Life" : "Lives")"
            }
        )
    }
    
    func gameParameters(players: [Player], selection: Int) -> GameParameters {
        let selectedLives = livesOptions[selection]
        return GameParameters(
            game: game,
            players: players,
            matchFormat: 1,
            killerLives: selectedLives
        )
    }
}
