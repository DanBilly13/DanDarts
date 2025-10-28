//
//  FriendSearchView.swift
//  DanDart
//
//  Sheet view for searching and adding friends
//

import SwiftUI

struct FriendSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    let onFriendAdded: (Player) -> Void
    
    @StateObject private var friendsService = FriendsService()
    @State private var searchQuery: String = ""
    @State private var searchResults: [User] = []
    @State private var existingFriends: [User] = [] // Current friends
    @State private var isSearching: Bool = false
    @State private var searchError: String?
    @State private var isAddingFriend: Bool = false
    @State private var addFriendError: String?
    @State private var showSuccessMessage: Bool = false
    @State private var sentRequestUserId: UUID? = nil // Track which user has pending request
    
    // Computed: separate results into friends and non-friends
    var friendResults: [User] {
        searchResults.filter { user in
            existingFriends.contains(where: { $0.id == user.id })
        }
    }
    
    var nonFriendResults: [User] {
        searchResults.filter { user in
            !existingFriends.contains(where: { $0.id == user.id })
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                    
                    TextField("Search by name or @handle", text: $searchQuery)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextPrimary"))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: searchQuery) { oldValue, newValue in
                            performSearch(query: newValue)
                        }
                    
                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                            searchResults = []
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
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                // Content Area
                if isSearching {
                    // Loading State
                    VStack(spacing: 16) {
                        Spacer()
                        
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Color("AccentPrimary"))
                        
                        Text("Searching...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                        
                        Spacer()
                    }
                } else if searchQuery.isEmpty {
                    // Empty State - No Search Yet
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(Color("TextSecondary"))
                        
                        VStack(spacing: 8) {
                            Text("Find Friends")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color("TextPrimary"))
                            
                            Text("Search by name or @handle to add friends")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                } else if searchResults.isEmpty {
                    // No Results State
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(Color("TextSecondary"))
                        
                        VStack(spacing: 8) {
                            Text("No results found")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color("TextPrimary"))
                            
                            Text("Try a different name or @handle")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                } else {
                    // Search Results List - Mixed (Friends + New People)
                    ScrollView {
                        VStack(spacing: 16) {
                            // Existing Friends Section
                            if !friendResults.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Friends")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Color("TextSecondary"))
                                        .padding(.horizontal, 16)
                                    
                                    ForEach(friendResults) { user in
                                        HStack(spacing: 16) {
                                            // Player Card
                                            PlayerCard(player: user.toPlayer())
                                            
                                            // Already Friends Badge
                                            HStack(spacing: 4) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.green)
                                                Text("Friends")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(Color("TextSecondary"))
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color("TextSecondary").opacity(0.1))
                                            .cornerRadius(20)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color("InputBackground"))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            
                            // New People Section
                            if !nonFriendResults.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    if !friendResults.isEmpty {
                                        Text("Add Friends")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color("TextSecondary"))
                                            .padding(.horizontal, 16)
                                    }
                                    
                                    ForEach(nonFriendResults) { user in
                                        HStack(spacing: 16) {
                                            // Player Card
                                            PlayerCard(player: user.toPlayer())
                                            
                                            // Send Request Button
                                            Button(action: {
                                                sendFriendRequest(user)
                                            }) {
                                                ZStack {
                                                    if isAddingFriend && sentRequestUserId == user.id {
                                                        ProgressView()
                                                            .tint(Color("AccentPrimary"))
                                                    } else if showSuccessMessage && sentRequestUserId == user.id {
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 20, weight: .bold))
                                                            .foregroundColor(.green)
                                                    } else if sentRequestUserId == user.id {
                                                        // Request Sent state
                                                        Image(systemName: "paperplane.fill")
                                                            .font(.system(size: 18, weight: .semibold))
                                                            .foregroundColor(Color("TextSecondary"))
                                                    } else {
                                                        Image(systemName: "person.badge.plus")
                                                            .font(.system(size: 20, weight: .semibold))
                                                            .foregroundColor(Color("AccentPrimary"))
                                                    }
                                                }
                                                .frame(width: 44, height: 44)
                                                .background(
                                                    Circle()
                                                        .fill(
                                                            sentRequestUserId == user.id 
                                                            ? Color("TextSecondary").opacity(0.15)
                                                            : Color("AccentPrimary").opacity(0.15)
                                                        )
                                                )
                                            }
                                            .disabled(isAddingFriend || sentRequestUserId == user.id)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color("InputBackground"))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .background(Color("BackgroundPrimary"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Find Friends")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color("TextPrimary"))
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
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
                }
            }
            .alert("Error", isPresented: .constant(addFriendError != nil)) {
                Button("OK") {
                    addFriendError = nil
                }
            } message: {
                if let error = addFriendError {
                    Text(error)
                }
            }
            .onAppear {
                loadExistingFriends()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Perform search with Supabase
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        // Set loading state
        isSearching = true
        searchError = nil
        
        // Debounce search with 500ms delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            do {
                // Search users in Supabase
                let users = try await friendsService.searchUsers(query: query, limit: 20)
                
                // Filter out current user from results
                if let currentUserId = authService.currentUser?.id {
                    searchResults = users.filter { $0.id != currentUserId }
                } else {
                    searchResults = users
                }
                
                isSearching = false
                
            } catch {
                print("❌ Search error: \(error)")
                searchError = "Failed to search. Please try again."
                searchResults = []
                isSearching = false
            }
        }
    }
    
    /// Send friend request (Task 301)
    private func sendFriendRequest(_ user: User) {
        guard let currentUserId = authService.currentUser?.id else {
            addFriendError = "You must be signed in to send friend requests"
            return
        }
        
        // Set loading state
        isAddingFriend = true
        sentRequestUserId = user.id
        addFriendError = nil
        
        Task {
            do {
                // Send friend request in Supabase (status: pending)
                try await friendsService.sendFriendRequest(userId: currentUserId, friendId: user.id)
                
                // Success haptic feedback
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
                
                // Show success message briefly
                showSuccessMessage = true
                
                // Wait a moment to show success checkmark
                try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
                
                // Update button to "Request Sent" state
                showSuccessMessage = false
                isAddingFriend = false
                // sentRequestUserId remains set to show "Request Sent" state
                
            } catch let error as FriendsError {
                // Handle specific friend errors
                isAddingFriend = false
                sentRequestUserId = nil
                addFriendError = error.localizedDescription
                
                // Error haptic feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
                
            } catch {
                // Handle generic errors
                isAddingFriend = false
                sentRequestUserId = nil
                addFriendError = "Failed to send friend request. Please try again."
                
                // Error haptic feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
                
                print("❌ Send friend request error: \(error)")
            }
        }
    }
    
    /// Load existing friends to show in mixed results
    private func loadExistingFriends() {
        guard let currentUserId = authService.currentUser?.id else {
            return
        }
        
        Task {
            do {
                existingFriends = try await friendsService.loadFriends(userId: currentUserId)
                print("✅ Loaded \(existingFriends.count) existing friends for search")
            } catch {
                print("❌ Failed to load existing friends: \(error)")
                existingFriends = []
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FriendSearchView { player in
        print("Added friend: \(player.displayName)")
    }
    .environmentObject(AuthService.mockAuthenticated)
}
