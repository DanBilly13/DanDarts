//
//  CountdownGameplayView.swift
//  Dart Freak
//
//  Full-screen gameplay view for countdown games (301/501)
//  Design: Calculator-inspired scoring with dark theme
//

import SwiftUI

struct RemoteGameplayView: View {
    let match: RemoteMatch
    let challenger: User
    let receiver: User
    let currentUserId: UUID
    
    // Game state managed by ViewModel
    @StateObject private var gameViewModel: CountdownViewModel
    @StateObject private var menuCoordinator = MenuCoordinator.shared
    @State private var showInstructions: Bool = false
    @State private var showRestartAlert: Bool = false
    @State private var showExitAlert: Bool = false
    @State private var showUndoConfirmation: Bool = false
    @State private var navigateToGameEnd: Bool = false
    @State private var showLegWinCelebration: Bool = false
    @State private var showGameTip: Bool = false
    @State private var currentTip: GameTip? = nil
    @State private var isScoreboardExpanded: Bool = false
    @State private var isSaving: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var router: Router
    
    private var adapter: RemoteGameStateAdapter {
        RemoteGameStateAdapter(
            match: match,
            challenger: challenger,
            receiver: receiver,
            currentUserId: currentUserId
        )
    }

    // MARK: - Derived UI State
    private var flowOverlayState: RemoteGameStateAdapter.OverlayState {
        // CountdownViewModel does not own an isSaving flag; keep this view-local for now.
        adapter.overlayState(isSaving: isSaving)
    }

    // MARK: - View Extraction (helps the SwiftUI type-checker)
    private var backgroundLayer: some View {
        AppColor.backgroundPrimary
            .ignoresSafeArea()
    }

