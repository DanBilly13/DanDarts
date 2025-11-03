//
//  CountdownSetupView.swift
//  DanDart
//
//  Game setup screen for countdown games (301/501) with player selection and match format
//

import SwiftUI

struct CountdownSetupView: View {
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
                            SegmentedControl(options: [1, 3, 5, 7], selection: $selectedLegs) { legs in
                                "Best of \(legs)"
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
                            // Show selected players in a List for swipe actions
                            List {
                                ForEach(Array(selectedPlayers.enumerated()), id: \.element.id) { index, player in
                                    PlayerCard(player: player, playerNumber: index + 1)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button {
                                                removePlayer(player)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.red)
                                            }
                                            .tint(.clear)
                                        }
                                }
                            }
                            .listStyle(.plain)
                            .scrollDisabled(true)
                            .frame(height: CGFloat(selectedPlayers.count * 92)) // 80pt card + 12pt spacing
                            .background(Color.clear)
                            
                            // Add next player button (if under limit)
                            if selectedPlayers.count < playerLimit {
                                AppButton(role: .primaryOutline, controlSize: .extraLarge, compact: true) {
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
                        AppButton(role: .primary, controlSize: .extraLarge, isDisabled: !canStartGame) {
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
    @EnvironmentObject private var authService: AuthService
    @StateObject private var friendsService = FriendsService()
    @State private var friends: [Player] = []
    @State private var isLoadingFriends = false
    @State private var showAddGuestPlayer = false
    @State private var guestPlayers: [Player] = []
    
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
                        if let currentUser = authService.currentUser {
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
                                        id: UUID(), // Generate new player ID
                                        displayName: currentUser.displayName,
                                        nickname: currentUser.nickname,
                                        avatarURL: currentUser.avatarURL,
                                        isGuest: false,
                                        totalWins: currentUser.totalWins,
                                        totalLosses: currentUser.totalLosses,
                                        userId: currentUser.id // CRITICAL: Link to user account for stats
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
                        }
                        
                        // Friends section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Your Friends")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color("TextPrimary"))
                                Spacer()
                            }
                            
                            if isLoadingFriends {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else if friends.isEmpty {
                                Text("No friends yet")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color("TextSecondary"))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(friends, id: \.id) { player in
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
                loadFriends()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MatchCompleted"))) { _ in
                // Reload friends to get updated stats after a match
                loadFriends()
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
    
    private func loadFriends() {
        guard let currentUser = authService.currentUser else { return }
        
        isLoadingFriends = true
        Task {
            do {
                let friendUsers = try await friendsService.loadFriends(userId: currentUser.id)
                // Convert Users to Players with userId properly set
                await MainActor.run {
                    friends = friendUsers.map { $0.toPlayer() }
                    isLoadingFriends = false
                }
            } catch {
                print("❌ Failed to load friends: \(error)")
                await MainActor.run {
                    isLoadingFriends = false
                }
            }
        }
    }
    
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
    CountdownSetupView(game: Game.preview301)
}

#Preview("CountdownSetup - 501") {
    CountdownSetupView(game: Game.preview501)
}

#Preview("CountdownSetup - Dark Mode") {
    CountdownSetupView(game: Game.preview301)
        .preferredColorScheme(.dark)
}
