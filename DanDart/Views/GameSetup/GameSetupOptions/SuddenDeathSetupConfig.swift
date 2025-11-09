//
//  SuddenDeathSetupConfig.swift
//  DanDart
//
//  Configuration for Sudden Death game setup
//

import SwiftUI

struct SuddenDeathSetupConfig: GameSetupConfigurable {
    let game: Game
    let playerLimit: Int = 10
    let optionLabel: String = "Lives"
    let defaultSelection: Int = 1 // 3 Lives (most common)
    
    // Lives options: 1, 3, or 5
    private let livesOptions = [1, 3, 5]
    
    func optionView(selection: Binding<Int>) -> AnyView {
        AnyView(
            SegmentedControl(options: livesOptions, selection: selection) { lives in
                "\(lives) \(lives == 1 ? "Life" : "Lives")"
            }
        )
    }
    
    func gameParameters(players: [Player], selection: Int) -> GameParameters {
        let selectedLives = livesOptions[selection]
        return GameParameters(
            game: game,
            players: players,
            matchFormat: 1,
            suddenDeathLives: selectedLives
        )
    }
}
