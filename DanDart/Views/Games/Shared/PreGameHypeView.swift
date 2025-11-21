//
//  PreGameHypeView.swift
//  DanDart
//
//  Pre-game hype screen with boxing match style presentation
//

import SwiftUI

struct PreGameHypeView: View {
    let game: Game
    let players: [Player]
    let matchFormat: Int
    let halveItDifficulty: HalveItDifficulty?
    let knockoutLives: Int?
    let autoTransition: Bool
    
    // Navigation helper
    private func navigateToGameplay() {
        if let difficulty = halveItDifficulty {
            router.push(.halveItGameplay(game: game, players: players, difficulty: difficulty))
        } else if let lives = knockoutLives {
            if game.title == "Knockout" {
                router.push(.knockoutGameplay(game: game, players: players, startingLives: lives))
            } else if game.title == "Sudden Death" {
                router.push(.suddenDeathGameplay(game: game, players: players, startingLives: lives))
            }
        } else {
            router.push(.countdownGameplay(game: game, players: players, matchFormat: matchFormat))
        }
    }
    
    init(game: Game, players: [Player], matchFormat: Int, halveItDifficulty: HalveItDifficulty? = nil, knockoutLives: Int? = nil, autoTransition: Bool = true) {
        self.game = game
        self.players = players
        self.matchFormat = matchFormat
        self.halveItDifficulty = halveItDifficulty
        self.knockoutLives = knockoutLives
        self.autoTransition = autoTransition
    }
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: Router
    
    // Animation states
    @State private var showPlayers = false
    @State private var showVS = false
    @State private var showGetReady = false
    
    var body: some View {
            GeometryReader { geometry in
                ZStack {
                    // Solid black background to prevent white page
                    Color.black
                        .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Game name at top
                    VStack(spacing: 8) {
                        Text(game.title)
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundColor(AppColor.textPrimary)
                        
                        Text("MATCH STARTING")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                            .tracking(2)
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Players section - dynamic layout based on player count
                    playersSection
                        .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    // GET READY section at bottom
                    VStack(spacing: 16) {
                        Text("GET READY!")
                            .font(.system(size: 32, weight: .black, design: .default))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                            .tracking(2)
                            .scaleEffect(showGetReady ? 1.0 : 0.8)
                            .opacity(showGetReady ? 1.0 : 0.0)
                        
                        Text("Tap to skip")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                            .opacity(showGetReady ? 0.7 : 0.0)
                    }
                    .padding(.bottom, 60)
                }
                } // End of conditional content
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .onAppear {
                startAnimationSequence()
                // Play boxing sound when view appears
                SoundManager.shared.playBoxingSound()
            }
        .onTapGesture {
            navigateToGameplay()
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Player Layouts
    
    @ViewBuilder
    private var playersSection: some View {
        if players.count == 2 {
            twoPlayerLayout
        } else if players.count == 3 {
            threePlayerLayout
        } else if players.count == 4 {
            fourPlayerLayout
        } else {
            multiPlayerGrid
        }
    }
    
    // 2 Players: Side-by-side with VS (absolutely positioned)
    private var twoPlayerLayout: some View {
        ZStack {
            // Players take full 50% width each (no space for VS)
            HStack(spacing: 0) {
                playerCard(players[0], index: 0)
                    .frame(maxWidth: .infinity)
             
                
                playerCard(players[1], index: 1)
                    .frame(maxWidth: .infinity)
            }
            
            // VS absolutely positioned in center (doesn't take layout space)
            VStack(spacing: 8) {
                Text("VS")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(AppColor.interactivePrimaryBackground)
                    .scaleEffect(showVS ? 1.0 : 0.5)
                    .opacity(showVS ? 1.0 : 0.0)
            }
            .offset(y: -40) // Align with avatar center
        }
    }
    
    // 3 Players: Triangle layout (2 top, 1 bottom center)
    private var threePlayerLayout: some View {
        VStack(spacing: 40) {
            HStack(spacing: 0) {
                playerCard(players[0], index: 0)
                    .frame(maxWidth: .infinity)
                playerCard(players[1], index: 1)
                    .frame(maxWidth: .infinity)
            }
            
            playerCard(players[2], index: 2)
                .frame(maxWidth: .infinity)
        }
    }
    
    // 4 Players: 2x2 grid
    private var fourPlayerLayout: some View {
        VStack(spacing: 40) {
            HStack(spacing: 0) {
                playerCard(players[0], index: 0)
                    .frame(maxWidth: .infinity)
                playerCard(players[1], index: 1)
                    .frame(maxWidth: .infinity)
            }
            
            HStack(spacing: 0) {
                playerCard(players[2], index: 2)
                    .frame(maxWidth: .infinity)
                playerCard(players[3], index: 3)
                    .frame(maxWidth: .infinity)
            }
            
        }
    }
    
    // 5-6 Players: 2x3 grid
    private var multiPlayerGrid: some View {
        VStack(spacing: 32) {
            HStack(spacing: 0) {
                ForEach(Array(players.prefix(2).enumerated()), id: \.element.id) { index, player in
                    playerCard(player, index: index)
                        .frame(maxWidth: .infinity)
                }
            }
            
            HStack(spacing: 0) {
                ForEach(Array(players.dropFirst(2).prefix(2).enumerated()), id: \.element.id) { index, player in
                    playerCard(player, index: index + 2)
                        .frame(maxWidth: .infinity)
                }
            }
            
            if players.count > 4 {
                HStack(spacing: 0) {
                    ForEach(Array(players.dropFirst(4).enumerated()), id: \.element.id) { index, player in
                        playerCard(player, index: index + 4)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
    
    // MARK: - Player Card Component
    
    private var avatarSize: CGFloat {
        players.count <= 4 ? 96 : 68
    }
    
    private func playerCard(_ player: Player, index: Int) -> some View {
        return VStack(spacing: 0) {
            // Avatar (96pt as per design) - no border
            PlayerAvatarView(
                avatarURL: player.avatarURL,
                size: avatarSize,
                borderColor: .clear
            )
            .scaleEffect(showPlayers ? 1.0 : 0.8)
            .opacity(showPlayers ? 1.0 : 0.0)
            
            // 16px spacing after avatar
            Spacer()
                .frame(height: 8)
            
            // Name and nickname grouped together (no spacing)
            VStack(spacing: 0) {
                // Player name (.subheadline)
                Text(player.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.textPrimary)
                    .opacity(showPlayers ? 1.0 : 0.0)
                
                // Nickname (.footnote) - no spacing from name
                Text("@\(player.nickname)")
                    .font(.footnote)
                    .foregroundColor(AppColor.textSecondary)
                    .opacity(showPlayers ? 1.0 : 0.0)
            }
            
            // 8px spacing before stats
            Spacer()
                .frame(height: 2)
            
            // Stats (.footnote) - W in AccentSecondary, L in AccentPrimary
            HStack(spacing: 0) {
                Text("W\(player.totalWins)")
                        .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.interactiveSecondaryBackground)
                Text("L\(player.totalLosses)")
                        .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.interactivePrimaryBackground)
            }
            .opacity(showPlayers ? 1.0 : 0.0)
        }
    }
    
    // MARK: - Animation Sequence
    
    private func startAnimationSequence() {
        // Players appear
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showPlayers = true
        }
        
        // VS appears (only for 2 players)
        if players.count == 2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showVS = true
                }
            }
        }
        
        // GET READY appears last
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.4)) {
                showGetReady = true
            }
        }
        
