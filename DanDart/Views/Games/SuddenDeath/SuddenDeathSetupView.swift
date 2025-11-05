//
//  SuddenDeathSetupView.swift
//  DanDart
//
//  Created by DanDarts Team
//

import SwiftUI

struct SuddenDeathSetupView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @StateObject private var friendsService = FriendsService()
    
    // MARK: - State
    
    @State private var selectedPlayers: [Player] = []
    @State private var selectedLives: Int = 3
    @State private var showAddGuestSheet = false
    @State private var showFriendSearchSheet = false
    @State private var showGameView = false
    @State private var isLoadingFriends = false
    @State private var friends: [Player] = []
    @StateObject private var navigationManager = NavigationManager.shared
    
    // MARK: - Constants
    
    private let livesOptions = [1, 3, 5]
    private let maxPlayers = 10
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color("BackgroundPrimary")
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Game Title
                    Text(game.title)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Color("TextPrimary"))
                        .padding(.top, 20)
                    
                    // Lives Selector
                    livesSelector
                    
                    // Player Selection Section
                    playerSelectionSection
                    
                    // Selected Players
                    if !selectedPlayers.isEmpty {
                        selectedPlayersSection
                    }
                    
                    // Start Game Button
                    startGameButton
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddGuestSheet) {
            AddGuestPlayerView { newPlayer in
                addPlayer(newPlayer)
            }
        }
        .sheet(isPresented: $showFriendSearchSheet) {
            FriendSearchView { selectedFriend in
                addPlayer(selectedFriend)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $showGameView) {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if !navigationManager.shouldDismissToGamesList {
                    PreGameHypeView(
                        game: game,
                        players: selectedPlayers,
                        matchFormat: 1
                    )
                    .navigationDestination(isPresented: .constant(true)) {
                        SuddenDeathGameplayView(
                            game: game,
                            players: selectedPlayers,
                            startingLives: selectedLives
                        )
                    }
                }
            }
        }
        .onChange(of: navigationManager.shouldDismissToGamesList) {
            if navigationManager.shouldDismissToGamesList {
                navigationManager.resetDismissFlag()
                dismiss()
            }
        }
        .onAppear {
            loadFriends()
        }
    }
    
    // MARK: - Lives Selector
    
    private var livesSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lives")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color("TextPrimary"))
            
            HStack(spacing: 12) {
                ForEach(livesOptions, id: \.self) { lives in
                    Button(action: {
                        selectedLives = lives
                    }) {
                        Text("\(lives)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(selectedLives == lives ? Color("TextPrimary") : Color("TextSecondary"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                selectedLives == lives ?
                                Color("AccentPrimary") :
                                Color("InputBackground")
                            )
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    // MARK: - Player Selection Section
    
    private var playerSelectionSection: some View {
        VStack(spacing: 12) {
            // Add Guest Player Button
            Button(action: {
                showAddGuestSheet = true
            }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 20))
                    Text("Add Guest Player")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(Color("TextPrimary"))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color("InputBackground"))
                .cornerRadius(12)
            }
            .disabled(selectedPlayers.count >= maxPlayers)
            .opacity(selectedPlayers.count >= maxPlayers ? 0.5 : 1.0)
            
            // Search for Player Button
            Button(action: {
                showFriendSearchSheet = true
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                    Text("Search for Player")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(Color("TextPrimary"))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color("InputBackground"))
                .cornerRadius(12)
            }
            .disabled(selectedPlayers.count >= maxPlayers)
            .opacity(selectedPlayers.count >= maxPlayers ? 0.5 : 1.0)
            
            // Quick Add Friends
            if !friends.isEmpty {
                quickAddFriendsSection
            }
        }
    }
    
    // MARK: - Quick Add Friends
    
    private var quickAddFriendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Add")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color("TextPrimary"))
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(friends.prefix(5)) { friend in
                        if !selectedPlayers.contains(where: { $0.id == friend.id }) {
                            Button(action: {
                                addPlayer(friend)
                            }) {
                                VStack(spacing: 8) {
                                    AsyncAvatarImage(
                                        avatarURL: friend.avatarURL,
                                        size: 48
                                    )
                                    
                                    Text(friend.displayName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color("TextPrimary"))
                                        .lineLimit(1)
                                }
                                .frame(width: 80)
                            }
                            .disabled(selectedPlayers.count >= maxPlayers)
                            .opacity(selectedPlayers.count >= maxPlayers ? 0.5 : 1.0)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Selected Players Section
    
    private var selectedPlayersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Players (\(selectedPlayers.count)/\(maxPlayers))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("TextPrimary"))
                
                Spacer()
                
                if selectedPlayers.count >= 2 {
                    Text("Ready!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color("AccentPrimary"))
                }
            }
            
            VStack(spacing: 12) {
                ForEach(selectedPlayers) { player in
                    HStack {
                        PlayerCard(player: player)
                        
                        Button(action: {
                            removePlayer(player)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color("TextSecondary"))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Start Game Button
    
    private var startGameButton: some View {
        Button(action: {
            startGame()
        }) {
            Text("Start Game")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color("TextPrimary"))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    selectedPlayers.count >= 2 ?
                    Color("AccentPrimary") :
                    Color("InputBackground")
                )
                .cornerRadius(16)
        }
        .disabled(selectedPlayers.count < 2)
        .opacity(selectedPlayers.count < 2 ? 0.5 : 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func addPlayer(_ player: Player) {
        guard selectedPlayers.count < maxPlayers else { return }
        guard !selectedPlayers.contains(where: { $0.id == player.id }) else { return }
        
        selectedPlayers.append(player)
    }
    
    private func removePlayer(_ player: Player) {
        selectedPlayers.removeAll { $0.id == player.id }
    }
    
    private func loadFriends() {
        guard let currentUser = authService.currentUser else { return }
        
        isLoadingFriends = true
        
        Task {
            do {
                let loadedFriends = try await friendsService.loadFriends(userId: currentUser.id)
                friends = loadedFriends.map { $0.toPlayer() }
                isLoadingFriends = false
            } catch {
                print("❌ Failed to load friends: \(error)")
                isLoadingFriends = false
            }
        }
    }
    
    private func startGame() {
        guard selectedPlayers.count >= 2 else { return }
        showGameView = true
    }
}

// MARK: - Preview

#Preview("Setup View") {
    NavigationStack {
        SuddenDeathSetupView(game: Game.preview301)
            .environmentObject(AuthService())
    }
}
