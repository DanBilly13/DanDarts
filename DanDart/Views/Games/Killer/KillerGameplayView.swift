//
//  KillerGameplayView.swift
//  Dart Freak
//
//  Main gameplay view for Killer game mode
//  Layout adapted from Sudden Death with Killer-specific components
//

import SwiftUI

struct KillerGameplayView: View {
    let game: Game
    let players: [Player]
    let startingLives: Int
    
    @StateObject private var viewModel: KillerViewModel
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var router: Router
    @Environment(\.dismiss) private var dismiss
    
    @State private var showInstructions = false
    @State private var showExitConfirmation = false
    @State private var navigateToGameEnd = false
    @State private var showGameTip: Bool = false
    @State private var currentTip: GameTip? = nil
    
    // Initialize with game, players, and starting lives
    init(game: Game, players: [Player], startingLives: Int) {
        self.game = game
        self.players = players
        self.startingLives = startingLives
        _viewModel = StateObject(wrappedValue: KillerViewModel(players: players, startingLives: startingLives))
    }
    
    var body: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()
            
            PositionedTip(
                xPercent: 0.5,
                yPercent: 0.55
            ) {
                if showGameTip, let tip = currentTip {
                    TipBubble(
                        systemImageName: tip.icon,
                        title: tip.title,
                        message: tip.message,
                        onDismiss: {
                            showGameTip = false
                            TipManager.shared.markTipAsSeen(for: game.title)
                        }
                    )
                    .padding(.horizontal, 24)
                }
            } background: {
                VStack(spacing: 0) {
                // TOP HALF — player cards + current throw
                VStack {
                    playerCardsRow
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                    
                    Spacer(minLength: 0)
                    
                    CurrentThrowDisplay(
                        currentThrow: viewModel.currentThrow,
                        selectedDartIndex: viewModel.selectedDartIndex,
                        onDartTapped: { index in
                            viewModel.selectedDartIndex = index
                        },
                        showScore: false
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 0)
                    
                    Spacer(minLength: 0)
                }
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 16)
                }
                
                // Flexible space between top and bottom halves
                Spacer(minLength: 0)
                
