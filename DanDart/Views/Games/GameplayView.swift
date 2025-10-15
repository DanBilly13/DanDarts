//
//  GameplayView.swift
//  DanDart
//
//  Full-screen gameplay view for dart scoring (301 game mode)
//  Design: Calculator-inspired scoring with dark theme
//

import SwiftUI

// MARK: - Menu Coordinator

class MenuCoordinator: ObservableObject {
    static let shared = MenuCoordinator()
    @Published var activeMenuId: String? = nil
    
    private init() {}
    
    func showMenu(for buttonId: String) {
        activeMenuId = buttonId
    }
    
    func hideMenu() {
        activeMenuId = nil
    }
}

// MARK: - Score Types

enum ScoreType: String, CaseIterable {
    case single = "Single"
    case double = "Double"
    case triple = "Triple"
    
    var multiplier: Int {
        switch self {
        case .single: return 1
        case .double: return 2
        case .triple: return 3
        }
    }
    
    var prefix: String {
        switch self {
        case .single: return ""
        case .double: return "D"
        case .triple: return "T"
        }
    }
}

struct ScoredThrow {
    let baseValue: Int
    let scoreType: ScoreType
    
    var totalValue: Int {
        baseValue * scoreType.multiplier
    }
    
    var displayText: String {
        if scoreType == .single {
            return "\(totalValue)"
        } else {
            return "\(scoreType.prefix)\(baseValue)"
        }
    }
}

struct GameplayView: View {
    let game: Game
    let players: [Player]
    
