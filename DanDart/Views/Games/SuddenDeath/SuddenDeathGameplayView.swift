//
//  SuddenDeathGameplayView.swift
//  DanDart
//
//  Created by DanDarts Team
//

import SwiftUI

struct SuddenDeathGameplayView: View {
    let game: Game
    let players: [Player]
    let startingLives: Int
    
    @StateObject private var viewModel: SuddenDeathViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showMenu = false
    @State private var showInstructions = false
    @State private var showExitConfirmation = false
    
    // Initialize with game, players, and starting lives
    init(game: Game, players: [Player], startingLives: Int) {
        self.game = game
        self.players = players
        self.startingLives = startingLives
        _viewModel = StateObject(wrappedValue: SuddenDeathViewModel(players: players, startingLives: startingLives))
    }
    
    var body: some View {
        ZStack {
            Color("BackgroundPrimary")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Game Title
                gameHeader
                
                // Avatar Lineup
                avatarLineup
                    .padding(.top, 16)
                
                // Player Cards
                playerCardsSection
                    .padding(.top, 24)
                
                // Current Throw Display
                CurrentThrowDisplay(
                    currentThrow: viewModel.currentThrow,
                    selectedDartIndex: viewModel.selectedDartIndex,
                    onDartTapped: { index in
                        viewModel.selectDart(at: index)
                    },
                    showScore: false // KEY: Don't show score in throw display
                )
                .padding(.horizontal, 16)
                .padding(.top, 24)
                
                // Points Needed Text
                Text(viewModel.pointsNeededText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color("AccentSecondary"))
                    .padding(.top, 12)
                
                // Scoring Buttons
                ScoringButtonGrid(
                    onScoreSelected: { baseValue, scoreType in
                        let scoredThrow = ScoredThrow(baseValue: baseValue, scoreType: scoreType)
                        viewModel.recordThrow(scoredThrow)
                    },
                    showBustButton: false
                )
                .padding(.horizontal, 16)
                .padding(.top, 20)
                
                // Save Score Button
                if viewModel.isTurnComplete {
                    Button(action: {
                        viewModel.completeTurn()
                    }) {
                        Text("Save Score")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color("TextPrimary"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color("AccentPrimary"))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .popAnimation(active: viewModel.isTurnComplete)
                }
                
                Spacer(minLength: 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showMenu = true
                }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 24))
                        .foregroundColor(Color("TextPrimary"))
                }
            }
        }
        .confirmationDialog("Game Menu", isPresented: $showMenu) {
            Button("Instructions") {
                showInstructions = true
            }
            Button("Restart Game") {
                viewModel.restartGame()
            }
            Button("Exit Game", role: .destructive) {
                showExitConfirmation = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Exit Game?", isPresented: $showExitConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Exit", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("Are you sure you want to exit? Progress will be lost.")
        }
        .sheet(isPresented: $showInstructions) {
            GameInstructionsView(game: game)
        }
        .navigationDestination(isPresented: $viewModel.isGameOver) {
            if let winner = viewModel.winner {
                GameEndView(
                    game: game,
                    winner: winner,
                    players: viewModel.players,
                    onPlayAgain: {
                        viewModel.restartGame()
                    },
                    onChangePlayers: {
                        dismiss()
                    },
                    onBackToGames: {
                        dismiss()
                    },
                    matchFormat: nil,
                    legsWon: nil,
                    matchId: nil
                )
            }
        }
    }
    
    // MARK: - Game Header
    
    private var gameHeader: some View {
        Text("Sudden death")
            .font(.system(size: 28, weight: .bold))
            .foregroundColor(Color("TextPrimary"))
            .padding(.top, 8)
    }
    
    // MARK: - Avatar Lineup
    
    private var avatarLineup: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.players) { player in
                    AvatarLineupItem(
                        player: player,
                        isCurrentPlayer: player.id == viewModel.currentPlayer.id,
                        isEliminated: viewModel.eliminatedPlayers.contains(player.id)
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Player Cards Section
    
    private var playerCardsSection: some View {
        VStack(spacing: 24) {
            // Player to Beat Card (Red/AccentPrimary)
            SuddenDeathPlayerCard(
                player: viewModel.playerToBeat,
                lives: viewModel.playerLives[viewModel.playerToBeat.id] ?? 0,
                score: viewModel.scoreToBeat,
                isPlayerToBeat: true,
                borderColor: Color("AccentPrimary")
            )
            
            // Current Player Card (Green/AccentSecondary)
            SuddenDeathPlayerCard(
                player: viewModel.currentPlayer,
                lives: viewModel.playerLives[viewModel.currentPlayer.id] ?? 0,
                score: viewModel.currentTurnTotal,
                isPlayerToBeat: false,
                borderColor: Color("AccentSecondary")
            )
        }
        .padding(.horizontal, 16)
    }
    
}

// MARK: - Avatar Lineup Item

struct AvatarLineupItem: View {
    let player: Player
    let isCurrentPlayer: Bool
    let isEliminated: Bool
    
    var body: some View {
        ZStack {
            // Outer border for current player (AccentSecondary)
            if isCurrentPlayer {
                Circle()
                    .stroke(Color("AccentSecondary"), lineWidth: 3)
                    .frame(width: 38, height: 38)
            }
            
            // Avatar
            AsyncAvatarImage(
                avatarURL: player.avatarURL,
                size: 32
            )
            .opacity(isEliminated ? 0.3 : 1.0)
        }
    }
}

// MARK: - Sudden Death Player Card

struct SuddenDeathPlayerCard: View {
    let player: Player
    let lives: Int
    let score: Int
    let isPlayerToBeat: Bool
    let borderColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AsyncAvatarImage(
                avatarURL: player.avatarURL,
                size: 44
            )
            .padding(.leading, 8)
            
            // Player Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(player.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color("TextPrimary"))
                        .lineLimit(1)
                    
                    // Lives (hearts)
                    HStack(spacing: 4) {
                        ForEach(0..<lives, id: \.self) { _ in
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                Text(player.nickname)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color("TextSecondary"))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Score Section
            HStack(spacing: 8) {
                // Crown for player to beat
                if isPlayerToBeat {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.yellow)
                }
                
                Text("\(score)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color("TextPrimary"))
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.trailing, 8)
        }
        .frame(height: 60)
        .background(Color("InputBackground"))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 8)
        )
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview("Gameplay") {
    NavigationStack {
        SuddenDeathGameplayView(
            game: Game(
                title: "Sudden Death",
                subtitle: "Fast and Ruthless Fun",
                players: "2 or more",
                instructions: "Each player throws three darts per round, and the player with the lowest total is eliminated."
            ),
            players: [
                Player.mockGuest1,
                Player.mockGuest2,
                Player.mockGuest3
            ],
            startingLives: 3
        )
    }
}
