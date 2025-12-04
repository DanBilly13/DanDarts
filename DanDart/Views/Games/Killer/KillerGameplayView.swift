//
//  KillerGameplayView.swift
//  DanDart
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
            if isOver, let winner = viewModel.winner {
                navigateToGameEnd = true
                
                // Save match data
                let (turns, matchId) = viewModel.getMatchData()
                
                // Create match players
                let matchPlayers = players.map { player in
                    MatchPlayer.from(
                        player: player,
                        finalScore: 0,
                        startingScore: 0,
                        totalDartsThrown: turns.filter { turn in
                            // Count darts for this player (Killer doesn't track per-player turns)
                            true
                        }.reduce(0) { $0 + $1.darts.count },
                        turns: turns
                    )
                }
                
                let matchResult = MatchResult(
                    gameType: "Killer",
                    gameName: game.title,
                    players: matchPlayers,
                    winnerId: winner.id,
                    duration: 0,
                    matchFormat: 1,
                    totalLegsPlayed: 1
                )
                
                MatchStorageManager.shared.saveMatch(matchResult)
                
                // Navigate to game end after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    router.push(.gameEnd(
                        game: game,
                        winner: winner,
                        players: players,
                        onPlayAgain: {
                            router.pop(count: 2)
                            router.push(.preGameHype(
                                game: game,
                                players: players,
                                matchFormat: 1,
                                killerLives: startingLives
                            ))
                        },
                        onBackToGames: {
                            router.popToRoot()
                        },
                        matchFormat: nil,
                        legsWon: nil,
                        matchId: matchId
                    ))
                }
            }
        }
    }
    
    // MARK: - Player Cards Row
    
    private var playerCardsRow: some View {
        // Show all players with lives > 0
        let playersToShow = viewModel.activePlayers
        
        // Spacing based on player count
        let spacing: CGFloat = {
            switch playersToShow.count {
            case 2: return 64
            case 3: return 48
            case 4: return 32
            case 5: return -6
            case 6: return -8
            case 7: return -8
            case 8: return -8
            default: return 32
            }
        }()
        
        // Card width based on player count
        let cardWidth: CGFloat = {
            switch playersToShow.count {
            case 2: return 100
            case 3: return 80
            case 4: return 70
            case 5: return 64
            case 6: return 64
            default: return 64
            }
        }()
        
        return HStack(spacing: spacing) {
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
                    cardWidth: cardWidth
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
