//
//  SearchPlayerSheet.swift
//  DanDart
//
//  Sheet for selecting players (yourself, friends, or guests) when setting up a game
//

import SwiftUI

struct SearchPlayerSheet: View {
    let selectedPlayers: [Player]
    let onPlayerSelected: (Player) -> Void
    @ObservedObject var friendsCache: FriendsCache // Injected from parent
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @StateObject private var friendsService = FriendsService()
    @State private var isLoadingFriends = false
    @State private var showAddGuestPlayer = false
    @State private var guestPlayers: [Player] = []
    
    var body: some View {
        StandardSheetView(
            title: "Add Player",
            dismissButtonTitle: "Back",
            onDismiss: { dismiss() }
        ) {
            VStack(spacing: 0) {
                // Subtitle + Add Guest button
                HStack {
                    Text("Choose yourself, a friend, or add a new guest")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                        .multilineTextAlignment(.leading)
                    
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
                .padding(.bottom, 24)
                
                VStack(spacing: 24) {
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
                                        showCheckmark: selectedPlayers.contains(where: { $0.userId == currentUser.id })
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(selectedPlayers.contains(where: { $0.userId == currentUser.id }))
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
                            } else if friendsCache.friends.isEmpty {
                                Text("No friends yet")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color("TextSecondary"))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(friendsCache.friends, id: \.id) { player in
                                        Button(action: {
                                            onPlayerSelected(player)
                                            dismiss()
                                        }) {
                                            PlayerCard(
                                                player: player,
                                                showCheckmark: selectedPlayers.contains(where: { $0.userId == player.userId })
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .disabled(selectedPlayers.contains(where: { $0.userId == player.userId }))
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
                                
                                // Use List for swipe actions
                                List {
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
                                        .listRowBackground(Color.clear)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                        .deleteSwipeAction {
                                            deleteGuestPlayer(player)
                                        }
                                    }
                                }
                                .listStyle(.plain)
                                .scrollDisabled(true)
                                .frame(height: CGFloat(guestPlayers.count) * 92) // 80pt card + 12pt spacing
                            }
                        }
                }
            }
        }
        .onAppear {
            loadGuestPlayers()
            if !friendsCache.hasFriendsLoaded {
                print("🔵 Loading friends for first time")
                loadFriends()
            } else {
                print("🟢 Friends already loaded, just updating stats")
                updateFriendStats()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MatchCompleted"))) { _ in
            // Update friend stats after a match (without recreating Player objects)
            updateFriendStats()
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
    
    // MARK: - Helper Methods
    
    private func loadFriends() {
        guard let currentUser = authService.currentUser else { return }
        
        isLoadingFriends = true
        Task {
            do {
                let friendUsers = try await friendsService.loadFriends(userId: currentUser.id)
                // Convert Users to Players with userId properly set
                await MainActor.run {
                    friendsCache.friends = friendUsers.map { $0.toPlayer() }
                    isLoadingFriends = false
                    friendsCache.hasFriendsLoaded = true // Mark as loaded
                }
            } catch {
                print("❌ Failed to load friends: \(error)")
                await MainActor.run {
                    isLoadingFriends = false
                }
            }
        }
    }
    
    private func updateFriendStats() {
        guard let currentUser = authService.currentUser else { return }
        
        Task {
            do {
                let friendUsers = try await friendsService.loadFriends(userId: currentUser.id)
                // Update stats for existing Player objects instead of replacing them
                await MainActor.run {
                    for friendUser in friendUsers {
                        if let index = friendsCache.friends.firstIndex(where: { $0.userId == friendUser.id }) {
                            let existingPlayer = friendsCache.friends[index]
                            // Create new Player with updated stats but same id
                            friendsCache.friends[index] = Player(
                                id: existingPlayer.id, // Keep same id to maintain selection state
                                displayName: friendUser.displayName,
                                nickname: friendUser.nickname,
                                avatarURL: friendUser.avatarURL,
                                isGuest: false,
                                totalWins: friendUser.totalWins,
                                totalLosses: friendUser.totalLosses,
                                userId: friendUser.id
                            )
                        }
                    }
                }
            } catch {
                print("❌ Failed to update friend stats: \(error)")
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
