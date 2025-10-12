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
    
    // Game state
    @State private var currentPlayerIndex: Int = 0
    @State private var playerScores: [UUID: Int] = [:]
    @State private var currentThrow: [Int] = []
    @State private var showExitAlert: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    // Initialize player scores based on game type
    private func initializeScores() {
        if playerScores.isEmpty {
            for player in players {
                playerScores[player.id] = 301 // Start with 301 for 301 game
            }
        }
    }
    
    var currentPlayer: Player {
        players[currentPlayerIndex]
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
                        players: players,
                        currentPlayerIndex: currentPlayerIndex,
                        playerScores: playerScores,
                        currentThrow: currentThrow
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 60)  // Extra padding to clear the notch area
                    
                    // Current throw display (always visible)
                    CurrentThrowDisplay(currentThrow: currentThrow)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                    Spacer()
                    
                    // Scoring button grid (center)
                    ScoringButtonGrid(
                        onScoreSelected: { score in
                            addScoreToThrow(score)
                        }
                    )
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    // Save Score button
                    Button(action: saveScore) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .medium))
                            Text("Save Score")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(currentThrow.isEmpty ? Color("TextSecondary").opacity(0.3) : Color("AccentPrimary"))
                        )
                    }
                    .disabled(currentThrow.isEmpty)
                    .padding(.horizontal, 16)
                    
                    // Cancel Game button
                    Button(action: {
                        showExitAlert = true
                    }) {
                        Text("Cancel Game")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            initializeScores()
        }
        .alert("Exit Game", isPresented: $showExitAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Leave Game", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("Are you sure you want to leave the game? Your progress will be lost.")
        }
    }
    
    // MARK: - Game Logic
    
    private func addScoreToThrow(_ score: Int) {
        guard currentThrow.count < 3 else { return }
        currentThrow.append(score)
    }
    
    private func saveScore() {
        guard !currentThrow.isEmpty else { return }
        
        let throwTotal = currentThrow.reduce(0, +)
        let currentScore = playerScores[currentPlayer.id] ?? 301
        let newScore = max(0, currentScore - throwTotal)
        
        playerScores[currentPlayer.id] = newScore
        
        // Check for winner
        if newScore == 0 {
            // Game won!
            // TODO: Navigate to GameEndView
            print("Player \(currentPlayer.displayName) wins!")
        } else {
            // Switch to next player
            switchToNextPlayer()
        }
        
        // Clear current throw
        currentThrow.removeAll()
    }
    
    private func switchToNextPlayer() {
        currentPlayerIndex = (currentPlayerIndex + 1) % players.count
    }
}

// MARK: - Stacked Player Cards

struct StackedPlayerCards: View {
    let players: [Player]
    let currentPlayerIndex: Int
    let playerScores: [UUID: Int]
    let currentThrow: [Int]
    
    var body: some View {
        VStack(spacing: 16) {
            // Stacked player cards with current player in front
            ZStack {
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    PlayerGameCard(
                        player: player,
                        score: playerScores[player.id] ?? 301,
                        isCurrentPlayer: index == currentPlayerIndex,
                        currentThrow: index == currentPlayerIndex ? currentThrow : []
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

struct PlayerGameCard: View {
    let player: Player
    let score: Int
    let isCurrentPlayer: Bool
    let currentThrow: [Int]
    
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
    let currentThrow: [Int]
    
    var body: some View {
        HStack(spacing: 12) {
                // Individual throw scores
                ForEach(0..<3, id: \.self) { index in
                    Text(index < currentThrow.count ? "\(currentThrow[index])" : "—")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(index < currentThrow.count ? Color("TextPrimary") : Color("TextSecondary").opacity(0.5))
                        .frame(width: 40, height: 40)
                        .background(Color("AccentPrimary").opacity(index < currentThrow.count ? 0.15 : 0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Equals sign
                Text("=")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("TextSecondary"))
                    .padding(.horizontal, 8)
                
                // Total score
                Text("\(currentThrow.reduce(0, +))")
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
    let onScoreSelected: (Int) -> Void
    
    // Sequential numbers 1-20
    private let dartboardNumbers = Array(1...20)
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
            // Numbers 1-20
            ForEach(dartboardNumbers, id: \.self) { number in
                ScoringButton(
                    title: "\(number)",
                    action: {
                        onScoreSelected(number)
                    }
                )
            }
            
            // 25
            ScoringButton(
                title: "25",
                action: {
                    onScoreSelected(25)
                }
            )
            
            // Bull
            ScoringButton(
                title: "Bull",
                action: {
                    onScoreSelected(50)
                }
            )
            
            // Miss
            ScoringButton(
                title: "Miss",
                action: {
                    onScoreSelected(0)
                }
            )
            
            // Bust
            ScoringButton(
                title: "Bust",
                action: {
                    // TODO: Handle bust logic
                    onScoreSelected(0)
                }
            )
        }
    }
}

// MARK: - Scoring Button Component

struct ScoringButton: View {
    let title: String
    let subtitle: String?
    let action: () -> Void
    
    @State private var isPressed = false
    
    init(title: String, subtitle: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundColor(Color("TextPrimary"))
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                }
            }
            .frame(width: 64, height: 64)
            .background(Color("AccentSecondary"))
            .clipShape(Circle())
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0) { pressing in
            isPressed = pressing
        } perform: {
            // Long press action for doubles/triples (future implementation)
        }
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
