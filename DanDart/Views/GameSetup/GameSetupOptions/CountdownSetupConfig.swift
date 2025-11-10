//
//  CountdownSetupConfig.swift
//  DanDart
//
//  Configuration for 301/501 game setup
//

import SwiftUI

struct CountdownSetupConfig: GameSetupConfigurable {
    let game: Game
    let playerLimit: Int = 8
    let optionLabel: String = "Match Format"
    let defaultSelection: Int = 0 // Best of 1
    
    // Legs options: Best of 1, 3, 5, 7
    private let legsOptions = [1, 3, 5, 7]
    
    func optionView(selection: Binding<Int>) -> AnyView {
        AnyView(
            SegmentedControl(options: [0, 1, 2, 3], selection: selection) { index in
                let legs = legsOptions[index]
                return "Best of \(legs)"
            }
        )
    }
    
    func gameParameters(players: [Player], selection: Int) -> GameParameters {
        let selectedLegs = legsOptions[selection]
        return GameParameters(
            game: game,
            players: players,
            matchFormat: selectedLegs
        )
    }
}
