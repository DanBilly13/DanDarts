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
    
    @State private var showInstructions = false
    @State private var showExitConfirmation = false
    @StateObject private var menuCoordinator = MenuCoordinator.shared
    
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
                
                VStack (spacing: 0) {  // Avatar Lineup
                    avatarLineup
                    Spacer()
                    
                    // Player Cards
                    playerCardsSection
                    Spacer()
                    
                    // Current throw display (always visible)
                    CurrentThrowDisplay(
                        currentThrow: viewModel.currentThrow,
                        selectedDartIndex: viewModel.selectedDartIndex,
                        onDartTapped: { index in
                            viewModel.selectDart(at: index)
                        },
                        showScore: false
                    )
                    .padding(.horizontal, 16)
                    Spacer()
                    
                    // Points needed text (like checkout suggestion)
                    VStack {
                        Text(viewModel.pointsNeededText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("AccentSecondary"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 0)
                    }
                    .frame(alignment: .center)
                    Spacer()
                }
               
                VStack (spacing: 0) {
                    // Scoring button grid (center)
                    ScoringButtonGrid(
                        onScoreSelected: { baseValue, scoreType in
                            let scoredThrow = ScoredThrow(baseValue: baseValue, scoreType: scoreType)
                            viewModel.recordThrow(scoredThrow)
                        },
                        showBustButton: false
                    )
                    .padding(.horizontal, 16)
                    
                    // THIS SPACER)
                    
                    Color.clear.frame(height: 24)
                    
                    // Save Score button container (fixed height to prevent layout shift)
                    ZStack {
                        // Invisible placeholder to maintain layout space
                        AppButton(role: .primary, controlSize: .extraLarge, action: {}) {
                            Text("Save Score")
                        }
                        .opacity(0)
                        .disabled(true)
                        
                        // Actual button that pops in/out
                        AppButton(
                            role: .primary,
                            controlSize: .extraLarge,
                            action: { viewModel.completeTurn() }
                        ) {
                            Label("Save Score", systemImage: "checkmark.circle.fill")
                        }
                        .popAnimation(
                            active: viewModel.isTurnComplete,
                            duration: 0.28,
                            bounce: 0.22
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 34)
                }
                
                
                
            }
        }
        .background(Color.black)
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                GameplayMenuButton(
                    onInstructions: { showInstructions = true },
                    onRestart: { viewModel.restartGame() },
                    onExit: { showExitConfirmation = true }
                )
            }
        }
        .toolbarBackground(Color("BackgroundPrimary"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled()
        .ignoresSafeArea(.container, edges: .bottom)
        .alert("Exit Game", isPresented: $showExitConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Leave Game", role: .destructive) {
                NavigationManager.shared.dismissToGamesList()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to leave the game? Your progress will be lost.")
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
                        NavigationManager.shared.dismissToGamesList()
                        dismiss()
                    },
                    onBackToGames: {
                        NavigationManager.shared.dismissToGamesList()
                        dismiss()
                    },
                    matchFormat: nil,
                    legsWon: nil,
                    matchId: nil
                )
            }
        }
    }
    
    
    // MARK: - Avatar Lineup
    
    private var avatarLineup: some View {
        HStack(spacing: -2) {
            ForEach(viewModel.players) { player in
                AvatarLineupItem(
                    player: player,
                    isCurrentPlayer: player.id == viewModel.currentPlayer.id,
                    isEliminated: viewModel.eliminatedPlayers.contains(player.id)
                )
            }
        }
    }
    
    // MARK: - Player Cards Section
    
    private var playerCardsSection: some View {
        VStack(spacing: 10) {
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
            if isCurrentPlayer {
                // Outer green circle (32px)
                Circle()
                    .fill(Color("AccentSecondary"))
                    .frame(width: 32, height: 32)
                
                // Inner black circle (28px)
                Circle()
                    .fill(Color.black)
                    .frame(width: 28, height: 28)
                
                // Avatar (24px to fit inside black circle)
                AsyncAvatarImage(
                    avatarURL: player.avatarURL,
                    size: 24
                )
                .opacity(isEliminated ? 0.3 : 1.0)
            } else {
                // Regular avatar (32px)
                AsyncAvatarImage(
                    avatarURL: player.avatarURL,
                    size: 32
                )
                .opacity(isEliminated ? 0.3 : 1.0)
            }
        }
        .frame(width: 32, height: 32)
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
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .padding(.leading, 8)
        .padding(.trailing, 24)
        .background(
            Capsule()
                .fill(Color("InputBackground"))
        )
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 2)
        )
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
