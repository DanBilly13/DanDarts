//
//  HalveItGameplayView.swift
//  DanDart
//
//  Full-screen gameplay view for Halve It game
//  Shows target progression and accumulated scoring
//

import SwiftUI

struct HalveItGameplayView: View {
    let game: Game
    let players: [Player]
    let difficulty: HalveItDifficulty
    
    // Game state managed by ViewModel
    @StateObject private var viewModel: HalveItViewModel
    @StateObject private var menuCoordinator = MenuCoordinator.shared
    @State private var showInstructions: Bool = false
    @State private var showRestartAlert: Bool = false
    @State private var showExitAlert: Bool = false
    @State private var navigateToGameEnd: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    // Initialize with game, players, and difficulty
    init(game: Game, players: [Player], difficulty: HalveItDifficulty) {
        self.game = game
        self.players = players
        self.difficulty = difficulty
        _viewModel = StateObject(wrappedValue: HalveItViewModel(players: players, difficulty: difficulty))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Player score cards (reusing 301 component)
            StackedPlayerCards(
                players: viewModel.players,
                currentPlayerIndex: viewModel.currentPlayerIndex,
                playerScores: viewModel.playerScores,
                currentThrow: viewModel.currentThrow,
                legsWon: [:],  // Not used in Halve It
                matchFormat: 1,  // Not used in Halve It
                showScoreAnimation: viewModel.showScoreAnimation
            )
            .padding(.horizontal, 16)
            .padding(.top, 56)
            
            // Current throw display (with tap-to-edit)
            CurrentThrowDisplay(
                currentThrow: viewModel.currentThrow,
                selectedDartIndex: viewModel.selectedDartIndex,
                onDartTapped: { index in
                    viewModel.selectDart(at: index)
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Target progression (moved below current throw)
            TargetProgressView(
                targets: viewModel.targets,
                currentRound: viewModel.currentRound
            )
            .padding(.top, 8)
            
            // Scoring button grid
            ScoringButtonGrid(
                onScoreSelected: { baseValue, scoreType in
                    viewModel.recordThrow(baseValue: baseValue, scoreType: scoreType)
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Spacer()
            
            // Save Score button container (fixed height to prevent layout shift)
            ZStack {
                // Invisible placeholder to maintain layout space
                AppButton(role: .primary, action: {}) {
                    Text("Save Score")
                }
                .opacity(0)
                .disabled(true)
                
                // Actual button that pops in/out
                AppButton(
                    role: .primary,
                    action: { viewModel.completeTurn() }
                ) {
                    Label("Save Score", systemImage: "checkmark.circle.fill")
                }
                .blur(radius: menuCoordinator.activeMenuId != nil ? 2 : 0)
                .opacity(menuCoordinator.activeMenuId != nil ? 0.4 : 1.0)
                // Pop animation when turn is complete (3 darts entered)
                .popAnimation(
                    active: viewModel.isTurnComplete,
                    duration: 0.28,
                    bounce: 0.22
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 34)
        }
        .background(Color.black)
        .navigationTitle("Halve It • \(difficulty.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Instructions") { showInstructions = true }
                    Button("Restart Game") { showRestartAlert = true }
                    Button("Cancel Game", role: .destructive) { showExitAlert = true }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color("TextSecondary"))
                }
            }
        }
        .toolbarBackground(Color("BackgroundPrimary"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled()
        .ignoresSafeArea(.container, edges: .bottom)
        .alert("Exit Game", isPresented: $showExitAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Leave Game", role: .destructive) {
                NavigationManager.shared.dismissToGamesList()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to leave the game? Your progress will be lost.")
        }
        .alert("Restart Game", isPresented: $showRestartAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Restart", role: .destructive) {
                viewModel.resetGame()
            }
        } message: {
            Text("This will reset the game and all scores.")
        }
        .sheet(isPresented: $showInstructions) {
            GameInstructionsView(game: game)
        }
        .onChange(of: viewModel.isGameOver) { _, isOver in
            if isOver {
                navigateToGameEnd = true
            }
        }
        .navigationDestination(isPresented: $navigateToGameEnd) {
            GameEndView(
                game: game,
                winner: viewModel.winner ?? viewModel.players[0],
                players: viewModel.players,
                onPlayAgain: {
                    viewModel.resetGame()
                    navigateToGameEnd = false
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

// MARK: - Preview

#Preview("Halve It Gameplay") {
    let games = Game.loadGames()
    let halveItGame = games.first(where: { $0.title == "Halve-It" })!
    
    return NavigationStack {
        HalveItGameplayView(
            game: halveItGame,
            players: [Player.mockGuest1, Player.mockGuest2],
            difficulty: .medium
        )
    }
}