    // Game state managed by ViewModel
    @StateObject private var gameViewModel: GameViewModel
    @StateObject private var navigationManager = NavigationManager.shared
    @StateObject private var menuCoordinator = MenuCoordinator.shared
    @State private var showInstructions: Bool = false
    @State private var showRestartAlert: Bool = false
    @State private var showExitAlert: Bool = false
    @State private var navigateToGameEnd: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    // Initialize with game and players
    init(game: Game, players: [Player]) {
        self.game = game
        self.players = players
        _gameViewModel = StateObject(wrappedValue: GameViewModel(game: game, players: players))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Stacked player cards (current player in front)
                    StackedPlayerCards(
                        players: gameViewModel.players,
                        currentPlayerIndex: gameViewModel.currentPlayerIndex,
                        playerScores: gameViewModel.playerScores,
                        currentThrow: gameViewModel.currentThrow
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 60)  // Extra padding to clear the notch area
                    
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
                    
                    // Checkout suggestion (when available)
                    if let checkout = gameViewModel.suggestedCheckout {
                        CheckoutSuggestionView(checkout: checkout)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    // Scoring button grid (center)
                    ScoringButtonGrid(
                        onScoreSelected: { baseValue, scoreType in
                            gameViewModel.recordThrow(value: baseValue, multiplier: scoreType.multiplier)
                        }
                    )
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    // Save Score button (new AppButton)
                    AppButton(role: .primary, action: { gameViewModel.saveScore() }) {
                        Label("Save Score", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(!gameViewModel.isTurnComplete)
                    .blur(radius: menuCoordinator.activeMenuId != nil ? 2 : 0)
                    .opacity(menuCoordinator.activeMenuId != nil ? 0.4 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: menuCoordinator.activeMenuId != nil)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 34)
                }
                
                // Absolutely positioned more menu button
                VStack {
                    HStack {
                        Spacer()
                        
                        Menu {
                            Button("Instructions") {
                                showInstructions = true
                            }
                            
                            Button("Restart Game") {
                                showRestartAlert = true
                            }
                            
                            Button("Cancel Game", role: .destructive) {
                                showExitAlert = true
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color("TextSecondary"))
                                .frame(width: 44, height: 44)
                                .background(Color("InputBackground").opacity(0.8))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
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
        .onChange(of: gameViewModel.winner) { oldValue, newValue in
            if newValue != nil {
                // Winner detected - navigate to game end screen after brief delay
                // This ensures all state updates are complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    navigateToGameEnd = true
                }
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
                    }
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
    
    var body: some View {
        VStack(spacing: 16) {
            // Stacked player cards with current player in front
            ZStack {
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    PlayerScoreCard(
                        player: player,
                        score: playerScores[player.id] ?? 301,
                        isCurrentPlayer: index == currentPlayerIndex,
                        currentThrow: index == currentPlayerIndex ? currentThrow : [ScoredThrow]()
                    )
                    .overlay(
                        // Background-colored overlay for depth effect
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(overlayOpacityForPlayer(index: index, currentIndex: currentPlayerIndex)))
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
        
        // Much smaller offsets to ensure score is visible on each card
        // The score is on the right side, so we need to show most of the card
        switch stackPosition {
        case 1: return -46  // Card 1: Show most of the card including full score
        case 2: return -68      // Card 2: Show at least half including score
        case 3: return -90  // Card 3: Show quarter but ensure score is visible
        default: return -CGFloat(stackPosition) * 12  // Additional cards
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
        case 1: return 0.3   // Player 2: 30% dark overlay
        case 2: return 0.5   // Player 3: 50% dark overlay  
        case 3: return 0.65  // Player 4: 65% dark overlay
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
    
    var body: some View {
        VStack(spacing: 12) {
            // Player info
            HStack(spacing: 12) {
                PlayerAvatarView(
                    avatarURL: player.avatarURL,
                    size: 48,
                    borderColor: isCurrentPlayer ? Color("AccentPrimary") : nil
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color("TextPrimary"))
                    
                    Text("@\(player.nickname)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                }
                
                Spacer()
                
                // Score
                Text("\(score)")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(isCurrentPlayer ? Color("AccentPrimary") : Color("TextPrimary"))
            }
            
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("InputBackground"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("AccentPrimary"), lineWidth: 2)
                )
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
                        .foregroundColor(hasDart ? Color("TextPrimary") : Color("TextSecondary").opacity(0.5))
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color("AccentPrimary").opacity(hasDart ? 0.15 : 0.05))
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
                .disabled(!hasDart)
            }
            
            // Equals sign
            Text("=")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color("TextSecondary"))
                .padding(.horizontal, 8)
            
            // Total score
            Text("\(currentThrow.reduce(0) { $0 + $1.totalValue })")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(Color("AccentPrimary"))
                .frame(width: 50, height: 40)
                .background(Color("AccentPrimary").opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("InputBackground").opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("AccentPrimary").opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Scoring Button Grid

struct ScoringButtonGrid: View {
    let onScoreSelected: (Int, ScoreType) -> Void
    
    // Sequential numbers 1-20
    private let dartboardNumbers = Array(1...20)
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
            // Numbers 1-20
            ForEach(dartboardNumbers, id: \.self) { number in
                ScoringButton(
                    title: "\(number)",
                    baseValue: number,
                    onScoreSelected: onScoreSelected
                )
            }
            
            // 25
            ScoringButton(
                title: "25",
                baseValue: 25,
                onScoreSelected: onScoreSelected
            )
            
            // Bull
            ScoringButton(
                title: "Bull",
                baseValue: 50,
                onScoreSelected: onScoreSelected
            )
            
            // Miss
            ScoringButton(
                title: "Miss",
                baseValue: 0,
                onScoreSelected: onScoreSelected
            )
            
            // Bust
            ScoringButton(
                title: "Bust",
                baseValue: -1, // -1 indicates bust
                onScoreSelected: onScoreSelected
            )
        }
    }
}

// MARK: - Scoring Button Component

struct ScoringButton: View {
    let title: String
    let subtitle: String?
    let baseValue: Int
    let onScoreSelected: (Int, ScoreType) -> Void
    
    @State private var isPressed = false
    @State private var isHighlighted = false
    @StateObject private var menuCoordinator = MenuCoordinator.shared
    @State private var buttonFrame: CGRect = .zero
    
    // Unique identifier for this button
    private var buttonId: String {
        "\(baseValue)-\(title)"
    }
    
    // Check if this button's menu is active
    private var isMenuActive: Bool {
        menuCoordinator.activeMenuId == buttonId
    }
    
    // Check if this button should be blurred (another menu is active)
    private var shouldBlur: Bool {
        menuCoordinator.activeMenuId != nil && menuCoordinator.activeMenuId != buttonId
    }
    
    // Calculate optimal menu position like Apple's context menu
    private var menuOffset: CGSize {
        let menuWidth: CGFloat = 120
        let menuHeight: CGFloat = 132 // 3 buttons × 44pt each
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        let buttonCenterX = buttonFrame.midX
        let buttonCenterY = buttonFrame.midY
        
        // Default positioning - above and centered
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = -menuHeight/2 - 32 - 16 // 16pt gap above button
        
        // Check if menu would go off left edge
        if buttonCenterX - menuWidth/2 < 16 {
            offsetX = 16 - buttonCenterX + menuWidth/2
        }
        
        // Check if menu would go off right edge  
        if buttonCenterX + menuWidth/2 > screenWidth - 16 {
            offsetX = (screenWidth - 16) - buttonCenterX - menuWidth/2
        }
        
        // Check if menu would go off top edge
        if buttonCenterY + offsetY < 60 { // Account for safe area
            offsetY = 80 // Position below button instead
        }
        
        return CGSize(width: offsetX, height: offsetY)
    }
    
    // Don't show context menu for special buttons
    private var canShowContextMenu: Bool {
        baseValue > 0 && baseValue != 50 // Exclude Miss, Bust, and Bull
    }
    
    init(title: String, subtitle: String? = nil, baseValue: Int, onScoreSelected: @escaping (Int, ScoreType) -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.baseValue = baseValue
        self.onScoreSelected = onScoreSelected
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundColor(Color("BackgroundPrimary"))
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color("BackgroundPrimary").opacity(0.8))
                }
            }
            .frame(width: 64, height: 64)
            .background(
                Circle()
                    .fill(Color("AccentTertiary"))
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(isHighlighted ? 0.3 : 0.0))
                    )
            )
            .clipShape(Circle())
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .blur(radius: shouldBlur ? 2 : 0)
            .opacity(shouldBlur ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: shouldBlur)
            .onAppear {
                // Capture button frame in global coordinates
                buttonFrame = geometry.frame(in: .global)
            }
            .onChange(of: geometry.frame(in: .global)) { newFrame in
                buttonFrame = newFrame
            }
        }
        .frame(width: 64, height: 64)
        .onTapGesture {
            // If any menu is open, just close it without scoring
            if menuCoordinator.activeMenuId != nil {
                menuCoordinator.hideMenu()
                return
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Brief highlight effect
            withAnimation(.easeInOut(duration: 0.15)) {
                isHighlighted = true
            }
            
            // Remove highlight after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHighlighted = false
                }
            }
            
            // Default to single
            onScoreSelected(baseValue, .single)
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            if canShowContextMenu {
                // Haptic feedback for long press
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    menuCoordinator.showMenu(for: buttonId)
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
        .overlay(
            // Custom dark-themed popup menu
            Group {
                if isMenuActive {
                    VStack(spacing: 1) {
                        // Triple option (top)
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                            impactFeedback.impactOccurred()
                            onScoreSelected(baseValue, .triple)
                            withAnimation(.easeOut(duration: 0.2)) {
                                menuCoordinator.hideMenu()
                            }
                        }) {
                            Text("Triple")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.red)
                        }
                        
                        // Double option (middle)
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            onScoreSelected(baseValue, .double)
                            withAnimation(.easeOut(duration: 0.2)) {
                                menuCoordinator.hideMenu()
                            }
                        }) {
                            Text("Double")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.red)
                        }
                        
                        // Single option (bottom)
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            onScoreSelected(baseValue, .single)
                            withAnimation(.easeOut(duration: 0.2)) {
                                menuCoordinator.hideMenu()
                            }
                        }) {
                            Text("Single")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.red)
                        }
                    }
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                    .frame(width: 120)
                    .offset(menuOffset)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                    .zIndex(1000)
                }
            }
        )
    }
}

// MARK: - Checkout Suggestion View

struct CheckoutSuggestionView: View {
    let checkout: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "target")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color("AccentPrimary"))
            
            Text("Checkout: \(checkout)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color("AccentPrimary"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("AccentPrimary").opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color("AccentPrimary").opacity(0.4), lineWidth: 1)
                )
        )
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: checkout)
    }
}

// MARK: - Preview
#Preview("Gameplay - 301") {
    GameplayView(
        game: Game.preview301,
        players: [Player.mockGuest1, Player.mockGuest2]
    )
}

#Preview("Gameplay - 3 Players") {
    GameplayView(
        game: Game.preview301,
        players: [Player.mockGuest1, Player.mockGuest2, Player.mockConnected1]
    )
}

#Preview("Gameplay - 4 Players") {
    GameplayView(
        game: Game.preview301,
        players: [Player.mockGuest1, Player.mockGuest2, Player.mockConnected1, Player.mockConnected2]
    )
}
