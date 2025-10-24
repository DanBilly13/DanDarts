//
//  GameplayView.swift
//  DanDart
//
//  Full-screen gameplay view for dart scoring (301 game mode)
//  Design: Calculator-inspired scoring with dark theme
//

import SwiftUI

struct GameplayView: View {
    let game: Game
    let players: [Player]
    let matchFormat: Int
    
    // Game state managed by ViewModel
    @StateObject private var gameViewModel: GameViewModel
    @StateObject private var menuCoordinator = MenuCoordinator.shared
    @State private var showInstructions: Bool = false
    @State private var showRestartAlert: Bool = false
    @State private var showExitAlert: Bool = false
    @State private var navigateToGameEnd: Bool = false
    @State private var showLegWinCelebration: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    // Initialize with game and players
    init(game: Game, players: [Player], matchFormat: Int = 1) {
        self.game = game
        self.players = players
        self.matchFormat = matchFormat
        _gameViewModel = StateObject(wrappedValue: GameViewModel(game: game, players: players, matchFormat: matchFormat))
    }
    
    var body: some View {
        VStack(spacing: 0) {
                // Stacked player cards (current player in front)
                StackedPlayerCards(
                    players: gameViewModel.players,
                    currentPlayerIndex: gameViewModel.currentPlayerIndex,
                    playerScores: gameViewModel.playerScores,
                    currentThrow: gameViewModel.currentThrow,
                    legsWon: gameViewModel.legsWon,
                    matchFormat: gameViewModel.matchFormat
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
                
                VStack {
                    if let checkout = gameViewModel.suggestedCheckout {
                        CheckoutSuggestionView(checkout: checkout)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 0)
                    }
                }
                .frame(height: 40, alignment: .center)
                .padding(.bottom, 8)
                
                // Scoring button grid (center)
                ScoringButtonGrid(
                    onScoreSelected: { baseValue, scoreType in
                        gameViewModel.recordThrow(value: baseValue, multiplier: scoreType.multiplier)
                    }
                )
                .padding(.horizontal, 16)
                
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
                        role: gameViewModel.isWinningThrow ? .secondary : .primary,
                        action: { gameViewModel.saveScore() }
                    ) {
                        if gameViewModel.isWinningThrow {
                            Label("Game Over", systemImage: "trophy.fill")
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
        .background(Color.black)
        .navigationTitle(gameViewModel.matchFormat > 1 ? "Leg \(gameViewModel.currentLeg)/\(gameViewModel.matchFormat)" : game.title)
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
                // Set flag first, then dismiss
                NavigationManager.shared.dismissToGamesList()
                dismiss()
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
                        NavigationManager.shared.dismissToGamesList()
                        dismiss()
                    },
                    matchFormat: gameViewModel.isMultiLegMatch ? gameViewModel.matchFormat : nil,
                    legsWon: gameViewModel.isMultiLegMatch ? gameViewModel.legsWon : nil
                )
            }
        }
    }
    
    // MARK: - Game Logic
    // All game logic now handled by GameViewModel
}



// MARK: - Stacked Player Cards

struct StackedPlayerCards: View {
    let players: [Player]
    let currentPlayerIndex: Int
    let playerScores: [UUID: Int]
    let currentThrow: [ScoredThrow]
    let legsWon: [UUID: Int]
    let matchFormat: Int
    
