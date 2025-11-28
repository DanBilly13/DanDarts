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
    
    // Shared content for both header styles
    private var contentBody: some View {
        VStack(spacing: 0) {
            // Search Bar (fixed at top)
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)

                TextField("Search by name or @handle", text: $searchQuery)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColor.textPrimary)
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
                            .foregroundColor(AppColor.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColor.inputBackground)
            .cornerRadius(12)
            .padding(.bottom, 16)

            // Content Area
            if isSearching {
                // Loading State
                VStack(spacing: 16) {
                    Spacer()

                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(AppColor.interactivePrimaryBackground)

                    Text("Searching...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)

                    Spacer()
                }
            } else if searchQuery.isEmpty {
                // Empty State - No Search Yet
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(AppColor.textSecondary)

                    VStack(spacing: 8) {
                        Text("Find Friends")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppColor.textPrimary)

                        Text("Search by name or @handle to add friends")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
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
                        .foregroundColor(AppColor.textSecondary)

                    VStack(spacing: 8) {
                        Text("No results found")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppColor.textPrimary)

                        Text("Try a different name or @handle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
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
                                    .foregroundColor(AppColor.textSecondary)

                                ForEach(friendResults) { user in
                                    FriendSearchResultCard(
                                        user: user,
                                        isFriend: true,
                                        isLoading: false,
                                        showSuccess: false,
                                        requestSent: false,
                                        onAction: {}
                                    )
                                }
                            }
                        }

                        // New People Section
                        if !nonFriendResults.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                if !friendResults.isEmpty {
                                    Text("Add Friends")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AppColor.textSecondary)
                                }

                                ForEach(nonFriendResults) { user in
                                    FriendSearchResultCard(
                                        user: user,
                                        isFriend: false,
                                        isLoading: isAddingFriend && sentRequestUserId == user.id,
                                        showSuccess: showSuccessMessage && sentRequestUserId == user.id,
                                        requestSent: sentRequestUserId == user.id,
                                        onAction: { sendFriendRequest(user) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
    }

    var body: some View {
        contentBody
            .padding(.horizontal, 16)
            .padding(.top, 8)
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

// MARK: - Friend Search Result Card

struct FriendSearchResultCard: View {
    let user: User
    let isFriend: Bool
    let isLoading: Bool
    let showSuccess: Bool
    let requestSent: Bool
    let onAction: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Player Identity (avatar + name + handle) - using consistent component
            PlayerIdentity(player: user.toPlayer())
            
            Spacer()
            
            // Action Button
            if isFriend {
                // Already Friends Badge
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                    Text("Friends")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColor.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColor.textSecondary.opacity(0.1))
                .cornerRadius(20)
            } else {
                // Invite Icon Button
                Button(action: onAction) {
                    ZStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.9)
                                .tint(AppColor.interactivePrimaryBackground)
                        } else if showSuccess {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.green)
                        } else if requestSent {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(AppColor.textSecondary)
                        } else {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AppColor.interactivePrimaryBackground)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(
                                requestSent
                                ? AppColor.textSecondary.opacity(0.15)
                                : AppColor.interactivePrimaryBackground.opacity(0.15)
                            )
                    )
                }
                .disabled(isLoading || requestSent)
            }
        }
        .padding(16)  // 16px padding all around
        .background(AppColor.surfacePrimary)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview("Empty State") {
    FriendSearchView { player in
        print("Added friend: \(player.displayName)")
    }
    .environmentObject(AuthService.mockAuthenticated)
}

#Preview("Search Results") {
    struct PreviewWrapper: View {
        @StateObject private var authService = AuthService.mockAuthenticated
        
        var body: some View {
            FriendSearchResultsPreview()
                .environmentObject(authService)
        }
    }
    
    return PreviewWrapper()
}

// Preview helper with fake search results
private struct FriendSearchResultsPreview: View {
    @State private var searchQuery = "ben"
    @State private var searchResults: [User] = [
        User(
            id: UUID(),
            displayName: "Ben Johnson",
            nickname: "benny",
            email: "ben@example.com",
            handle: "benjohnson",
            avatarURL: "avatar2",
            authProvider: .email,
            createdAt: Date(),
            lastSeenAt: Date(),
            totalWins: 5,
            totalLosses: 3
        ),
        User(
            id: UUID(),
            displayName: "Benjamin Smith",
            nickname: "bensmith",
            email: "bensmith@example.com",
            handle: "bensmith",
            avatarURL: "avatar3",
            authProvider: .email,
            createdAt: Date(),
            lastSeenAt: Date(),
            totalWins: 0,
            totalLosses: 0
        ),
        User(
            id: UUID(),
            displayName: "Ben Williams",
            nickname: "benwilliams",
            email: "benwilliams@example.com",
            handle: "benwilliams",
            avatarURL: "avatar1",
            authProvider: .google,
            createdAt: Date(),
            lastSeenAt: Date(),
            totalWins: 12,
            totalLosses: 8
        )
    ]
    @State private var sentRequestUserId: UUID?
    
    var body: some View {
        StandardSheetView(
            title: "Find Friends",
            dismissButtonTitle: "Back",
            useScrollView: false,
            onDismiss: {}
        ) {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                    
                    TextField("Search by name or @handle", text: $searchQuery)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textPrimary)
                        .autocorrectionDisabled()
                    
                    Button(action: {
                        searchQuery = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppColor.inputBackground)
                .cornerRadius(12)
                .padding(.bottom, 16)
                
                // Search Results
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Results")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColor.textSecondary)
                            
                            ForEach(searchResults) { user in
                                FriendSearchResultCard(
                                    user: user,
                                    isFriend: false,
                                    isLoading: false,
                                    showSuccess: false,
                                    requestSent: sentRequestUserId == user.id,
                                    onAction: {
                                        sentRequestUserId = user.id
                                    }
                                )
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
    }
}
