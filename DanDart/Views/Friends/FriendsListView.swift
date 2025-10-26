//
//  FriendsListView.swift
//  DanDart
//
//  Friends list view with search and add functionality
//

import SwiftUI

struct FriendsListView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var friendsService = FriendsService()
    
    @State private var searchText: String = ""
    @State private var showAddFriend: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var successMessage: String = ""
    @State private var showDeleteConfirmation: Bool = false
    @State private var friendToDelete: Player? = nil
    
    // Friends data loaded from Supabase
    @State private var friends: [Player] = []
    @State private var isLoadingFriends: Bool = false
    @State private var loadError: String?
    
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
                .padding(.top, 12)
                .padding(.bottom, 16)
            
            // Friends List, Loading, or Empty State
            if isLoadingFriends {
                // Loading State
                VStack(spacing: 16) {
                    Spacer()
                    
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color("AccentPrimary"))
                    
                    Text("Loading friends...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            } else if friends.isEmpty {
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
                        PlayerCard(player: friend)
                            .listRowBackground(Color("BackgroundPrimary"))
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    friendToDelete = friend
                                    showDeleteConfirmation = true
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .tint(.clear)
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
    
    /// Load friends from Supabase
    private func loadFriends() {
        guard let currentUserId = authService.currentUser?.id else {
            print("⚠️ No current user, cannot load friends")
            return
        }
        
        isLoadingFriends = true
        loadError = nil
        
        Task {
            do {
                // Load friends from Supabase
                let friendUsers = try await friendsService.loadFriends(userId: currentUserId)
                
                // Convert Users to Players
                friends = friendUsers.map { $0.toPlayer() }
                
                isLoadingFriends = false
                print("✅ Loaded \(friends.count) friends from Supabase")
                
            } catch {
                isLoadingFriends = false
                loadError = "Failed to load friends"
                print("❌ Load friends error: \(error)")
                
                // Show empty state on error
                friends = []
            }
        }
    }
    
    /// Add friend callback - reload friends list
    private func addFriend(_ player: Player) {
        // Reload friends list from Supabase
        loadFriends()
        
        // Show success message
        successMessage = "\(player.displayName) added to friends!"
        showSuccessAlert = true
    }
    
    /// Remove friend with confirmation
    private func removeFriend(_ player: Player) {
        guard let currentUserId = authService.currentUser?.id else {
            return
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        Task {
            do {
                // Remove friendship from Supabase
                try await friendsService.removeFriend(userId: currentUserId, friendId: player.id)
                
                // Reload friends list
                loadFriends()
                
                // Show success message
                successMessage = "\(player.displayName) removed from friends"
                showSuccessAlert = true
                
            } catch {
                print("❌ Remove friend error: \(error)")
                successMessage = "Failed to remove friend"
                showSuccessAlert = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Empty State") {
    FriendsListView()
        .environmentObject(AuthService.mockAuthenticated)
}

#Preview("With Friends") {
    FriendsListViewPreview()
}

// Preview wrapper with mock data
struct FriendsListViewPreview: View {
    @StateObject private var authService = AuthService.mockAuthenticated
    
    var body: some View {
        FriendsListViewWithMockData()
            .environmentObject(authService)
    }
}

struct FriendsListViewWithMockData: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var friendsService = FriendsService()
    
    @State private var searchText: String = ""
    @State private var showAddFriend: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var successMessage: String = ""
    @State private var showDeleteConfirmation: Bool = false
    @State private var friendToDelete: Player? = nil
    
    // Mock friends data
    @State private var friends: [Player] = Player.mockConnectedPlayers
    @State private var isLoadingFriends: Bool = false
    @State private var loadError: String?
    
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
                .padding(.top, 12)
                .padding(.bottom, 16)
            
                // Friends List
                List {
                    ForEach(filteredFriends) { friend in
                        PlayerCard(player: friend)
                            .listRowBackground(Color("BackgroundPrimary"))
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    friendToDelete = friend
                                    showDeleteConfirmation = true
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .tint(.clear)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color("BackgroundPrimary"))
            }
            .padding(.horizontal, 16)
            .background(Color("BackgroundPrimary"))
            .navigationTitle("Friends")
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
        .alert("Remove Friend?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                if let friend = friendToDelete {
                    friends.removeAll { $0.id == friend.id }
                }
            }
        } message: {
            if let friend = friendToDelete {
                Text("Are you sure you want to remove \(friend.displayName) from your friends?")
            }
        }
    }
}
