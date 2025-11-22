//
//  CountdownGameplayView.swift
//  DanDart
//
//  Full-screen gameplay view for countdown games (301/501)
//  Design: Calculator-inspired scoring with dark theme
//

import SwiftUI

struct CountdownGameplayView: View {
    let game: Game
    let players: [Player]
    let matchFormat: Int
    
    // Game state managed by ViewModel
    @StateObject private var gameViewModel: CountdownViewModel
    @StateObject private var menuCoordinator = MenuCoordinator.shared
    @State private var showInstructions: Bool = false
    @State private var showRestartAlert: Bool = false
    @State private var showExitAlert: Bool = false
    @State private var navigateToGameEnd: Bool = false
    @State private var showLegWinCelebration: Bool = false
    @State private var showDoubleTripleTip: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var router: Router
    
    // Initialize with game and players
    init(game: Game, players: [Player], matchFormat: Int = 1) {
        self.game = game
        self.players = players
        self.matchFormat = matchFormat
        _gameViewModel = StateObject(wrappedValue: CountdownViewModel(game: game, players: players, matchFormat: matchFormat))
    }
    
    var body: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()
            
            // Core gameplay layout, optionally wrapped with a positioned tip overlay
            PositionedTip(
                xPercent: 0.5,
                yPercent: 0.8
            ) {
                if showDoubleTripleTip {
                    TipBubble(
                        systemImageName: "cursorarrow.click",
                        title: "Doubles & Trebles",
                        message: "Long-press any number button to choose single, double, or treble before you lift your finger.",
                        onDismiss: {
                            showDoubleTripleTip = false
                            UserDefaults.standard.set(true, forKey: "hasSeenDoubleTripleTip")
                        }
                    )
                    .padding(.horizontal, 24)
                }
            } background: {
                VStack(spacing: 0) {
                    // TOP — cards / throw / checkout
                    VStack(spacing: 0) {
                        // Stacked player cards (current player in front)
                        StackedPlayerCards(
                            players: gameViewModel.players,
                            currentPlayerIndex: gameViewModel.currentPlayerIndex,
                            playerScores: gameViewModel.playerScores,
                            currentThrow: gameViewModel.currentThrow,
                            legsWon: gameViewModel.legsWon,
                            matchFormat: gameViewModel.matchFormat,
                            showScoreAnimation: gameViewModel.showScoreAnimation
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 56)
                        
                        // Current throw display (always visible)
                        CurrentThrowDisplay(
                            currentThrow: gameViewModel.currentThrow,
                            selectedDartIndex: gameViewModel.selectedDartIndex,
                            onDartTapped: { index in
                                gameViewModel.selectDart(at: index)
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        
                        // Checkout suggestion slot
                        VStack {
                            if let checkout = gameViewModel.suggestedCheckout {
                                CheckoutSuggestionView(checkout: checkout)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 0)
                            }
                        }
                        .frame(height: 40, alignment: .center)
                        .padding(.bottom, 8)
                        
                        Spacer(minLength: 0)
                    }
                    
                    // Flexible gap between halves (grows on large phones)
                    Spacer(minLength: 0)
                    
                    // BOTTOM — scoring grid + save
                    VStack(spacing: 0) {
                        // Scoring button grid (center)
                        ScoringButtonGrid(
                            onScoreSelected: { baseValue, scoreType in
                                gameViewModel.recordThrow(value: baseValue, multiplier: scoreType.multiplier)
                            },
                            showBustButton: gameViewModel.canBust
                        )
                        .padding(.horizontal, 16)
                        
                        // Small breathing room between grid and button (replaces Spacer)
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
                                role: gameViewModel.isWinningThrow ? .secondary : .primary,
                                controlSize: .extraLarge,
                                action: { gameViewModel.saveScore() }
                            ) {
                                if gameViewModel.isWinningThrow {
                                    Label("Save Score", systemImage: "trophy.fill")
                                } else if gameViewModel.isBust {
                                    Text("Bust")
                                } else {
                                    Label("Save Score", systemImage: "checkmark.circle.fill")
                                }
                            }
                            .blur(radius: menuCoordinator.activeMenuId != nil ? 2 : 0)
                            .opacity(menuCoordinator.activeMenuId != nil ? 0.4 : 1.0)
                            // Reusable pop animation (applies to all button states)
                            .popAnimation(
                                active: gameViewModel.isTurnComplete,
                                duration: gameViewModel.isWinningThrow ? 0.32 : 0.28,
                                bounce: gameViewModel.isWinningThrow ? 0.28 : 0.22
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 34)
                    }
                }
            }
            .navigationTitle(gameViewModel.matchFormat > 1 ? "Leg \(gameViewModel.currentLeg)/\(gameViewModel.matchFormat)" : game.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GameplayMenuButton(
                        onInstructions: { showInstructions = true },
                        onRestart: { showRestartAlert = true },
                        onExit: { showExitAlert = true }
                    )
                }
            }
            .toolbarBackground(AppColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .navigationBarBackButtonHidden(true)
            .interactiveDismissDisabled()
            .ignoresSafeArea(.container, edges: .bottom)
            .onAppear {
                // Inject authService into the ViewModel
                gameViewModel.setAuthService(authService)
                
                // Show long-press tip only once for 301 games
                let isCountdown301 = game.title.contains("301")
                let hasSeenTip = UserDefaults.standard.bool(forKey: "hasSeenDoubleTripleTip")
                
                #if DEBUG
                let shouldShowTip = isCountdown301
                #else
                let shouldShowTip = isCountdown301 && !hasSeenTip
                #endif
                
                if shouldShowTip {
                    // Slight delay so it appears after navigation transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            showDoubleTripleTip = true
                        }
                    }
                }
            }
            .alert("Exit Game", isPresented: $showExitAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Leave Game", role: .destructive) {
                    // Pop to root (games list)
                    router.popToRoot()
                }
            } message: {
                Text("Are you sure you want to leave the game? Your progress will be lost.")
            }
            .alert("Restart Game", isPresented: $showRestartAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Restart", role: .destructive) {
                    gameViewModel.restartGame()
                }
            } message: {
                Text("Are you sure you want to restart the game? All progress will be lost.")
            }
            .sheet(isPresented: $showInstructions) {
                GameInstructionsView(game: game)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: gameViewModel.legWinner) { oldValue, newValue in
                if newValue != nil && !gameViewModel.isMatchWon {
                    // Leg won but match continues - show celebration
                    showLegWinCelebration = true
                }
            }
            .onChange(of: gameViewModel.winner) { oldValue, newValue in
                if newValue != nil {
                    // Match winner detected - navigate to game end screen after brief delay
                    // This ensures all state updates are complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigateToGameEnd = true
                    }
                }
            }
            .alert("Leg Won!", isPresented: $showLegWinCelebration) {
                Button("Next Leg") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        gameViewModel.resetLeg()
                    }
                }
            } message: {
                if let legWinner = gameViewModel.legWinner {
                    let winnerLegs = gameViewModel.legsWon[legWinner.id] ?? 0
                    Text("\(legWinner.displayName) wins the leg! (\(winnerLegs) legs won)")
                }
            }
            .navigationDestination(isPresented: $navigateToGameEnd) {
                if let winner = gameViewModel.winner {
                    GameEndView(
                        game: game,
                        winner: winner,
                        players: players,
                        onPlayAgain: {
                            // Reset game with same players
                            gameViewModel.restartGame()
                            navigateToGameEnd = false
                        },
                        onChangePlayers: {
                            // Navigate back to game setup
                            navigateToGameEnd = false
                            dismiss()
                        },
                        onBackToGames: {
                            // Navigate back to games list
                            router.popToRoot()
                        },
                        matchFormat: gameViewModel.isMultiLegMatch ? gameViewModel.matchFormat : nil,
                        legsWon: gameViewModel.isMultiLegMatch ? gameViewModel.legsWon : nil,
                        matchId: gameViewModel.matchId
                    )
                }
            }
        }
        
        // MARK: - Game Logic
        // All game logic now handled by GameViewModel
    }
    
    
    
    // MARK: - Checkout Suggestion View
    
    struct CheckoutSuggestionView: View {
        let checkout: String
        
        var body: some View {
            Text("Checkout: \(checkout)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColor.brandPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: checkout)
        }
    }
    
    
    // MARK: - Preview
    #Preview("Countdown - 301") {
        NavigationStack {
            CountdownGameplayView(
                game: Game.preview301,
                players: [Player.mockGuest1, Player.mockGuest2]
            )
            .environmentObject(AuthService())
            .background(AppColor.backgroundPrimary)
        }
    }
    
    #Preview("Best of 3") {
        NavigationStack {
            CountdownGameplayView(
                game: Game.preview301,
                players: [Player.mockGuest1, Player.mockGuest2],
                matchFormat: 3
            )
            .environmentObject(AuthService())
            .background(AppColor.backgroundPrimary)
        }
    }
    
    #Preview("Best of 5") {
        NavigationStack {
            CountdownGameplayView(
                game: Game.preview501,
                players: [Player.mockGuest1, Player.mockGuest2],
                matchFormat: 5
            )
            .environmentObject(AuthService())
            .background(AppColor.backgroundPrimary)
        }
    }
    
    #Preview("Best of 7 - 4 Players") {
        NavigationStack {
            CountdownGameplayView(
                game: Game.preview301,
                players: [Player.mockGuest1, Player.mockGuest2, Player.mockConnected1, Player.mockConnected2],
                matchFormat: 7
            )
            .environmentObject(AuthService())
            .background(AppColor.backgroundPrimary)
        }
    }
    
    #Preview("3 Players") {
        NavigationStack {
            CountdownGameplayView(
                game: Game.preview301,
                players: [Player.mockGuest1, Player.mockGuest2, Player.mockConnected1]
            )
            .environmentObject(AuthService())
            .background(AppColor.backgroundPrimary)
        }
    }
}
