import SwiftUI

struct StackedPlayerCards: View {
    let players: [Player]
    let currentPlayerIndex: Int
    let playerScores: [UUID: Int]
    let currentThrow: [ScoredThrow]
    let legsWon: [UUID: Int]
    let matchFormat: Int
    let showScoreAnimation: Bool
    let isExpanded: Bool
    let onTap: (() -> Void)?
    let getOriginalIndex: ((Player) -> Int)? // Function to get original player index for color consistency

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
                        playerIndex: getOriginalIndex?(player) ?? index,
                        showScoreAnimation: showScoreAnimation && index == currentPlayerIndex
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
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isExpanded)
            .frame(height: calculateStackHeight(playerCount: players.count, isExpanded: isExpanded), alignment: .top)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
        }
    }

    // MARK: - Helper Functions

    private func offsetForPlayer(index: Int, currentIndex: Int, totalPlayers: Int) -> CGFloat {
        // When expanded, spread cards into a vertical column anchored at the top.
        // The current (front) player sits at the bottom of the column, with
        // earlier players stacked above it in turn order.
        if isExpanded {
            let cardHeight: CGFloat = 84
            let spacing: CGFloat = 12
            let stackPosition = CGFloat(stackPositionForPlayer(index: index, currentIndex: currentIndex, totalPlayers: totalPlayers))

            // Map stackPosition (0 = current player) into a vertical index where
            // 0 is the *top* of the column and the current player is at the
            // bottom (largest index).
            let verticalIndex = CGFloat(totalPlayers - 1) - stackPosition
            return verticalIndex * (cardHeight + spacing)
        }

        if index == currentIndex {
            return 0  // Current player at front (bottom of stack)
        }

        // Calculate position in stack (excluding current player)
        let stackPosition = stackPositionForPlayer(index: index, currentIndex: currentIndex, totalPlayers: totalPlayers)

        // Adjusted offsets for new layout below navigation bar
        switch stackPosition {
        case 1: return -50  // Card 1: Show most of the card including full score
        case 2: return -72      // Card 2: Show at least half including score
        case 3: return -88  // Card 3: Show quarter but ensure score is visible
        default: return -CGFloat(stackPosition) * 10  // Additional cards
        }
    }

    private func scaleForPlayer(index: Int, currentIndex: Int, totalPlayers: Int) -> CGFloat {
        // When expanded, all cards sit at full scale
        if isExpanded {
            return 1.0
        }

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
        // When expanded, avoid dimming so all cards are equally legible
        if isExpanded {
            return 0.0
        }

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
        // In expanded mode, keep a simple top-to-bottom stacking order
        if isExpanded {
            return Double(totalPlayers - index)
        }

        if index == currentIndex {
            return 100  // Current player always on top
        }

        // Stack the rest in reverse order (higher stack position = lower z-index)
        let stackPosition = stackPositionForPlayer(index: index, currentIndex: currentIndex, totalPlayers: totalPlayers)
        return Double(totalPlayers - stackPosition)
    }

    private func stackPositionForPlayer(index: Int, currentIndex: Int, totalPlayers: Int) -> Int {
        // Calculate the position in the stack for non-current players
        // Use circular/modulo logic to maintain consistent order
        // Next player (clockwise) gets position 1, then 2, 3, etc.

        let relativePosition = (index - currentIndex + totalPlayers) % totalPlayers

        // relativePosition 0 is the current player (should never reach here due to early return)
        // relativePosition 1 is the next player (position 1 in stack)
        // relativePosition 2 is two players ahead (position 2 in stack), etc.

        return relativePosition
    }

    private func calculateStackHeight(playerCount: Int, isExpanded: Bool) -> CGFloat {
        let cardHeight: CGFloat = 84
        let spacing: CGFloat = 12

        if playerCount <= 1 {
            return cardHeight
        }

        if isExpanded {
            // Full column height: one full card per player plus spacing
            return CGFloat(playerCount) * (cardHeight + spacing)
        } else {
            // Stacked height: single card plus small visible portions
            let additionalHeight = CGFloat(playerCount - 1) * 12
            return cardHeight + additionalHeight
        }
    }
}

// MARK: - Player Game Card (shared)

struct PlayerScoreCard: View {
    let player: Player
    let score: Int
    let isCurrentPlayer: Bool
    let currentThrow: [ScoredThrow]
    let legsWon: Int
    let matchFormat: Int
    let playerIndex: Int
    let showScoreAnimation: Bool
    
    // Get border color based on player index
    var borderColor: Color {
        switch playerIndex {
        case 0: return AppColor.player1
        case 1: return AppColor.player2
        case 2: return AppColor.player3
        case 3: return AppColor.player4
        default: return AppColor.player1
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Player info
            HStack(spacing: 12) {
                // Player identity (avatar + name + nickname)
                PlayerIdentity(
                    player: player,
                    avatarSize: 48,
                    spacing: 0
                )
                
                Spacer()
                
                // Score and legs indicator
                VStack(spacing: 4) {
                    // Score with arcade-style pop animation
                    // Fixed-width container to prevent layout shift
                    Text("\(score)")
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(AppColor.textPrimary)
                        .frame(width: 70) // Fixed width to fit "888"
                        .multilineTextAlignment(.center)
                        .scaleEffect(showScoreAnimation ? 1.35 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.4), value: showScoreAnimation)
                        .onChange(of: showScoreAnimation) { oldValue, newValue in
                            if newValue {
                                // Haptic feedback when score pops
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                            }
                        }
                    
                    // Legs indicator (dots) - show all legs with filled/unfilled states
                    if matchFormat > 1 {
                        LegIndicators(
                            legsWon: legsWon,
                            totalLegs: matchFormat,
                            color: borderColor,
                            dotSize: 8,
                            spacing: 4
                        )
                    }
                }
            }
            
        }
        .padding(.leading, 16)
        .padding(.trailing, 24)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .fill(AppColor.inputBackground)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(borderColor, lineWidth: 2)
        )
    }
}
