//
//  SearchPlayerSheet.swift
//  Dart Freak
//
//  Sheet for selecting players (yourself, friends, or guests) when setting up a game
//

import SwiftUI

struct SearchPlayerSheet: View {
    @Binding var selectedPlayers: [Player]
    @ObservedObject var friendsCache: FriendsCache // Injected from parent
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var friendsService: FriendsService
    @State private var isLoadingFriends = false
    @State private var showAddGuestPlayer = false
    @State private var guestPlayers: [Player] = []
    @State private var selectionLimitMessage: String = ""
    @State private var showSelectionLimitMessage: Bool = false
    
    private var playerLimit: Int {
        // Use a conservative max; GameSetupView enforces exact limit per game.
        // We'll pass the concrete limit from the parent later if needed.
        10
    }

    private var allPlayers: [Player] {
        var result: [Player] = []

        if let currentUser = authService.currentUser {
            let you = currentUser.toPlayer()
            result.append(you)
        }

        result.append(contentsOf: friendsCache.friends)
        result.append(contentsOf: guestPlayers)

        // Deduplicate by id and sort by displayName (except "you" stays first)
        var unique: [UUID: Player] = [:]
        for player in result {
            unique[player.id] = player
        }

        var players = Array(unique.values)

        // Keep current user at top if present
        if let currentUser = authService.currentUser {
            let youId = selectedPlayers.first(where: { $0.userId == currentUser.id })?.id ?? players.first(where: { $0.userId == currentUser.id })?.id
            players.sort { lhs, rhs in
                if lhs.userId == currentUser.id { return true }
                if rhs.userId == currentUser.id { return false }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        } else {
            players.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }

        return players
    }

    private func isSelected(_ player: Player) -> Bool {
        selectedPlayers.contains(where: { $0.id == player.id || ($0.userId != nil && $0.userId == player.userId) })
    }

    private func toggleSelection(_ player: Player) {
        if isSelected(player) {
            selectedPlayers.removeAll { $0.id == player.id || ($0.userId != nil && $0.userId == player.userId) }
        } else {
            guard selectedPlayers.count < playerLimit else {
                selectionLimitMessage = "You can only add up to \(playerLimit) players for this game"
                withAnimation {
                    showSelectionLimitMessage = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showSelectionLimitMessage = false
                    }
                }
                return
            }
            selectedPlayers.append(player)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if showSelectionLimitMessage {
                    Text(selectionLimitMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                        .padding(.vertical, 4)
                        .transition(.opacity)
                }

                VStack(spacing: 12) {
                    if isLoadingFriends {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if allPlayers.isEmpty {
                        Text("No players available yet")
                            .font(.system(size: 14))
                            .foregroundColor(AppColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ForEach(allPlayers, id: \.id) { player in
                            Button {
                                toggleSelection(player)
                            } label: {
                                PlayerCard(
                                    player: player,
                                    showCheckmark: isSelected(player)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(AppColor.surfacePrimary)
        .safeAreaInset(edge: .bottom) {
            BottomActionContainer {
                AppButton(role: .primary,
                          controlSize: .extraLarge) {
                    dismiss()
                } label: {
                    Text("Done")
                }
                
                .frame(width: UIScreen.main.bounds.width * 0.5)
            }
            .frame(maxWidth: .infinity)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAddGuestPlayer"))) { _ in
            // Show add guest player sheet when button tapped
            showAddGuestPlayer = true
        }
        .sheet(isPresented: $showAddGuestPlayer) {
            AddGuestPlayerView { player in
                toggleSelection(player)
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

#Preview("Search Player Sheet") {
    SearchPlayerSheet(
        selectedPlayers: .constant([]),
        friendsCache: FriendsCache()
    )
    .environmentObject(AuthService())
    .environmentObject(FriendsService())
}