    var body: some View {
        VStack(spacing: 16) {
            // Stacked player cards with current player in front
            ZStack {
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    PlayerScoreCard(
                        player: player,
                        score: playerScores[player.id] ?? 301,
                        isCurrentPlayer: index == currentPlayerIndex,
                        currentThrow: index == currentPlayerIndex ? currentThrow : [ScoredThrow](),
                        legsWon: legsWon[player.id] ?? 0,
                        matchFormat: matchFormat,
                        playerIndex: index
                    )
                    .overlay(
                        // Matched-shape dimming overlay for depth effect
                        Capsule()
                            .fill(Color.black.opacity(overlayOpacityForPlayer(index: index, currentIndex: currentPlayerIndex)))
                            .allowsHitTesting(false)
                    )
                    .offset(
                        x: 0,
                        y: offsetForPlayer(index: index, currentIndex: currentPlayerIndex, totalPlayers: players.count)
                    )
                    .scaleEffect(scaleForPlayer(index: index, currentIndex: currentPlayerIndex, totalPlayers: players.count))
                    .zIndex(zIndexForPlayer(index: index, currentIndex: currentPlayerIndex, totalPlayers: players.count))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPlayerIndex)
                }
            }
            .frame(height: calculateStackHeight(playerCount: players.count))
        }
    }
    
    // MARK: - Helper Functions
    
    private func offsetForPlayer(index: Int, currentIndex: Int, totalPlayers: Int) -> CGFloat {
        if index == currentIndex {
            return 0  // Current player at front (bottom of stack)
        }
        
        // Calculate position in stack (excluding current player)
        let stackPosition = stackPositionForPlayer(index: index, currentIndex: currentIndex, totalPlayers: totalPlayers)
        
        // Adjusted offsets for new layout below navigation bar
        switch stackPosition {
        case 1: return -52  // Card 1: Show most of the card including full score
        case 2: return -68      // Card 2: Show at least half including score
        case 3: return -85  // Card 3: Show quarter but ensure score is visible
        default: return -CGFloat(stackPosition) * 10  // Additional cards
        }
    }
    
    private func scaleForPlayer(index: Int, currentIndex: Int, totalPlayers: Int) -> CGFloat {
        if index == currentIndex {
            return 1.0  // Current player: 100% scale
        }
        
        // Calculate position in stack (excluding current player)
        let stackPosition = stackPositionForPlayer(index: index, currentIndex: currentIndex, totalPlayers: totalPlayers)
        
        // Exponential scaling for dramatic visual hierarchy
        // Each card scales by a power of the base scale factor
        let baseScale: CGFloat = 0.92  // 8% reduction for first card
        let exponentialScale = pow(baseScale, CGFloat(stackPosition))
        return max(exponentialScale, 0.75)  // Minimum 75% scale
    }
    
    private func overlayOpacityForPlayer(index: Int, currentIndex: Int) -> Double {
        if index == currentIndex {
            return 0.0  // Current player: no overlay (fully visible)
        }
        
        // Calculate position in stack (excluding current player)
        let stackPosition = stackPositionForPlayer(index: index, currentIndex: currentIndex, totalPlayers: players.count)
        
        // Progressive overlay opacity for depth effect
        switch stackPosition {
        case 1: return 0.5   // Player 2: 30% dark overlay
        case 2: return 0.6   // Player 3: 50% dark overlay
        case 3: return 0.7  // Player 4: 65% dark overlay
        default: return min(0.8, 0.3 + (CGFloat(stackPosition - 1) * 0.15))  // Additional players
        }
    }
    
    private func zIndexForPlayer(index: Int, currentIndex: Int, totalPlayers: Int) -> Double {
        if index == currentIndex {
            return 100  // Current player always on top
        }
        
        // Stack the rest in reverse order (higher stack position = lower z-index)
        let stackPosition = stackPositionForPlayer(index: index, currentIndex: currentIndex, totalPlayers: totalPlayers)
        return Double(totalPlayers - stackPosition)
    }
    
    private func stackPositionForPlayer(index: Int, currentIndex: Int, totalPlayers: Int) -> Int {
        // Calculate the position in the stack for non-current players
        // Players after current index get positions 1, 2, 3...
        // Players before current index get positions based on how many are after
        
        if index > currentIndex {
            return index - currentIndex
        } else {
            // Players before current index
            let playersAfterCurrent = totalPlayers - currentIndex - 1
            return playersAfterCurrent + (currentIndex - index)
        }
    }
    
    private func calculateStackHeight(playerCount: Int) -> CGFloat {
        // Base card height + smaller offsets for visible portions
        let baseCardHeight: CGFloat = 84
        
        if playerCount <= 1 {
            return baseCardHeight
        }
        
        // Add space for visible portions of stacked cards
        // Each card adds approximately 12pt of visible space
        let additionalHeight = CGFloat(playerCount - 1) * 12
        
        return baseCardHeight + additionalHeight
    }
}

