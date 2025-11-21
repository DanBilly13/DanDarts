//
//  FriendsListView.swift
//  DanDart
//
//  Unified friends view with requests and friends list
//

import SwiftUI

struct FriendsListView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var friendsService = FriendsService()
    
    @State private var showSearch: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var successMessage: String = ""
    @State private var showDeleteConfirmation: Bool = false
    @State private var friendToDelete: Player? = nil
    
    // Friends data loaded from Supabase
    @State private var friends: [Player] = []
    @State private var receivedRequests: [FriendRequest] = []
    @State private var sentRequests: [FriendRequest] = []
    @State private var isLoadingFriends: Bool = false
    @State private var isLoadingRequests: Bool = false
    @State private var loadError: String?
    @State private var processingRequestId: UUID? = nil
    
    var body: some View {
        NavigationStack {
            List {
                // Received Requests Section (only show if any exist)
                if !receivedRequests.isEmpty {
                    Section {
                        ForEach(receivedRequests) { request in
                            ReceivedRequestCard(
                                request: request,
                                isProcessing: processingRequestId == request.id,
                                onAccept: { acceptRequest(request) },
                                onDeny: { denyRequest(request) }
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    } header: {
                        Text("Friend Requests")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColor.textPrimary)
                            .textCase(nil)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                
                // Sent Requests Section (only show if any exist)
                if !sentRequests.isEmpty {
                    Section {
                        ForEach(sentRequests) { request in
                            SentRequestCard(
                                request: request,
                                isProcessing: processingRequestId == request.id
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    withdrawRequest(request)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .tint(.clear)
                                
                                Button {
                                    sendAgainRequest(request)
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(Color("AccentSecondary"))
                                }
                                .tint(.clear)
                            }
                        }
                    } header: {
                        Text("Requests Sent")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColor.textPrimary)
                            .textCase(nil)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                
                // Friends Section
                if !friends.isEmpty {
                    Section {
                        ForEach(friends) { friend in
                            ZStack {
                                NavigationLink(destination: FriendProfileView(friend: friend)) {
                                    EmptyView()
                                }
                                .opacity(0)
                                
                                PlayerCard(player: friend)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
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
                    } header: {
                        Text("Friends")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColor.textPrimary)
                            .textCase(nil)
                    }
                } else if !isLoadingFriends && !isLoadingRequests {
                    // Empty State - No friends
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(AppColor.textSecondary)
                            
                            VStack(spacing: 8) {
                                Text("No friends yet")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(AppColor.textPrimary)
                                
                                Text("Search for friends to add them")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppColor.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            AppButton(role: .primary, controlSize: .regular) {
                                showSearch = true
                            } label: {
                                Label("Find Friends", systemImage: "magnifyingglass")
                            }
                            .frame(maxWidth: 280)
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .listRowInsets(EdgeInsets())
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                
                // Loading State
                if isLoadingFriends || isLoadingRequests {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(AppColor.interactivePrimaryBackground)
                            Spacer()
                        }
                        .padding(.vertical, 32)
                        .listRowInsets(EdgeInsets())
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppColor.backgroundPrimary)
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSearch = true
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                }
            }
            .toolbarBackground(AppColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .background(AppColor.backgroundPrimary).ignoresSafeArea()
        .onAppear {
            loadFriends()
            loadRequests()
        }
        .sheet(isPresented: $showSearch) {
            FriendSearchView { player in
                // Reload after adding friend
                loadFriends()
                loadRequests()
                successMessage = "Friend request sent to \(player.displayName)!"
                showSuccessAlert = true
            }
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
        guard let currentUserId = authService.currentUser?.id,
              let friendUserId = player.userId else {
            print("⚠️ Cannot remove friend: missing user ID")
            return
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Optimistically remove from UI immediately
        friends.removeAll { $0.id == player.id }
        
        Task {
            do {
                // Remove friendship from Supabase
                try await friendsService.removeFriend(userId: currentUserId, friendId: friendUserId)
                
                // Show success message
                successMessage = "\(player.displayName) removed from friends"
                showSuccessAlert = true
                
            } catch {
                print("❌ Remove friend error: \(error)")
                // Reload on error to restore the friend
                loadFriends()
                successMessage = "Failed to remove friend"
                showSuccessAlert = true
            }
        }
    }
    
    /// Load friend requests (received and sent)
    private func loadRequests() {
        guard let currentUserId = authService.currentUser?.id else {
            print("⚠️ No current user, cannot load requests")
            return
        }
        
        isLoadingRequests = true
        
        Task {
            do {
                // Load received and sent requests separately
                async let receivedTask = friendsService.loadReceivedRequests(userId: currentUserId)
                async let sentTask = friendsService.loadSentRequests(userId: currentUserId)
                
                let (received, sent) = try await (receivedTask, sentTask)
                
                receivedRequests = received
                sentRequests = sent
                
                isLoadingRequests = false
                print("✅ Loaded \(received.count) received, \(sent.count) sent requests")
                
            } catch {
                isLoadingRequests = false
                print("❌ Load requests error: \(error)")
                receivedRequests = []
                sentRequests = []
            }
        }
    }
    
    /// Accept friend request
    private func acceptRequest(_ request: FriendRequest) {
        processingRequestId = request.id
        
        Task {
            do {
                try await friendsService.acceptFriendRequest(requestId: request.id)
                
                // Success haptic
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
                
                // Reload both friends and requests
                loadFriends()
                loadRequests()
                
                // Notify MainTabView to update badge
                NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsChanged"), object: nil)
                
                processingRequestId = nil
                
            } catch {
                print("❌ Accept request error: \(error)")
                
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
                
                processingRequestId = nil
            }
        }
    }
    
    /// Deny friend request
    private func denyRequest(_ request: FriendRequest) {
        processingRequestId = request.id
        
        Task {
            do {
                try await friendsService.denyFriendRequest(requestId: request.id)
                
                // Light haptic
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                // Reload requests
                loadRequests()
                
                // Notify MainTabView to update badge
                NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsChanged"), object: nil)
                
                processingRequestId = nil
                
            } catch {
                print("❌ Deny request error: \(error)")
                processingRequestId = nil
            }
        }
    }
    
    /// Withdraw sent friend request
    private func withdrawRequest(_ request: FriendRequest) {
        processingRequestId = request.id
        
        Task {
            do {
                try await friendsService.withdrawFriendRequest(requestId: request.id)
                
                // Light haptic
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                // Reload requests
                loadRequests()
                
                processingRequestId = nil
                
            } catch {
                print("❌ Withdraw request error: \(error)")
                processingRequestId = nil
            }
        }
    }
    
    /// Send friend request again
    private func sendAgainRequest(_ request: FriendRequest) {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        processingRequestId = request.id
        
        Task {
            do {
                // First withdraw the old request
                try await friendsService.withdrawFriendRequest(requestId: request.id)
                
                // Then send a new request
                try await friendsService.sendFriendRequest(userId: currentUserId, friendId: request.user.id)
                
                // Success haptic
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
                
                // Reload requests
                loadRequests()
                
                processingRequestId = nil
                
            } catch {
                print("❌ Send again error: \(error)")
                
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
                
                processingRequestId = nil
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
                        .foregroundColor(AppColor.textSecondary)
                    
                    TextField("Search friends", text: $searchText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
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
                .padding(.top, 12)
                .padding(.bottom, 16)
            
                // Friends List
                List {
                    ForEach(filteredFriends) { friend in
                        PlayerCard(player: friend)
                            .listRowBackground(AppColor.backgroundPrimary)
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
                .background(AppColor.backgroundPrimary)
            }
            .padding(.horizontal, 16)
            .background(AppColor.backgroundPrimary)
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddFriend = true
                    }) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                }
            }
            .toolbarBackground(AppColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .background(AppColor.backgroundPrimary).ignoresSafeArea()
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
