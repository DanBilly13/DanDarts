//
//  GamesListView.swift
//  DanDart
//
//  Horizontal scrolling list of dart games with snap-to-center behavior
//

import SwiftUI

struct GamesListView: View {
    let games: [Game]
    let onGameSelected: (Game) -> Void
    
    init(games: [Game] = Game.mockGames, onGameSelected: @escaping (Game) -> Void = { _ in }) {
        self.games = games
        self.onGameSelected = onGameSelected
    }
    
    var body: some View {
        // Use simple vertical list to avoid geometry crashes
        GamesListViewVertical(games: games, onGameSelected: onGameSelected)
    }
}

// MARK: - Alternative Implementation for iOS 16 Compatibility

struct GamesListViewLegacy: View {
    let games: [Game]
    let onGameSelected: (Game) -> Void
    
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    
    private var cardWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        return screenWidth > 0 ? screenWidth * 0.9 : 300 // Fallback to prevent NaN
    }
    private let cardSpacing: CGFloat = 20
    
    init(games: [Game] = Game.mockGames, onGameSelected: @escaping (Game) -> Void = { _ in }) {
        self.games = games
        self.onGameSelected = onGameSelected
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Games ScrollView
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: cardSpacing) {
                    ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                        GameCard(game: game) {
                            onGameSelected(game)
                        }
                        .frame(width: cardWidth)
                        .scaleEffect(index == currentIndex ? 1.0 : 0.95)
                        .opacity(index == currentIndex ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                    }
                }
                .padding(.horizontal, max(0, (UIScreen.main.bounds.width - cardWidth) / 2))
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let cardWidthWithSpacing = cardWidth + cardSpacing
                            let threshold: CGFloat = 50
                            
                            if value.translation.width > threshold && currentIndex > 0 {
                                // Swipe right - go to previous
                                currentIndex = max(0, currentIndex - 1)
                            } else if value.translation.width < -threshold && currentIndex < games.count - 1 {
                                // Swipe left - go to next
                                currentIndex = min(games.count - 1, currentIndex + 1)
                            }
                            
                            // Ensure currentIndex is within bounds
                            currentIndex = max(0, min(games.count - 1, currentIndex))
                            
                            // Snap to position with bounds checking
                            withAnimation(.easeOut(duration: 0.3)) {
                                let offset = -CGFloat(currentIndex) * cardWidthWithSpacing
                                dragOffset = offset.isFinite ? offset : 0
                            }
                        }
                )
            }
            .clipped()
            .onAppear {
                // Initialize position with bounds checking
                let cardWidthWithSpacing = cardWidth + cardSpacing
                let initialOffset = -CGFloat(currentIndex) * cardWidthWithSpacing
                dragOffset = initialOffset.isFinite ? initialOffset : 0
            }
            
            // Page Indicator
            HStack(spacing: 8) {
                ForEach(0..<games.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? Color("AccentPrimary") : Color("TextSecondary").opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - Simple Vertical List Alternative

struct GamesListViewVertical: View {
    let games: [Game]
    let onGameSelected: (Game) -> Void
    
    init(games: [Game] = Game.mockGames, onGameSelected: @escaping (Game) -> Void = { _ in }) {
        self.games = games
        self.onGameSelected = onGameSelected
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(games) { game in
                    GameCardContainer(game: game) {
                        onGameSelected(game)
                    }
                }
            }
            .padding(.vertical, 20)
        }
    }
}

// MARK: - Preview
#Preview("Games List - Horizontal") {
    GamesListView { game in
        print("Selected game: \(game.name)")
    }
    .background(Color("BackgroundPrimary"))
}

#Preview("Games List - Legacy") {
    GamesListViewLegacy { game in
        print("Selected game: \(game.name)")
    }
    .background(Color("BackgroundPrimary"))
}

#Preview("Games List - Vertical") {
    GamesListViewVertical { game in
        print("Selected game: \(game.name)")
    }
    .background(Color("BackgroundPrimary"))
}

#Preview("Games List - Dark Mode") {
    GamesListView { game in
        print("Selected game: \(game.name)")
    }
    .background(Color("BackgroundPrimary"))
    .preferredColorScheme(.dark)
}
