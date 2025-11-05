//
//  SuddenDeathPreGameHypeView.swift
//  DanDart
//
//  Wrapper for PreGameHypeView that navigates to Sudden Death gameplay
//

import SwiftUI

struct SuddenDeathPreGameHypeView: View {
    let game: Game
    let players: [Player]
    let startingLives: Int
    
    var body: some View {
        PreGameHypeView(
            game: game,
            players: players,
            matchFormat: 1
        )
        .navigationDestination(isPresented: .constant(true)) {
            SuddenDeathGameplayView(
                game: game,
                players: players,
                startingLives: startingLives
            )
        }
    }
}
