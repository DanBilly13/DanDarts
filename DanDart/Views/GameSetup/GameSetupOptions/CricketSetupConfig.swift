//
//  CricketSetupConfig.swift
//  Dart Freak
//
//  Configuration for Cricket game setup: 2 to 4 players, no options.
//

import SwiftUI

struct CricketSetupConfig: GameSetupConfigurable {
    let game: Game
    let playerLimit: Int = 4
    let optionLabel: String = ""
    let showOptions: Bool = false

    func optionView(selection: Binding<Int>) -> AnyView {
        AnyView(EmptyView())
    }

    func gameParameters(players: [Player], selection: Int) -> GameParameters {
        GameParameters(game: game, players: players, matchFormat: 1)
    }
}
