//
//  FriendsListView.swift
//  DanDart
//
//  Friends list view with search and add functionality
//

import SwiftUI

struct FriendsListView: View {
    @State private var searchText: String = ""
    @State private var showAddFriend: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var successMessage: String = ""
    @State private var showDeleteConfirmation: Bool = false
    @State private var friendToDelete: Player? = nil
    
    // Friends data loaded from local storage
    @State private var friends: [Player] = []
    
    var filteredFriends: [Player] {
        if searchText.isEmpty {
            return friends
        } else {
            return friends.filter { friend in
                friend.displayName.localizedCaseInsensitiveContains(searchText) ||
                friend.nickname.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                    
                    TextField("Search friends", text: $searchText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextPrimary"))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color("InputBackground"))
                .cornerRadius(12)
                .padding(.bottom, 16)
            
            // Friends List or Empty State
            if friends.isEmpty {
                // Empty State
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(Color("TextSecondary"))
                    
                    VStack(spacing: 8) {
                        Text("No friends yet")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color("TextPrimary"))
                        
                        Text("Add friends to challenge them to games")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                            .multilineTextAlignment(.center)
                    }
                    
                    AppButton(role: .primary, controlSize: .regular) {
                        showAddFriend = true
                    } label: {
                        Label("Add Your First Friend", systemImage: "person.badge.plus")
                    }
                    .frame(maxWidth: 280)
                    .padding(.top, 8)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            } else if filteredFriends.isEmpty {
                // No Search Results
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(Color("TextSecondary"))
                    
                    VStack(spacing: 8) {
                        Text("No results")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color("TextPrimary"))
                        
                        Text("Try searching for a different name")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            } else {
                // Friends List
                List {
                    ForEach(filteredFriends) { friend in
                        NavigationLink(destination: FriendProfileView(friend: friend)) {
                            PlayerCard(player: friend)
                        }
                        .listRowBackground(Color("BackgroundPrimary"))
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                friendToDelete = friend
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color("BackgroundPrimary"))
            }
            }
            .padding(.horizontal, 16)
            .background(Color("BackgroundPrimary"))
            .navigationTitle("Friends")
            /*'/.foregroundColor(Color.accentColor)*/
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddFriend = true
                    }) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color("AccentPrimary"))
                    }
                }
            }
            .toolbarBackground(Color("BackgroundPrimary"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .background(Color("BackgroundPrimary")).ignoresSafeArea()
        .onAppear {
            loadFriends()
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
        .alert("Remove Friend?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                if let friend = friendToDelete {
                    removeFriend(friend)
                }
            }
        } message: {
            if let friend = friendToDelete {
                Text("Are you sure you want to remove \(friend.displayName) from your friends?")
            }
        }
        .sheet(isPresented: $showAddFriend) {
            FriendSearchView { player in
                addFriend(player)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Load friends from local storage
    private func loadFriends() {
        friends = FriendsStorageManager.shared.loadFriends()
        
        // Add Bob as initial mock friend for testing (only if no friends exist)
        if friends.isEmpty {
            let bob = Player(
                displayName: "Bob Smith",
                nickname: "bobsmith",
                avatarURL: "avatar2",
                isGuest: false,
                totalWins: 12,
                totalLosses: 11
            )
            FriendsStorageManager.shared.addFriend(bob)
            friends = FriendsStorageManager.shared.loadFriends()
        }
    }
    
    /// Add friend with duplicate prevention and success feedback
    private func addFriend(_ player: Player) {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Try to add friend
        let success = FriendsStorageManager.shared.addFriend(player)
        
        if success {
            // Reload friends list
            loadFriends()
            
            // Show success message
            successMessage = "\(player.displayName) added to friends!"
            showSuccessAlert = true
        } else {
            // Already a friend
            successMessage = "\(player.displayName) is already your friend"
            showSuccessAlert = true
        }
    }
    
    /// Remove friend with confirmation
    private func removeFriend(_ player: Player) {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Remove from storage
        FriendsStorageManager.shared.removeFriend(withId: player.id)
        
        // Reload friends list
        loadFriends()
        
        // Show success message
        successMessage = "\(player.displayName) removed from friends"
        showSuccessAlert = true
    }
}

// MARK: - Preview

#Preview {
    FriendsListView()
}

#Preview("With Friends") {
    FriendsListView()
}
