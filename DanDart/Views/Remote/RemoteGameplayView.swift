//
//  RemoteGameplayView.swift
//  DanDart
//
//  Remote match gameplay view for 301/501
//  Server-authoritative with realtime sync and turn lockout
//

import SwiftUI

struct RemoteGameplayView: View {
    let matchId: UUID
    
    // Game state managed by ViewModel
    @StateObject private var gameViewModel: RemoteGameplayViewModel
    @StateObject private var menuCoordinator = MenuCoordinator.shared
    @State private var showExitAlert: Bool = false
    @State private var navigateToGameEnd: Bool = false
    @State private var isScoreboardExpanded: Bool = false
    @State private var hasAttemptedInitialLoad = false
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var router: Router
    @EnvironmentObject var remoteMatchService: RemoteMatchService
    @EnvironmentObject var authService: AuthService
    
    // Computed from service's published state (DO NOT store in @State)
    private var matchWithPlayers: RemoteMatchWithPlayers? {
        if let active = remoteMatchService.activeMatch, active.match.id == matchId {
            return active
        }
        return remoteMatchService.readyMatches.first(where: { $0.match.id == matchId })
    }
    
    private var match: RemoteMatch? { matchWithPlayers?.match }
    private var opponent: User? { matchWithPlayers?.opponent }
    private var currentUser: User? { authService.currentUser }
    
    // CRITICAL: Initialize @StateObject in init() to ensure VM created ONCE per view identity
    init(matchId: UUID) {
        self.matchId = matchId
        
        // Initialize ViewModel with matchId only
        _gameViewModel = StateObject(wrappedValue: RemoteGameplayViewModel(matchId: matchId))
    }
    
    // Computed property for navigation title
    private var navigationTitle: String {
        guard let match = match else { return "Loading..." }
        let gameTitle = match.gameType.uppercased() // "301" or "501"
        let visitNumber = gameViewModel.currentVisit
        let matchFormat = gameViewModel.remoteMatch?.matchFormat ?? 1
        
        if matchFormat > 1 {
            // Multi-leg match
            let legInfo = "LEG 1/\(matchFormat)"
            let visitInfo = "VISIT \(visitNumber)"
            return "\(gameTitle)  \(legInfo)  \(visitInfo)"
        } else {
            // Single game
            return "\(gameTitle)  VISIT \(visitNumber)"
        }
    }
    