// MARK: - Player Game Card

struct PlayerScoreCard: View {
    let player: Player
    let score: Int
    let isCurrentPlayer: Bool
    let currentThrow: [ScoredThrow]
    let legsWon: Int
    let matchFormat: Int
    let playerIndex: Int
    
    // Get border color based on player index
    var borderColor: Color {
        switch playerIndex {
        case 0: return Color("AccentPrimary")
        case 1: return Color("AccentSecondary")
        case 2: return Color("AccentTertiary")
        case 3: return Color("AccentQuaternary")
        default: return Color("AccentPrimary")
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Player info
            HStack(spacing: 12) {
                // Avatar - 68px to match match detail
                PlayerAvatarView(
                    avatarURL: player.avatarURL,
                    size: 68,
                    borderColor: nil
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    // Player name - title3 rounded semibold
                    Text(player.displayName)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(Color("TextPrimary"))
                    
                    // Nickname - subheadline medium
                    Text("@\(player.nickname)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("TextSecondary"))
                    
                    // Legs won indicator (dots) - 10px spacing from nickname
                    if matchFormat > 1 && legsWon > 0 {
                        HStack(spacing: 4) {
                            ForEach(0..<legsWon, id: \.self) { _ in
                                Circle()
                                    .fill(borderColor)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.top, 6)
                    }
                }
                
                Spacer()
                
                // Score
                Text("\(score)")
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Color("TextPrimary"))
            }
            
        }
        .padding(.leading, 16)
        .padding(.trailing, 24)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .fill(Color("InputBackground"))
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(borderColor, lineWidth: 2)
        )
    }
}

// MARK: - Current Throw Display

struct CurrentThrowDisplay: View {
    let currentThrow: [ScoredThrow]
    let selectedDartIndex: Int?
    let onDartTapped: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Individual throw scores
            ForEach(0..<3, id: \.self) { index in
                let isSelected = selectedDartIndex == index
                let hasDart = index < currentThrow.count
                
                Button(action: {
                    if hasDart {
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        onDartTapped(index)
                    }
                }) {
                    Text(hasDart ? currentThrow[index].displayText : "—")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(hasDart ? Color("TextPrimary") : Color("TextSecondary"))
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color("TextPrimary").opacity(hasDart ? 0.15 : 0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isSelected ? Color("AccentPrimary") : Color.clear,
                                    lineWidth: isSelected ? 2 : 0
                                )
                        )
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                }
                .buttonStyle(PlainButtonStyle())
                .allowsHitTesting(hasDart)
            }
            
            // Equals sign
            Text("=")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color("TextSecondary"))
                .padding(.horizontal, 8)
            
            // Total score
            Text("\(currentThrow.reduce(0) { $0 + $1.totalValue })")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(Color("TextPrimary"))
                .frame(width: 50, height: 40)
                .background(Color("TextPrimary").opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        
    }
}

// MARK: - Checkout Suggestion View

struct CheckoutSuggestionView: View {
    let checkout: String
    
    var body: some View {
        Text("Checkout: \(checkout)")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color("AccentTertiary"))
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
#Preview("Gameplay - 301") {
    NavigationStack {
        GameplayView(
            game: Game.preview301,
            players: [Player.mockGuest1, Player.mockGuest2]
        )
    }
}

#Preview("Gameplay - 3 Players") {
    NavigationStack {
        GameplayView(
            game: Game.preview301,
            players: [Player.mockGuest1, Player.mockGuest2, Player.mockConnected1]
        )
    }
}

#Preview("Gameplay - 4 Players") {
    NavigationStack {
        GameplayView(
            game: Game.preview301,
            players: [Player.mockGuest1, Player.mockGuest2, Player.mockConnected1, Player.mockConnected2]
        )
    }
}
