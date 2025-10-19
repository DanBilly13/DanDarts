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
    @State private var isSearching: Bool = false
    @State private var searchError: String?
    @State private var isAddingFriend: Bool = false
    @State private var addFriendError: String?
    @State private var showSuccessMessage: Bool = false
    
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
                    // Search Results List
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(searchResults) { user in
                                HStack(spacing: 16) {
                                    // Player Card (convert User to Player)
                                    PlayerCard(player: user.toPlayer())
                                    
                                    // Add Friend Button
                                    Button(action: {
                                        addFriend(user)
                                    }) {
                                        ZStack {
                                            if isAddingFriend {
                                                ProgressView()
                                                    .tint(Color("AccentPrimary"))
                                            } else if showSuccessMessage {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 20, weight: .bold))
                                                    .foregroundColor(.green)
                                            } else {
                                                Image(systemName: "person.badge.plus")
                                                    .font(.system(size: 20, weight: .semibold))
                                                    .foregroundColor(Color("AccentPrimary"))
                                            }
                                        }
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .fill(Color("AccentPrimary").opacity(0.15))
                                        )
                                    }
                                    .disabled(isAddingFriend || showSuccessMessage)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color("InputBackground"))
                                .cornerRadius(12)
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
                    Text("Add Friend")
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
    
    /// Add friend and dismiss sheet
    private func addFriend(_ user: User) {
        guard let currentUserId = authService.currentUser?.id else {
            addFriendError = "You must be signed in to add friends"
            return
        }
        
        // Set loading state
        isAddingFriend = true
        addFriendError = nil
        
        Task {
            do {
                // Create friendship in Supabase
                try await friendsService.addFriend(userId: currentUserId, friendId: user.id)
                
                // Success haptic feedback
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
                
                // Show success message briefly
                showSuccessMessage = true
                
                // Convert User to Player and call callback
                onFriendAdded(user.toPlayer())
                
                // Wait a moment to show success, then dismiss
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                isAddingFriend = false
                dismiss()
                
            } catch let error as FriendsError {
                // Handle specific friend errors
                isAddingFriend = false
                addFriendError = error.localizedDescription
                
                // Error haptic feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
                
            } catch {
                // Handle generic errors
                isAddingFriend = false
                addFriendError = "Failed to add friend. Please try again."
                
                // Error haptic feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
                
                print("❌ Add friend error: \(error)")
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