                // BOTTOM HALF — scoring grid + Save Score button
                VStack(spacing: 0) {
                    ScoringButtonGrid(
                        onScoreSelected: { baseValue, scoreType in
                            viewModel.recordThrow(value: baseValue, multiplier: scoreType.multiplier)
                        },
                        showBustButton: false
                    )
                    .padding(.horizontal, 16)
                    
                    Color.clear.frame(height: 24)
                    
                    ZStack {
                        AppButton(role: .primary, controlSize: .extraLarge, action: {}) {
                            Text("Save Score")
                        }
                        .opacity(0)
                        .disabled(true)
                        
                        AppButton(
                            role: .primary,
                            controlSize: .extraLarge,
                            action: { viewModel.completeTurn() }
                        ) {
                            Label("Save Score", systemImage: "checkmark.circle.fill")
                        }
                        .popAnimation(
                            active: viewModel.canSave,
                            duration: 0.28,
                            bounce: 0.22
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 34)
                }
            }
            }
        }
        .background(AppColor.backgroundPrimary)
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(game.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.anyPlayerIsKiller ? AppColor.interactivePrimaryBackground : AppColor.justWhite)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                GameplayMenuButton(
                    onInstructions: { showInstructions = true },
                    onRestart: {
                        // Reset game
                        router.pop()
                        router.push(.gameSetup(game: game))
                    },
                    onExit: {
                        showExitConfirmation = true
                    }
                )
            }
        }
        .toolbarBackground(AppColor.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .interactiveDismissDisabled()
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            // Show game-specific tip if available and not seen before
            if TipManager.shared.shouldShowTip(for: game.title) {
                currentTip = TipManager.shared.getTip(for: game.title)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        showGameTip = true
                    }
                }
            }
        }
        .sheet(isPresented: $showInstructions) {
            GameInstructionsView(game: game)
        }
        .alert("Exit Game?", isPresented: $showExitConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Exit", role: .destructive) {
                router.popToRoot()
            }
        } message: {
            Text("Your progress will be lost.")
        }
        .onChange(of: viewModel.isGameOver) { _, isOver in
            if isOver {
                navigateToGameEnd = true
            }
        }
        .navigationDestination(isPresented: $navigateToGameEnd) {
            GameEndView(
                game: game,
                winner: viewModel.winner ?? players[0],
                players: players,
                onPlayAgain: {
                    navigateToGameEnd = false
                    router.pop()
                    router.push(.preGameHype(
                        game: game,
                        players: players,
                        matchFormat: 1,
                        killerLives: startingLives
                    ))
                },
                onChangePlayers: {
                    navigateToGameEnd = false
                    dismiss()
                },
                onBackToGames: {
                    router.popToRoot()
                },
                matchFormat: nil,
                legsWon: nil,
                matchId: viewModel.matchId
            )
        }
    }
    
    // MARK: - Player Cards Row
    
    private var playerCardsRow: some View {
        // Show all players with lives > 0
        let playersToShow = viewModel.activePlayers
        
        // Use PlayerCardLayout for consistent spacing and sizing
        let layout = PlayerCardLayout(playerCount: playersToShow.count)
        
        return HStack(spacing: layout.spacing) {
            ForEach(playersToShow) { player in
                KillerPlayerCard2(
                    player: player,
                    assignedNumber: viewModel.playerNumbers[player.id] ?? 0,
                    isKiller: viewModel.isKiller[player.id] ?? false,
                    lives: viewModel.displayPlayerLives[player.id] ?? 0,
                    startingLives: viewModel.startingLives,
                    isCurrentPlayer: player.id == viewModel.currentPlayer.id,
                    animatingKillerActivation: viewModel.animatingKillerActivation == player.id,
                    animatingLifeLoss: viewModel.animatingLifeLoss == player.id,
                    animatingGunSpin: viewModel.animatingGunSpin == player.id,
                    playerIndex: viewModel.players.firstIndex(where: { $0.id == player.id }) ?? 0,
                    cardWidth: layout.cardWidth
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: 160)
    }
}

// MARK: - Previews

#Preview("Killer - 2 Players") {
    NavigationStack {
        KillerGameplayView(
            game: Game(
                title: "Killer",
                subtitle: "It's Kill or Be Killed",
                players: "2-6",
                instructions: "You start the game with a randomly assigned number between 1 and 20..."
            ),
            players: [
                Player.mockGuest1,
                Player.mockGuest2
            ],
            startingLives: 3
        )
        .environmentObject(AuthService.mockAuthenticated)
        .environmentObject(Router.shared)
    }
}

#Preview("Killer - 4 Players") {
    NavigationStack {
        KillerGameplayView(
            game: Game(
                title: "Killer",
                subtitle: "It's Kill or Be Killed",
                players: "2-6",
                instructions: "You start the game with a randomly assigned number between 1 and 20..."
            ),
            players: [
                Player.mockGuest1,
                Player.mockGuest2,
                Player(id: UUID(), displayName: "Alice", nickname: "Alice", avatarURL: nil),
                Player(id: UUID(), displayName: "Bob", nickname: "Bob", avatarURL: nil)
            ],
            startingLives: 5
        )
        .environmentObject(AuthService.mockAuthenticated)
        .environmentObject(Router.shared)
    }
}

#Preview("Killer - 6 Players") {
    NavigationStack {
        KillerGameplayView(
            game: Game(
                title: "Killer",
                subtitle: "It's Kill or Be Killed",
                players: "2-6",
                instructions: "You start the game with a randomly assigned number between 1 and 20..."
            ),
            players: [
                Player.mockGuest1,
                Player.mockGuest2,
                Player.mockGuest1,
                Player.mockGuest2,
                Player.mockGuest1,
                Player.mockGuest2,
            ],
            startingLives: 5
        )
        .environmentObject(AuthService.mockAuthenticated)
        .environmentObject(Router.shared)
    }
}
