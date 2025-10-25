//
//  GameSetupView.swift
//  DanDart
//
//  Game setup screen for configuring players and game options
//

import SwiftUI

struct GameSetupView: View {
    let game: Game
    @State private var selectedPlayers: [Player] = []
    @State private var showSearchPlayer: Bool = false
    @State private var showGameView: Bool = false
    @State private var selectedLegs: Int = 1 // Best of 1, 3, 5, or 7
    @Environment(\.dismiss) private var dismiss
    @StateObject private var navigationManager = NavigationManager.shared
    @EnvironmentObject private var authService: AuthService
    
    private let playerLimit = 8 // Maximum players for MVP
    private var canStartGame: Bool {
        selectedPlayers.count >= 2
    }
    
    // Check if current game supports legs (301/501 only)
    private var supportsLegs: Bool {
        game.title == "301" || game.title == "501"
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content with ScrollView
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Header with Cover Image
                    ZStack(alignment: .bottomLeading) {
                        // Cover Image
                        if let coverImage = UIImage(named: "game-cover/\(game.title)") {
                            Image(uiImage: coverImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 280)
                                .clipped()
                        } else {
                            // Fallback gradient if no image
                            LinearGradient(
                                colors: [
                                    Color("AccentPrimary").opacity(0.6),
                                    Color("AccentPrimary").opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: 280)
                        }
                        
                        // Gradient overlay for text readability
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.0),
                                Color.black.opacity(0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 280)
                        
                        // Game Title
                        Text(game.title)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.leading, 20)
                            .padding(.bottom, 24)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    
                    // Content below header
                    VStack(spacing: 24) {
                    // Legs Selection Section (301/501 only)
                    if supportsLegs {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Match Format")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Color("TextPrimary"))
                                
                                Spacer()
                            }
                            
                            // Segmented control for legs selection
                            HStack(spacing: 8) {
                                ForEach([1, 3, 5, 7], id: \.self) { legs in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedLegs = legs
                                        }
                                    }) {
                                        Text("Best of \(legs)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(selectedLegs == legs ? .white : Color("TextSecondary"))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(selectedLegs == legs ? Color("AccentPrimary") : Color("InputBackground"))
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    
                    // Player Selection Section
                    VStack(spacing: 16) {
                        HStack {
                            Text("Players")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color("TextPrimary"))
                            
                            Spacer()
                            
                            Text("\(selectedPlayers.count) of \(playerLimit)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                        }
                        
                        // Sequential Player Addition
                        VStack(spacing: 12) {
                            // Show selected players first
                            ForEach(Array(selectedPlayers.enumerated()), id: \.element.id) { index, player in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Player \(index + 1)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color("AccentPrimary"))
                                        Spacer()
                                    }
                                    
                                    PlayerCard(player: player, showRemoveButton: true) {
                                        removePlayer(player)
                                    }
                                }
                            }
                            
                            // Add next player button (if under limit)
                            if selectedPlayers.count < playerLimit {
                                AppButton(role: .primaryOutline, controlSize: .regular, compact: true) {
                                    showSearchPlayer = true
                                } label: {
                                    Label("Add Player \(selectedPlayers.count + 1)", systemImage: "plus")
                                        .font(.system(size: 16))
                                }
                            }
                        }
                        
                    }
                    
                    // Start Game Button
                    VStack(spacing: 12) {
                        AppButton(role: .primary, controlSize: .regular, isDisabled: !canStartGame) {
                            showGameView = true
                        } label: {
                            Text("Start Game")
                        }
                        .frame(maxWidth: .infinity)

                        if !canStartGame && selectedPlayers.count == 1 {
                            Text("Add at least one more player")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                        }
                    }
                    
                    // Game Instructions (moved to bottom)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to Play")
                            .font(.headline)
                            .foregroundStyle(Color("TextPrimary"))
                        
                        Text(game.instructions)
                            .font(.body)
                            .foregroundStyle(Color("TextSecondary"))
                    }
                    .padding(16)
                    .background(Color("InputBackground"))
                    .cornerRadius(12)
                    
                    Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
            }
            .background(Color("BackgroundPrimary"))
            .edgesIgnoringSafeArea(.top)
            
            // Transparent Navigation Bar Overlay
            VStack {
                HStack {
                    // Back Button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
            .toolbar(.hidden, for: .tabBar)
            .navigationDestination(isPresented: $showGameView) {
                // Always show black background to prevent white flash
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if !navigationManager.shouldDismissToGamesList {
                        PreGameHypeView(game: game, players: selectedPlayers, matchFormat: supportsLegs ? selectedLegs : 1)
                    }
                }
            }
            .onChange(of: navigationManager.shouldDismissToGamesList) {
                if navigationManager.shouldDismissToGamesList {
                    navigationManager.resetDismissFlag()
                    dismiss()
                }
            }
            .sheet(isPresented: $showSearchPlayer) {
                SearchPlayerSheet(selectedPlayers: selectedPlayers) { player in
                    addPlayer(player)
                }
            }
    }
    
    // MARK: - Helper Methods
    
    private func addPlayer(_ player: Player) {
        if selectedPlayers.count < playerLimit && !selectedPlayers.contains(where: { $0.id == player.id }) {
            selectedPlayers.append(player)
        }
    }
    
    private func removePlayer(_ player: Player) {
        selectedPlayers.removeAll { $0.id == player.id }
    }
}