        // Auto-transition to gameplay after 3 seconds total (if enabled)
        if autoTransition {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                navigateToGameplay()
            }
        }
    }
}

// MARK: - Preview
#Preview("Pre-Game Hype - 301") {
    NavigationStack {
        PreGameHypeView(
            game: Game.preview301,
            players: [Player.mockGuest1, Player.mockGuest2],
            matchFormat: 1,
            autoTransition: false
        )
    }
    .environmentObject(AuthService.mockAuthenticated)
}

#Preview("Pre-Game Hype - 501") {
    NavigationStack {
        PreGameHypeView(
            game: Game.preview501,
            players: [Player.mockConnected1, Player.mockConnected2],
            matchFormat: 3,
            autoTransition: false
        )
    }
    .environmentObject(AuthService.mockAuthenticated)
}

#Preview("Pre-Game Hype - Single Player") {
    NavigationStack {
        PreGameHypeView(
            game: Game.previewHalveIt,
            players: [Player.mockGuest1],
            matchFormat: 1,
            autoTransition: false
        )
    }
    .environmentObject(AuthService.mockAuthenticated)
}

#Preview("Pre-Game Hype - 3 Players") {
    NavigationStack {
        PreGameHypeView(
            game: Game.preview301,
            players: [Player.mockGuest1, Player.mockGuest2, Player.mockConnected1],
            matchFormat: 1,
            autoTransition: false
        )
    }
    .environmentObject(AuthService.mockAuthenticated)
}

#Preview("Pre-Game Hype - 4 Players") {
    NavigationStack {
        PreGameHypeView(
            game: Game.preview501,
            players: [Player.mockGuest1, Player.mockGuest2, Player.mockConnected1, Player.mockConnected2],
            matchFormat: 3,
            autoTransition: false
        )
    }
    .environmentObject(AuthService.mockAuthenticated)
}

#Preview("Pre-Game Hype - 6 Players") {
    NavigationStack {
        PreGameHypeView(
            game: Game.preview501,
            players: [Player.mockGuest1, Player.mockGuest2, Player.mockConnected1, Player.mockConnected2, Player.mockGuest1, Player.mockGuest2],
            matchFormat: 3,
            autoTransition: false
        )
    }
    .environmentObject(AuthService.mockAuthenticated)
}
