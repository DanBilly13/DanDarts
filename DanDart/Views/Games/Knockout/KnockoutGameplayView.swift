//
//  KnockoutGameplayView.swift
//  Dart Freak
//
//  Created by DanDarts Team
//

import SwiftUI

struct KnockoutGameplayView: View {
    let game: Game
    let players: [Player]
    let startingLives: Int
    
    @StateObject private var viewModel: KnockoutViewModel
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var router: Router
    @Environment(\.dismiss) private var dismiss
    
    @State private var showInstructions = false
    @State private var showExitConfirmation = false
    @State private var navigateToGameEnd = false
    @StateObject private var menuCoordinator = MenuCoordinator.shared
    @State private var showGameTip: Bool = false
    @State private var currentTip: GameTip? = nil
    
    // Initialize with game, players, and starting lives
    init(game: Game, players: [Player], startingLives: Int) {
        self.game = game
        self.players = players
        self.startingLives = startingLives
        _viewModel = StateObject(wrappedValue: KnockoutViewModel(players: players, startingLives: startingLives))
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
                        message1: tip.message1,
                        message2: tip.message2,
                        onDismiss: {
                            showGameTip = false
                            TipManager.shared.markTipAsSeen(for: game.title)
                        }
                    )
                    .padding(.horizontal, 24)
                }
            } background: {
                VStack(spacing: 0) {
                
                VStack (spacing: 0) {
                    
                    
                    // Score to Beat
                    ScoreToBeatView(score: viewModel.scoreToBeat, showScoreAnimation: viewModel.showScoreAnimation, showSkullWiggle: viewModel.showSkullWiggle)
                    Spacer()
                    
                    // Current Player Card
                    currentPlayerCard
                        .padding(.horizontal, 16)
                    
                    Spacer()
                        .frame(height: 12)
                    // Current throw display (always visible)
                    CurrentThrowDisplay(
                        currentThrow: viewModel.currentThrow,
                        selectedDartIndex: viewModel.selectedDartIndex,
                        onDartTapped: { index in
                            viewModel.selectDart(at: index)
                        },
                        showScore: false
                    )
                    /*Color.clear.frame(height: 12)*/
                    
                    
                    // Points needed text (like checkout suggestion) - HIDDEN for now
                    // VStack {
                    //     Text(viewModel.pointsNeededText)
                    //         .font(.system(size: 14, weight: .medium))
                    //         .foregroundColor(Color("AccentTertiary"))
                    //         .padding(.horizontal, 16)
                    //         .padding(.vertical, 0)
                    // }
                    Spacer()
                    
                    // Avatar Lineup
                    avatarLineup
                    
                    
                    
                    Spacer()
                }
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 8)
                }
                
                // Insert flexible spacer between the two main sections
                Spacer(minLength: 0)
                
                VStack (spacing: 0) {
                    // Scoring button grid (center)
                    ScoringButtonGrid(
                        onScoreSelected: { baseValue, scoreType in
                            let scoredThrow = ScoredThrow(baseValue: baseValue, scoreType: scoreType)
                            viewModel.recordThrow(scoredThrow)
                        },
                        showBustButton: false,
                        onDelete: {
                            viewModel.deleteThrow()
                        },
                        canDelete: viewModel.canDelete
                    )
                    .padding(.horizontal, 16)
                    
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
        }
        .background(AppColor.backgroundPrimary)
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
        .toolbarBackground(AppColor.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled()
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            if TipManager.shared.shouldShowTip(for: game.title) {
                currentTip = TipManager.shared.getTip(for: game.title)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        showGameTip = true
                    }
                }
            }
        }
        .alert("Exit Game", isPresented: $showExitConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Leave Game", role: .destructive) {
                router.popToRoot()
            }
        } message: {
            Text("Are you sure you want to leave the game? Your progress will be lost.")
        }
        .sheet(isPresented: $showInstructions) {
            GameInstructionsView(game: game)
        }
        .onAppear {
            // Inject authService for match saving
            viewModel.authService = authService
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
                    viewModel.restartGame()
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
                matchId: viewModel.matchId,
                matchResult: nil
            )
        }
    }
    
    
    // MARK: - Avatar Lineup
    
    private var avatarLineup: some View {
        let dynamicRingColor = viewModel.currentTurnTotal > viewModel.scoreToBeat ? AppColor.player2 : AppColor.player1
        
        return HStack(spacing: -2) {
            ForEach(viewModel.players) { player in
                AvatarLineupItem(
                    player: player,
                    isCurrentPlayer: player.id == viewModel.currentPlayer.id,
                    isEliminated: viewModel.eliminatedPlayers.contains(player.id),
                    ringColor: dynamicRingColor
                )
            }
        }
    }
    
    // MARK: - Current Player Card
    
    private var currentPlayerCard: some View {
        let dynamicBorderColor = viewModel.currentTurnTotal > viewModel.scoreToBeat ? AppColor.player2 : AppColor.player1
        
        return KnockoutPlayerCard(
            player: viewModel.currentPlayer,
            lives: viewModel.playerLives[viewModel.currentPlayer.id] ?? 0,
            startingLives: viewModel.startingLives,
            score: viewModel.currentTurnTotal,
            scoreToBeat: viewModel.scoreToBeat,
            isPlayerToBeat: false,
            borderColor: dynamicBorderColor,
            animatingLifeLoss: viewModel.animatingLifeLoss == viewModel.currentPlayer.id,
            animatingTransition: viewModel.animatingPlayerTransition,
            showScorePop: viewModel.showPlayerScorePop
        )
        .animation(.easeInOut(duration: 0.4), value: viewModel.animatingPlayerTransition)
    }
    
}

