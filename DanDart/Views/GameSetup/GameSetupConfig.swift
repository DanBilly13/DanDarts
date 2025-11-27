//
//  GameSetupConfig.swift
//  DanDart
//
//  Configuration protocol for game setup views
//  Allows each game type to define its specific options and parameters
//

import SwiftUI

// MARK: - Game Parameters

/// Parameters to pass to PreGameHypeView for starting a game
struct GameParameters {
    let game: Game
    let players: [Player]
    let matchFormat: Int
    let halveItDifficulty: HalveItDifficulty?
    let knockoutLives: Int?
    let killerLives: Int?
    
    init(game: Game, players: [Player], matchFormat: Int = 1, halveItDifficulty: HalveItDifficulty? = nil, knockoutLives: Int? = nil, killerLives: Int? = nil) {
        self.game = game
        self.players = players
        self.matchFormat = matchFormat
        self.halveItDifficulty = halveItDifficulty
        self.knockoutLives = knockoutLives
        self.killerLives = killerLives
    }
}

// MARK: - Configuration Protocol

/// Protocol that each game type implements to define its setup configuration
protocol GameSetupConfigurable {
    /// The game being configured
    var game: Game { get }
    
    /// Maximum number of players allowed
    var playerLimit: Int { get }
    
    /// Label for the options section (e.g., "Match Format", "Difficulty", "Lives")
    var optionLabel: String { get }
    
    /// Whether to show the options section at all
    var showOptions: Bool { get }
    
    /// Default selection index
    var defaultSelection: Int { get }
    
    /// Creates the segmented control view for game-specific options
    func optionView(selection: Binding<Int>) -> AnyView
    
    /// Converts the selection index to game parameters for PreGameHypeView
    func gameParameters(players: [Player], selection: Int) -> GameParameters
}

// MARK: - Default Implementations

extension GameSetupConfigurable {
    var showOptions: Bool { true }
    var defaultSelection: Int { 0 }
}
