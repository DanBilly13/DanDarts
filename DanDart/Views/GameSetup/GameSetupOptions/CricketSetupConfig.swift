//
//  CricketSetupConfig.swift
//  Dart Freak
//
//  Configuration for Cricket game setup: 2 to 4 players, Standard or Cut-Throat scoring.
//

import SwiftUI

struct CricketSetupConfig: GameSetupConfigurable {
    let game: Game
    let playerLimit: Int = 4
    let optionLabel: String = "Scoring"
    let defaultSelection: Int = 0 // Standard

    private let scoringOptions: [CricketScoring] = [.standard, .cutThroat]

    func optionView(selection: Binding<Int>) -> AnyView {
        AnyView(
            SegmentedControl(options: [0, 1], selection: selection) { index in
                scoringOptions[index] == .cutThroat ? "Cut-Throat" : "Standard"
            }
        )
    }

    func gameParameters(players: [Player], selection: Int) -> GameParameters {
        GameParameters(game: game, players: players, matchFormat: scoringOptions[selection].matchFormat)
    }
}
