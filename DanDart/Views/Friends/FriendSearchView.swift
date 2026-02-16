//
//  FriendSearchView.swift
//  Dart Freak
//
//  Overlay view for searching and adding friends (matches History search pattern)
//

import SwiftUI

struct FriendSearchView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var authService: AuthService
    let onFriendAdded: (Player) -> Void
    
    @FocusState private var isSearchFieldFocused: Bool
    
    @EnvironmentObject private var friendsService: FriendsService
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
    
    // Search overlay (Liquid Glass pattern - matches MatchHistoryView)
    private var searchOverlay: some View {
        ZStack {
            // Dim background (covers everything including tab bar)
            AppColor.justBlack.opacity(0.4)
                .ignoresSafeArea(edges: .all)
                .onTapGesture {
                    stopSearch()
                }
            
            // Solid background for content area
            AppColor.backgroundPrimary
                .ignoresSafeArea(edges: .all)
            
            // Results area (full height, scrolls behind search bar)
            if searchQuery.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image("DartHeadOnly")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                    
                    VStack(spacing: 8) {
                        Text("Find Friends")
                            .font(.headline)
                            .foregroundColor(AppColor.textPrimary)
                        
                        Text("Search by name or @handle")
                            .font(.subheadline)
                            .foregroundColor(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                }
            } else {
                if isSearching {
                    // Loading state
                    VStack(spacing: 16) {
                        Spacer()
                        
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(AppColor.interactivePrimaryBackground)
                        
                        Text("Searching...")
                            .font(.headline)
                            .foregroundColor(AppColor.textPrimary)
                        
                        Spacer()
                    }
                } else if nonFriendResults.isEmpty {
                    // No results
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(AppColor.textSecondary)
                        
                        Text("No users found")
                            .font(.headline)
                            .foregroundColor(AppColor.textPrimary)
                        
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(AppColor.textSecondary)
                        
                        Spacer()
                    }
                } else {
                    // Results list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(nonFriendResults) { user in
                                FriendSearchResultCard(
                                    user: user,
                                    isLoading: isAddingFriend && sentRequestUserId == user.id,
                                    showSuccess: showSuccessMessage && sentRequestUserId == user.id,
                                    requestSent: sentRequestUserId == user.id,
                                    onAction: { sendFriendRequest(user) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 120)
                    }
                }
            }
            
            // Search bar pinned to bottom (overlays results in outer ZStack)
            VStack {
                Spacer()
                
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                        
                        TextField("Search by name or @handle", text: $searchQuery)
                            .font(.system(size: 17))
                            .foregroundColor(AppColor.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($isSearchFieldFocused)
                            .submitLabel(.search)
                        
                        if !searchQuery.isEmpty {
                            Button(action: {
                                searchQuery = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColor.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    )
                    
                    Button(action: { stopSearch() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                    )
                            )
                            .accessibilityLabel("Close search")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    var body: some View {
        searchOverlay
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
                // Auto-focus search field with slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFieldFocused = true
                }
            }
            .onChange(of: searchQuery) { oldValue, newValue in
                performSearch(query: newValue)
            }
    }
    
    private func stopSearch() {
        isSearchFieldFocused = false
        isPresented = false
        searchQuery = ""
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

                // Notify parent view so the Friends tab can refresh sent/received requests
                onFriendAdded(user.toPlayer())

                // Notify badge/count listeners
                NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsChanged"), object: nil)
                
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
                
                // Wait briefly to show "Sent" state, then auto-dismiss
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                stopSearch() // Dismiss overlay and return to friends list
                
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
    let isLoading: Bool
    let showSuccess: Bool
    let requestSent: Bool
    let onAction: () -> Void
    
    // Calculate button width based on "Friends" text (longest) + 16px padding (8px each side)
    private let buttonWidth: CGFloat = 72
    
    var body: some View {
        HStack(spacing: 16) {
            // Player Identity (avatar + name + handle) - using consistent component
            PlayerIdentity(player: user.toPlayer())
            
            Spacer()
            
            // Action Button with AppButton
            ZStack {
                if isLoading {
                    AppButton(role: .primary, controlSize: .small, isDisabled: true, compact: true, action: {}) {
                        ProgressView()
                            .tint(.white)
                    }
                    .frame(width: buttonWidth)
                    .transition(.scale.combined(with: .opacity))
                } else if showSuccess {
                    // Brief success state before showing "Sent"
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.green)
                        .frame(width: buttonWidth, height: 36)
                        .transition(.scale.combined(with: .opacity))
                } else if requestSent {
                    AppButton(role: .secondary, controlSize: .small, isDisabled: true, compact: true, action: {}) {
                        Text("Sent")
                            .foregroundColor(.white)
                    }
                    .frame(width: buttonWidth)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    AppButton(role: .primary, controlSize: .small, compact: true, action: onAction) {
                        Text("Add")
                    }
                    .frame(width: buttonWidth)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isLoading)
            .animation(.easeInOut(duration: 0.25), value: requestSent)
            .animation(.easeInOut(duration: 0.25), value: showSuccess)
        }
        .padding(16)  // 16px padding all around
        .background(
            Capsule()
                .fill(AppColor.inputBackground)
        )
        
    }
}

// MARK: - Preview

#Preview("Empty State") {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        
        var body: some View {
            ZStack {
                Color.black
                
                if isPresented {
                    FriendSearchView(
                        isPresented: $isPresented,
                        onFriendAdded: { player in
                            print("Added friend: \(player.displayName)")
                        }
                    )
                    .environmentObject(AuthService.mockAuthenticated)
                    .environmentObject(FriendsService())
                }
            }
        }
    }
    
    return PreviewWrapper()
}

#Preview("Search Results") {
    struct PreviewWrapper: View {
        @StateObject private var authService = AuthService.mockAuthenticated
        
        var body: some View {
            FriendSearchResultsPreview()
                .environmentObject(authService)
                .environmentObject(FriendsService())
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