// MARK: - Avatar Lineup Item

struct AvatarLineupItem: View {
    let player: Player
    let isCurrentPlayer: Bool
    let isEliminated: Bool
    let ringColor: Color
    
    var body: some View {
        ZStack {
            // Outer circle - only visible when current player, color based on score
            Circle()
                .fill(ringColor)
                .frame(width: 36, height: 36)
                .opacity(isCurrentPlayer ? 1.0 : 0.0)
            
            // Inner black circle - only visible when current player
            Circle()
                .fill(Color.black)
                .frame(width: 32, height: 32)
                .opacity(isCurrentPlayer ? 1.0 : 0.0)
            
            // Avatar - always present, just changes size
            AsyncAvatarImage(
                avatarURL: player.avatarURL,
                size: isCurrentPlayer ? 28 : 36
            )
            .opacity(isEliminated ? 0.3 : 1.0)
        }
        .frame(width: 36, height: 36)
        .animation(.easeInOut(duration: 1.2), value: isCurrentPlayer)
    }
}

// MARK: - Knockout Player Card

struct KnockoutPlayerCard: View {
    let player: Player
    let lives: Int
    let startingLives: Int
    let score: Int
    let scoreToBeat: Int
    let isPlayerToBeat: Bool
    let borderColor: Color
    let animatingLifeLoss: Bool
    let animatingTransition: Bool
    let showScorePop: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AsyncAvatarImage(
                avatarURL: player.avatarURL,
                size: 48
            )
            .opacity(animatingTransition ? 0 : 1)
            
            // Player Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(player.displayName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColor.textPrimary)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    Text(player.nickname)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColor.textSecondary)
                        .lineLimit(1)
                    
                    // Lives (hearts) - show all hearts, lost ones filled with background
                    HStack(spacing: 4) {
                        ForEach(0..<startingLives, id: \.self) { index in
                            let isLosingLife = animatingLifeLoss && index == (lives - 1)
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(index < lives ? .white : Color.white.opacity(0.25))
                                .scaleEffect(isLosingLife ? 3.0 : 1.0)
                                .animation(.timingCurve(0.5, 1.4, 0.5, 1.0, duration: 0.15), value: isLosingLife)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(animatingTransition ? 0 : 1)
            
            // Score Section
            HStack(spacing: 6) {
                // Crown for player to beat
                if isPlayerToBeat {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.yellow)
                }
                
                Text("\(score)")
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(AppColor.textPrimary)
                    .frame(width: 60, alignment: .trailing)
                    .scaleEffect(showScorePop ? 1.35 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.4), value: showScorePop)
                
                // Points needed indicator - only show when there's a score to beat AND player has thrown
                if scoreToBeat > 0 && score > 0 {
                    HStack(spacing: 2) {
                        if score > scoreToBeat {
                            Image(systemName: "arrow.up")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColor.player2)
                        } else if score < scoreToBeat {
                            Image(systemName: "arrow.down")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColor.player1)
                        } else {
                            Image(systemName: "minus")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColor.player1)
                        }
                        
                        Text("\(abs(score - scoreToBeat))")
                            .font(.headline)
                            .foregroundColor(score > scoreToBeat ? AppColor.player2 : AppColor.player1)
                    }
                    .padding(.vertical, 4)
                    .padding(.leading, 4)
                    .padding(.trailing, 6)
                    .background(AppColor.backgroundPrimary)
                    .cornerRadius(9)
                }
            }
            .opacity(animatingTransition ? 0 : 1)
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
        .padding(.leading, 16)
        .padding(.trailing, 24)
        .background(
            Capsule()
                .fill(AppColor.inputBackground)
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
        KnockoutGameplayView(
            game: Game(
                title: "Knockout",
                subtitle: "Beat the Previous Player or Lose a Life",
                players: "2 or more",
                instructions: "The first player throws three darts to set a score. The next player must beat that score, or they lose a life. The winner is the final player left with one or more lives remaining."
            ),
            players: [
                Player.mockGuest1,
                Player.mockGuest2,
                Player.mockGuest3
            ],
            startingLives: 3
        )
        .environmentObject(AuthService.mockAuthenticated)
        .background(AppColor.backgroundPrimary)
    }
}
