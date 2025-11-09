//
//  HalveItSetupConfig.swift
//  DanDart
//
//  Configuration for Halve-It game setup
//

import SwiftUI

struct HalveItSetupConfig: GameSetupConfigurable {
    let game: Game
    let playerLimit: Int = 8
    let optionLabel: String = "Difficulty"
    let defaultSelection: Int = 0 // Easy
    
    // Array of difficulty options for segmented control
    private let difficulties: [HalveItDifficulty] = [.easy, .medium, .hard]
    
    func optionView(selection: Binding<Int>) -> AnyView {
        AnyView(
            SegmentedControl(options: [0, 1, 2], selection: selection) { index in
                difficulties[index].rawValue
            }
        )
    }
    
    func gameParameters(players: [Player], selection: Int) -> GameParameters {
        let selectedDifficulty = difficulties[selection]
        return GameParameters(
            game: game,
            players: players,
            matchFormat: 1,
            halveItDifficulty: selectedDifficulty
        )
    }
}
