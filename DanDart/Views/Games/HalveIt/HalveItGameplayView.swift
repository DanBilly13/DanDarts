//
//  HalveItGameplayView.swift
//  Dart Freak
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
    @State private var isScoreboardExpanded: Bool = false
    @State private var showGameTip: Bool = false
    @State private var currentTip: GameTip? = nil
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var router: Router
    
    // Initialize with game, players, and difficulty
    init(game: Game, players: [Player], difficulty: HalveItDifficulty) {
        self.game = game
        self.players = players
        self.difficulty = difficulty
        _viewModel = StateObject(wrappedValue: HalveItViewModel(players: players, difficulty: difficulty, gameId: game.id))
    }
    
    var body: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()
            
            // Core gameplay layout, wrapped with PositionedTip for proper nav bar spacing
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
                ZStack {
                    VStack(spacing: 0) {
                    // TOP — cards / throw / targets
                    VStack(spacing: 0) {
                        // Player score cards
                        StackedPlayerCards(
                            players: viewModel.players,
                            currentPlayerIndex: viewModel.currentPlayerIndex,
                            playerScores: viewModel.playerScores,
                            currentThrow: viewModel.currentThrow,
                            legsWon: [:],
                            matchFormat: 1,
                            showScoreAnimation: viewModel.showScoreAnimation,
                            isExpanded: isScoreboardExpanded,
                            onTap: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isScoreboardExpanded = true
                                }
                            },
                            getOriginalIndex: nil
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 56)

                        // Current throw display
                        HalveItThrowDisplay(
                            currentThrow: viewModel.currentThrow,
                            selectedDartIndex: viewModel.selectedDartIndex,
                            currentTarget: viewModel.currentTarget,
                            onDartTapped: { index in
                                viewModel.selectDart(at: index)
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Target progression — now height-matched to Countdown
                        TargetProgressView(
                            targets: viewModel.targets,
                            currentRound: viewModel.currentRound
                        )
                        .frame(height: 40)
                        .padding(.top, 8)

                        // Collapsible spacer (matches Countdown)
                        Spacer(minLength: 0)
                    }
                    
                    // Flexible gap between halves (grows on large phones)
                    Spacer(minLength: 0)
                    
                    // BOTTOM — scoring grid + save
                    VStack(spacing: 0) {
                        // Scoring button grid (no bust button for Halve-It)
                        ScoringButtonGrid(
                            onScoreSelected: { baseValue, scoreType in
                                viewModel.recordThrow(baseValue: baseValue, scoreType: scoreType)
                            },
                            showBustButton: false
                        )
                        .padding(.horizontal, 16)
                        
                        // Small breathing room between grid and button
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
                }

                // When expanded, swallow taps anywhere in the gameplay area
                // so the scoreboard behaves like a modal overlay. The
                // navigation bar (above this view) remains interactive.
                if isScoreboardExpanded {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea(.container, edges: .bottom)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isScoreboardExpanded = false
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Halve It • \(difficulty.rawValue)")
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
            viewModel.setAuthService(authService)
            
            // Show game-specific tip if available and not seen before
            if TipManager.shared.shouldShowTip(for: game.title) {
                currentTip = TipManager.shared.getTip(for: game.title)
                // Slight delay so it appears after navigation transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        showGameTip = true
                    }
                }
            }
        }
        .alert("Exit Game", isPresented: $showExitAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Leave Game", role: .destructive) {
                router.popToRoot()
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
        .environmentObject(AuthService())
        .background(AppColor.backgroundPrimary)
    }
}
