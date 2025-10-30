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
            // Target progression at top
            TargetProgressView(
                targets: viewModel.targets,
                currentRound: viewModel.currentRound
            )
            .padding(.top, 56)
            
            // Player score cards
            HalveItPlayerCards(
                players: viewModel.players,
                currentPlayerIndex: viewModel.currentPlayerIndex,
                playerScores: viewModel.playerScores,
                currentThrow: viewModel.currentThrow
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Current throw display
            CurrentThrowDisplay(
                currentThrow: viewModel.currentThrow,
                selectedDartIndex: nil,
                onDartTapped: { _ in }
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Round info
            Text("Round \(viewModel.currentRound + 1)/6 • Target: \(viewModel.currentTarget.displayText)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color("TextSecondary"))
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
            
            // Action buttons
            HStack(spacing: 12) {
                // Undo button
                if !viewModel.currentThrow.isEmpty {
                    AppButton(role: .secondary, action: {
                        viewModel.undoLastDart()
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .frame(width: 60)
                }
                
                // Save Score button
                AppButton(
                    role: .primary,
                    action: { viewModel.completeTurn() }
                ) {
                    Label("Save Score", systemImage: "checkmark.circle.fill")
                }
                .disabled(viewModel.currentThrow.isEmpty)
                .opacity(viewModel.currentThrow.isEmpty ? 0.5 : 1.0)
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
            if let winner = viewModel.winner {
                GameEndView(
                    game: game,
                    winner: winner,
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
}

// MARK: - Halve It Player Cards

struct HalveItPlayerCards: View {
    let players: [Player]
    let currentPlayerIndex: Int
    let playerScores: [UUID: Int]
    let currentThrow: [ScoredThrow]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                HalveItPlayerCard(
                    player: player,
                    score: playerScores[player.id] ?? 0,
                    isActive: index == currentPlayerIndex,
                    currentThrow: index == currentPlayerIndex ? currentThrow : []
                )
            }
        }
    }
}

// MARK: - Halve It Player Card

struct HalveItPlayerCard: View {
    let player: Player
    let score: Int
    let isActive: Bool
    let currentThrow: [ScoredThrow]
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AsyncAvatarImage(
                avatarURL: player.avatarURL,
                size: 40
            )
            
            // Player info
            VStack(alignment: .leading, spacing: 2) {
                Text(player.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("TextPrimary"))
                
                if let nickname = player.nickname {
                    Text("@\(nickname)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color("TextSecondary"))
                }
            }
            
            Spacer()
            
            // Score display
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(isActive ? Color("AccentPrimary") : Color("TextPrimary"))
                
                if isActive && !currentThrow.isEmpty {
                    Text("+\(currentThrow.map { $0.totalValue }.reduce(0, +))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color("AccentSecondary"))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("InputBackground"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isActive ? Color("AccentPrimary") : Color.clear,
                            lineWidth: 2
                        )
                )
        )
    }
}

// MARK: - Preview

#Preview("Halve It Gameplay") {
    NavigationStack {
        HalveItGameplayView(
            game: Game(
                id: "halve_it",
                title: "Halve It",
                description: "Hit targets or halve your score",
                iconName: "divide.circle.fill",
                minPlayers: 1,
                maxPlayers: 4
            ),
            players: [Player.mockGuest1, Player.mockGuest2],
            difficulty: .medium
        )
    }
}