    @ViewBuilder
    private func gameplayContent(_ overlayState: RemoteGameStateAdapter.OverlayState) -> some View {
        // Core gameplay layout, optionally wrapped with a positioned tip overlay
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
                        TipManager.shared.markTipAsSeen(for: match.gameName)
                    }
                )
                .padding(.horizontal, 24)
            }
        } background: {
            gameplayStack(overlayState)
        }
    }

    @ViewBuilder
    private func gameplayStack(_ overlayState: RemoteGameStateAdapter.OverlayState) -> some View {
        ZStack {
            VStack(spacing: 0) {
                topSection
                Spacer(minLength: 0)
                bottomSection
            }

            // Turn lockout overlay (inactive player or saving state)
            if overlayState.isVisible {
                TurnLockoutOverlay(
                    overlayState: overlayState,
                    opponentName: adapter.opponent.displayName,
                    lastVisitValue: adapter.lastVisitValue
                )
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

    private var topSection: some View {
        VStack(spacing: 0) {
            // Stacked player cards (current player in front / expandable into column)
            StackedPlayerCards(
                players: gameViewModel.players,
                currentPlayerIndex: gameViewModel.currentPlayerIndex,
                playerScores: gameViewModel.playerScores,
                currentThrow: gameViewModel.currentThrow,
                legsWon: gameViewModel.legsWon,
                matchFormat: gameViewModel.matchFormat,
                showScoreAnimation: gameViewModel.showScoreAnimation,
                isExpanded: isScoreboardExpanded,
                onTap: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isScoreboardExpanded = true
                    }
                },
                getOriginalIndex: { player in
                    gameViewModel.originalIndex(of: player)
                }
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
    }

    private var bottomSection: some View {
        VStack(spacing: 0) {
            // Scoring button grid (center)
            ScoringButtonGrid(
                onScoreSelected: { baseValue, scoreType in
                    gameViewModel.recordThrow(value: baseValue, multiplier: scoreType.multiplier)
                },
                showBustButton: gameViewModel.canBust,
                onDelete: {
                    gameViewModel.deleteThrow()
                },
                canDelete: gameViewModel.canDelete
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
                    action: {
                        // View-local saving flag (remote RPC wiring comes in Phase 4)
                        isSaving = true
                        gameViewModel.saveScore()
                        // Reset quickly to avoid sticking UI in saving state for local logic
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isSaving = false
                        }
                    }
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
    
    init(match: RemoteMatch, challenger: User, receiver: User, currentUserId: UUID) {
        self.match = match
        self.challenger = challenger
        self.receiver = receiver
        self.currentUserId = currentUserId
        
        let adapter = RemoteGameStateAdapter(
            match: match,
            challenger: challenger,
            receiver: receiver,
            currentUserId: currentUserId
        )
        let players = adapter.createPlayersArray()
        let game = Game(
            title: match.gameName,
            subtitle: "Remote Match",
            players: "2 Players",
            instructions: ""
        )
        
        _gameViewModel = StateObject(
            wrappedValue: CountdownViewModel(
                game: game,
                players: players,
                matchFormat: match.matchFormat
            )
        )
    }
    
    // Computed property for navigation title
    private var navigationTitle: String {
        let gameTitle = match.gameName // "301" or "501"
        
        // Remote matches are always 2 players
        if gameViewModel.matchFormat > 1 {
            // Multi-leg match
            return "\(gameTitle)  LEG \(gameViewModel.currentLeg)/\(gameViewModel.matchFormat)  VISIT \(gameViewModel.currentVisit)"
        } else {
            // Single game (best of 1)
            return "\(gameTitle)  VISIT \(gameViewModel.currentVisit)"
        }
    }
    
    var body: some View {
        let overlayState = flowOverlayState

        ZStack {
            backgroundLayer
            gameplayContent(overlayState)
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        GameplayMenuButton(
                            onInstructions: { showInstructions = true },
                            onRestart: { showRestartAlert = true },
                            onExit: { showExitAlert = true },
                            onUndo: { showUndoConfirmation = true },
                            canUndo: gameViewModel.canUndo
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

                    // Show game-specific tip if available and not seen before
                    if TipManager.shared.shouldShowTip(for: match.gameName) {
                        currentTip = TipManager.shared.getTip(for: match.gameName)
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
                .alert("Undo Last Visit", isPresented: $showUndoConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Undo", role: .destructive) {
                        gameViewModel.undoLastVisit()
                    }
                } message: {
                    if let visit = gameViewModel.lastVisit {
                        Text("Undo visit by \(visit.playerName)?\n\nScore will revert from \(visit.newScore) to \(visit.previousScore).")
                    } else {
                        Text("Undo the last visit?")
                    }
                }
                .sheet(isPresented: $showInstructions) {
                    EmptyView()
                }
                .onChange(of: gameViewModel.legWinner) { _, newValue in
                    if newValue != nil && !gameViewModel.isMatchWon {
                        // Leg won but match continues - show celebration
                        showLegWinCelebration = true
                    }
                }
                .onChange(of: gameViewModel.winner) { _, newValue in
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
                        let tempGame = Game(
                            title: match.gameName,
                            subtitle: "Remote Match",
                            players: "2 Players",
                            instructions: ""
                        )
                        GameEndView(
                            game: tempGame,
                            winner: winner,
                            players: gameViewModel.players,
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
                            matchId: gameViewModel.matchId,
                            matchResult: gameViewModel.savedMatchResult
                        )
                    }
                }
        }

        // MARK: - Game Logic
        // All game logic now handled by GameViewModel
    }
}

// MARK: - Checkout Suggestion View

extension RemoteGameplayView {
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
}

// MARK: - Turn Lockout Overlay Component

struct TurnLockoutOverlay: View {
    let overlayState: RemoteGameStateAdapter.OverlayState
    let opponentName: String
    let lastVisitValue: Int?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
                
                Text(mainMessage)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                
                if let subtitle = subtitleMessage {
                    Text(subtitle)
                        .font(.body)
                        .foregroundColor(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: overlayState)
    }
    
    private var iconName: String {
        switch overlayState {
        case .none: return ""
        case .inactiveLockout: return "hourglass"
        case .saving: return "arrow.up.circle.fill"
        }
    }
    
    private var mainMessage: String {
        switch overlayState {
        case .none: return ""
        case .inactiveLockout: return "\(opponentName) is throwing"
        case .saving: return "Saving visit..."
        }
    }
    
    private var subtitleMessage: String? {
        switch overlayState {
        case .none: return nil
        case .inactiveLockout:
            if let lastVisit = lastVisitValue {
                return "Last visit: \(lastVisit)"
            }
            return "Waiting for opponent"
        case .saving: return "Please wait"
        }
    }
}