    var body: some View {
        Group {
            if match != nil && opponent != nil && currentUser != nil {
                gameplayContent
            } else {
                loadingView
            }
        }
        .task {
            guard !hasAttemptedInitialLoad else { return }
            hasAttemptedInitialLoad = true
            
            if matchWithPlayers == nil, let userId = authService.currentUser?.id {
                try? await remoteMatchService.loadMatches(userId: userId)
            }
        }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    exitButton
                }
            }
            .toolbarBackground(AppColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .navigationBarBackButtonHidden(true)
            .interactiveDismissDisabled()
            .ignoresSafeArea(.container, edges: .bottom)
            .alert("Exit Match", isPresented: $showExitAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Leave Match", role: .destructive) {
                    router.popToRoot()
                }
            } message: {
                Text("Are you sure you want to leave the match? The match will continue.")
            }
            .onChange(of: gameViewModel.winner) { oldValue, newValue in
                if newValue != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigateToGameEnd = true
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToGameEnd) {
                gameEndView
            }
            .onDisappear {
                // Clear navigation latch when leaving gameplay
                RemoteNavigationLatch.shared.clearNavigation(matchId: matchId)
                print("🔄 [RemoteGameplayView] Cleared navigation latch for match \(matchId)")
            }
    }
    
    // MARK: - Sub-Views
    
    private var loadingView: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()
            
            ProgressView("Loading match...")
                .foregroundColor(AppColor.textPrimary)
        }
    }
    
    private var gameplayContent: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                topSection
                Spacer(minLength: 0)
                bottomSection
            }
            
            overlays
        }
    }
    
    private var topSection: some View {
        VStack(spacing: 0) {
            playerCardsSection
            throwDisplaySection
            checkoutSection
            Spacer(minLength: 0)
        }
    }
    
    private var playerCardsSection: some View {
        StackedPlayerCards(
            players: gameViewModel.players,
            currentPlayerIndex: gameViewModel.isMyTurn ? 0 : 1,
            playerScores: gameViewModel.playerScores,
            currentThrow: gameViewModel.currentThrow,
            legsWon: [:],
            matchFormat: gameViewModel.remoteMatch?.matchFormat ?? 1,
            showScoreAnimation: gameViewModel.showScoreAnimation,
            isExpanded: isScoreboardExpanded,
            onTap: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isScoreboardExpanded = true
                }
            },
            getOriginalIndex: { player in
                gameViewModel.playerIndex(for: player)
            }
        )
        .padding(.horizontal, 16)
        .padding(.top, 56)
    }
    
    private var throwDisplaySection: some View {
        CurrentThrowDisplay(
            currentThrow: gameViewModel.currentThrow,
            selectedDartIndex: gameViewModel.selectedDartIndex,
            onDartTapped: { index in
                gameViewModel.selectDart(at: index)
            }
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var checkoutSection: some View {
        VStack {
            if let checkout = gameViewModel.suggestedCheckout {
                CheckoutSuggestionView(checkout: checkout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 0)
            }
        }
        .frame(height: 40, alignment: .center)
        .padding(.bottom, 8)
    }
    
    private var bottomSection: some View {
        VStack(spacing: 0) {
            if !gameViewModel.isMyTurn {
                TurnLockoutOverlay(
                    opponentName: gameViewModel.opponentPlayer.displayName,
                    lastVisit: gameViewModel.revealVisit
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            
            scoringGrid
            Color.clear.frame(height: 24)
            saveButtonContainer
        }
    }
    
    private var scoringGrid: some View {
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
        .opacity(gameViewModel.isMyTurn ? 1.0 : 0.3)
        .disabled(!gameViewModel.isMyTurn)
    }
    
    private var saveButtonContainer: some View {
        ZStack {
            AppButton(role: .primary, controlSize: .extraLarge, action: {}) {
                Text("Save Visit")
            }
            .opacity(0)
            .disabled(true)
            
            if gameViewModel.isMyTurn {
                saveButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 34)
    }
    
    private var saveButton: some View {
        AppButton(
            role: gameViewModel.isWinningThrow ? .secondary : .primary,
            controlSize: .extraLarge,
            action: {
                Task {
                    await gameViewModel.saveVisit()
                }
            }
        ) {
            saveButtonLabel
        }
        .blur(radius: menuCoordinator.activeMenuId != nil ? 2 : 0)
        .opacity(menuCoordinator.activeMenuId != nil ? 0.4 : 1.0)
        .disabled(gameViewModel.isSaving)
        .popAnimation(
            active: gameViewModel.isTurnComplete,
            duration: gameViewModel.isWinningThrow ? 0.32 : 0.28,
            bounce: gameViewModel.isWinningThrow ? 0.28 : 0.22
        )
    }
    
    @ViewBuilder
    private var saveButtonLabel: some View {
        if gameViewModel.isSaving {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
        } else if gameViewModel.isWinningThrow {
            Label("Save Visit", systemImage: "trophy.fill")
        } else if gameViewModel.isBust {
            Text("Bust")
        } else {
            Label("Save Visit", systemImage: "checkmark.circle.fill")
        }
    }
    
    @ViewBuilder
    private var overlays: some View {
        if gameViewModel.showingReveal, let visit = gameViewModel.revealVisit, let currentUser = currentUser {
            RevealOverlay(visit: visit, currentUserId: currentUser.id)
        }
        
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
    
    private var exitButton: some View {
        Button {
            showExitAlert = true
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(AppColor.textSecondary)
        }
    }
    
    @ViewBuilder
    private var gameEndView: some View {
        if let winner = gameViewModel.winner, let match = match {
            GameEndView(
                game: Game(
                    title: match.gameName,
                    subtitle: "Remote Match",
                    players: "2",
                    instructions: ""
                ),
                winner: winner,
                players: gameViewModel.players,
                onPlayAgain: {
                    router.popToRoot()
                },
                onChangePlayers: {
                    router.popToRoot()
                },
                onBackToGames: {
                    router.popToRoot()
                },
                matchFormat: match.matchFormat,
                legsWon: nil,
                matchId: matchId,
                matchResult: nil
            )
        }
    }
}

// MARK: - Turn Lockout Overlay

struct TurnLockoutOverlay: View {
    let opponentName: String
    let lastVisit: LastVisitPayload?
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(opponentName)'s turn")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColor.textPrimary)
            
            if let visit = lastVisit {
                Text("Last visit: \(visit.darts.reduce(0, +))")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(AppColor.inputBackground)
        .cornerRadius(12)
    }
}

// MARK: - Reveal Overlay

struct RevealOverlay: View {
    let visit: LastVisitPayload
    let currentUserId: UUID
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text(visit.playerId == currentUserId ? "You scored" : "Opponent scored")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColor.textPrimary)
                
                Text("\(visit.darts.reduce(0, +))")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(AppColor.brandPrimary)
                
                Text("\(visit.scoreBefore) → \(visit.scoreAfter)")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
            }
            .padding(40)
            .background(AppColor.surfacePrimary)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .transition(.opacity)
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

// MARK: - Preview

#Preview {
    NavigationStack {
        RemoteGameplayView(matchId: RemoteMatch.mockInProgress.id)
            .environmentObject(Router.shared)
            .environmentObject(RemoteMatchService())
            .environmentObject(AuthService.shared)
    }
}