// MARK: - Placeholder Sheet Components

struct SearchPlayerSheet: View {
    let selectedPlayers: [Player]
    let onPlayerSelected: (Player) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showAddGuestPlayer = false
    @State private var guestPlayers: [Player] = []
    
    // Mock current user - in real app this would come from AuthService
    private let currentUser = User.mockUser1
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    // Back button
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(Color("AccentPrimary"))
                    }
                    
                    Spacer()
                    
                    // Add Guest button
                    AppButton(role: .primary, controlSize: .small, compact: true) {
                        showAddGuestPlayer = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Guest")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .frame(width: 100)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color("BackgroundPrimary"))
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Add Player")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color("TextPrimary"))
                            
                            Text("Choose yourself, a friend, or add a new guest")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)
                        
                        // Current User Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("You")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color("TextPrimary"))
                                Spacer()
                            }
                            
                            Button(action: {
                                // Convert User to Player
                                let currentUserAsPlayer = Player(
                                    displayName: currentUser.displayName,
                                    nickname: currentUser.nickname,
                                    avatarURL: currentUser.avatarURL,
                                    isGuest: false,
                                    totalWins: currentUser.totalWins,
                                    totalLosses: currentUser.totalLosses
                                )
                                onPlayerSelected(currentUserAsPlayer)
                                dismiss()
                            }) {
                                PlayerCard(
                                    player: Player(
                                        displayName: currentUser.displayName,
                                        nickname: currentUser.nickname,
                                        avatarURL: currentUser.avatarURL,
                                        isGuest: false,
                                        totalWins: currentUser.totalWins,
                                        totalLosses: currentUser.totalLosses
                                    ),
                                    showCheckmark: selectedPlayers.contains(where: { $0.nickname == currentUser.nickname })
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(selectedPlayers.contains(where: { $0.nickname == currentUser.nickname }))
                        }
                        
                        // Friends section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Your Friends")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color("TextPrimary"))
                                Spacer()
                            }
                            
                            VStack(spacing: 12) {
                                ForEach(Player.mockConnectedPlayers, id: \.id) { player in
                                    Button(action: {
                                        onPlayerSelected(player)
                                        dismiss()
                                    }) {
                                        PlayerCard(
                                            player: player,
                                            showCheckmark: selectedPlayers.contains(where: { $0.id == player.id })
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .disabled(selectedPlayers.contains(where: { $0.id == player.id }))
                                }
                            }
                        }
                        
                        // Guest Players section
                        if !guestPlayers.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Guest Players")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(Color("TextPrimary"))
                                    Spacer()
                                }
                                
                                VStack(spacing: 12) {
                                    ForEach(guestPlayers, id: \.id) { player in
                                        Button(action: {
                                            onPlayerSelected(player)
                                            dismiss()
                                        }) {
                                            PlayerCard(
                                                player: player,
                                                showCheckmark: selectedPlayers.contains(where: { $0.id == player.id })
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .disabled(selectedPlayers.contains(where: { $0.id == player.id }))
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                deleteGuestPlayer(player)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .background(Color("BackgroundPrimary"))
            .navigationBarHidden(true)
            .onAppear {
                loadGuestPlayers()
            }
            .sheet(isPresented: $showAddGuestPlayer) {
                AddGuestPlayerView { player in
                    onPlayerSelected(player)
                    // Reload guest players to show the newly added one
                    loadGuestPlayers()
                    // AddGuestPlayerView dismisses itself, so we also dismiss the SearchPlayerSheet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadGuestPlayers() {
        guestPlayers = GuestPlayerStorageManager.shared.loadGuestPlayers()
    }
    
    private func deleteGuestPlayer(_ player: Player) {
        GuestPlayerStorageManager.shared.deleteGuestPlayer(id: player.id)
        loadGuestPlayers()
    }
}

// MARK: - Preview
#Preview {
    GameSetupView(game: Game.preview301)
}

#Preview("GameSetup - 501") {
    GameSetupView(game: Game.preview501)
}

#Preview("GameSetup - Dark Mode") {
    GameSetupView(game: Game.previewHalveIt)
        .preferredColorScheme(.dark)
}
