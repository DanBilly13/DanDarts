//
//  FriendRequestsView.swift
//  DanDart
//
//  View for managing friend requests (received and sent)
//  Task 302: Create Friend Requests View
//

import SwiftUI

struct FriendRequestsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @StateObject private var friendsService = FriendsService()
    
    @State private var receivedRequests: [FriendRequest] = []
    @State private var sentRequests: [FriendRequest] = []
    @State private var isLoading: Bool = false
    @State private var loadError: String?
    @State private var isRefreshing: Bool = false
    @State private var processingRequestId: UUID? = nil
    @State private var showSuccessMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Received Requests Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Received Requests")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color("TextPrimary"))
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        
                        if isLoading && receivedRequests.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .tint(Color("AccentPrimary"))
                                Spacer()
                            }
                            .padding(.vertical, 32)
                        } else if receivedRequests.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundColor(Color("TextSecondary"))
                                
                                Text("No pending requests")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color("TextSecondary"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(receivedRequests) { request in
                                    ReceivedRequestCard(
                                        request: request,
                                        isProcessing: processingRequestId == request.id,
                                        onAccept: { acceptRequest(request) },
                                        onDeny: { denyRequest(request) }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 24)
                    
                    // Divider
                    Rectangle()
                        .fill(Color("TextSecondary").opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    
                    // Sent Requests Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sent Requests")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color("TextPrimary"))
                            .padding(.horizontal, 16)
                        
                        if isLoading && sentRequests.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .tint(Color("AccentPrimary"))
                                Spacer()
                            }
                            .padding(.vertical, 32)
                        } else if sentRequests.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "paperplane")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundColor(Color("TextSecondary"))
                                
                                Text("No pending requests")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color("TextSecondary"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        } else {
                            // Standalone List with swipe actions (matching GameSetupView pattern)
                            VStack(spacing: 12) {
                                List {
                                    ForEach(sentRequests) { request in
                                        SentRequestCard(
                                            request: request,
                                            isProcessing: processingRequestId == request.id
                                        )
                                        .contentShape(Rectangle())
                                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
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
                                }
                                .listStyle(.plain)
                                .scrollDisabled(true)
                                .frame(height: CGFloat(sentRequests.count * 92))
                                .background(Color.clear)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
            .background(Color("BackgroundPrimary"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Friend Requests")
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
            .refreshable {
                await refreshRequests()
            }
            .onAppear {
                loadRequests()
            }
            .overlay(
                // Success Message Banner
                VStack {
                    if let message = showSuccessMessage {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.green)
                            
                            Text(message)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TextPrimary"))
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color("InputBackground"))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    Spacer()
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showSuccessMessage)
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Load all friend requests
    private func loadRequests() {
        guard let currentUserId = authService.currentUser?.id else {
            return
        }
        
        isLoading = true
        loadError = nil
        
        Task {
            do {
                // Load received and sent requests in parallel
                async let received = friendsService.loadReceivedRequests(userId: currentUserId)
                async let sent = friendsService.loadSentRequests(userId: currentUserId)
                
                receivedRequests = try await received
                sentRequests = try await sent
                
                isLoading = false
                
            } catch {
                print("❌ Load requests error: \(error)")
                loadError = "Failed to load requests"
                isLoading = false
            }
        }
    }
    
    /// Refresh requests (pull-to-refresh)
    private func refreshRequests() async {
        guard let currentUserId = authService.currentUser?.id else {
            return
        }
        
        isRefreshing = true
        
        do {
            // Load received and sent requests in parallel
            async let received = friendsService.loadReceivedRequests(userId: currentUserId)
            async let sent = friendsService.loadSentRequests(userId: currentUserId)
            
            receivedRequests = try await received
            sentRequests = try await sent
            
            isRefreshing = false
            
        } catch {
            print("❌ Refresh requests error: \(error)")
            isRefreshing = false
        }
    }
    
    /// Accept a friend request (Task 303)
    private func acceptRequest(_ request: FriendRequest) {
        processingRequestId = request.id
        
        Task {
            do {
                // Update friendship status to 'accepted'
                try await friendsService.acceptFriendRequest(requestId: request.id)
                
                // Success haptic feedback
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
                
                // Show success message
                showSuccessMessage = "You are now friends with \(request.user.displayName)"
                
                // Remove from received requests
                receivedRequests.removeAll { $0.id == request.id }
                
                // Clear processing state
                processingRequestId = nil
                
                // Auto-dismiss success message after 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                showSuccessMessage = nil
                
            } catch {
                print("❌ Accept request error: \(error)")
                processingRequestId = nil
                
                // Error haptic feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
        }
    }
    
    /// Deny a friend request (Task 304)
    private func denyRequest(_ request: FriendRequest) {
        processingRequestId = request.id
        
        Task {
            do {
                // Delete the friendship record
                try await friendsService.denyFriendRequest(requestId: request.id)
                
                // Light haptic feedback (subtle)
                let lightFeedback = UIImpactFeedbackGenerator(style: .light)
                lightFeedback.impactOccurred()
                
                // Remove from received requests
                receivedRequests.removeAll { $0.id == request.id }
                
                // Clear processing state
                processingRequestId = nil
                
            } catch {
                print("❌ Deny request error: \(error)")
                processingRequestId = nil
                
                // Error haptic feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
        }
    }
    
    /// Withdraw a friend request (Task 305)
    private func withdrawRequest(_ request: FriendRequest) {
        processingRequestId = request.id
        
        Task {
            do {
                // Delete the friendship record
                try await friendsService.withdrawFriendRequest(requestId: request.id)
                
                // Light haptic feedback (subtle)
                let lightFeedback = UIImpactFeedbackGenerator(style: .light)
                lightFeedback.impactOccurred()
                
                // Remove from sent requests
                sentRequests.removeAll { $0.id == request.id }
                
                // Clear processing state
                processingRequestId = nil
                
            } catch {
                print("❌ Withdraw request error: \(error)")
                processingRequestId = nil
                
                // Error haptic feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
        }
    }
    
    /// Send friend request again - Send Again action
    private func sendAgainRequest(_ request: FriendRequest) {
        guard let currentUserId = authService.currentUser?.id else { return }
        
        processingRequestId = request.id
        
        Task {
            do {
                // First withdraw the old request
                try await friendsService.withdrawFriendRequest(requestId: request.id)
                
                // Then send a new request
                try await friendsService.sendFriendRequest(userId: currentUserId, friendId: request.user.id)
                
                // Success haptic feedback
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
                
                // Reload requests to show updated timestamp
                loadRequests()
                
                processingRequestId = nil
                
            } catch {
                print("❌ Send again error: \(error)")
                
                // Error haptic feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
                
                processingRequestId = nil
            }
        }
    }
}

// MARK: - Received Request Card

struct ReceivedRequestCard: View {
    let request: FriendRequest
    let isProcessing: Bool
    let onAccept: () -> Void
    let onDeny: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Player Card with time label
            ZStack(alignment: .topTrailing) {
                PlayerCard(player: request.user.toPlayer())
                
                // Time label
                Text(request.timeAgo)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color("TextSecondary"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color("BackgroundPrimary").opacity(0.8))
                    .cornerRadius(8)
                    .padding(8)
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                // Deny Button
                AppButton(role: .tertiaryOutline, controlSize: .small, isDisabled: isProcessing, compact: true) {
                    onDeny()
                } label: {
                    if isProcessing {
                        ProgressView()
                            .tint(Color("AccentPrimary"))
                    } else {
                        Label("Deny", systemImage: "xmark")
                    }
                }
                
                // Accept Button
                AppButton(role: .secondary, controlSize: .small, isDisabled: isProcessing, compact: true) {
                    onAccept()
                } label: {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Label("Accept", systemImage: "checkmark")
                    }
                }
            }
        }
        .padding(.bottom, 16)
        
    }
}

// MARK: - Sent Request Card

struct SentRequestCard: View {
    let request: FriendRequest
    let isProcessing: Bool
    
    var body: some View {
        PlayerCard(player: request.user.toPlayer())
            .opacity(isProcessing ? 0.5 : 1.0)
    }
}

// MARK: - Preview

#Preview("Empty State") {
    FriendRequestsView()
        .environmentObject(AuthService.mockAuthenticated)
}

#Preview("With Requests") {
    FriendRequestsViewPreview()
}

// Preview wrapper with mock data
struct FriendRequestsViewPreview: View {
    @StateObject private var authService = AuthService.mockAuthenticated
    
    var body: some View {
        FriendRequestsViewWithMockData()
            .environmentObject(authService)
    }
}

// Mock view with sample data
struct FriendRequestsViewWithMockData: View {
    @State private var receivedRequests: [FriendRequest] = [
        FriendRequest(
            id: UUID(),
            user: User.mockUser2,
            createdAt: Date().addingTimeInterval(-3600 * 2), // 2 hours ago
            type: .received
        ),
        FriendRequest(
            id: UUID(),
            user: User.mockUser3,
            createdAt: Date().addingTimeInterval(-86400), // 1 day ago
            type: .received
        )
    ]
    
    @State private var sentRequests: [FriendRequest] = [
        FriendRequest(
            id: UUID(),
            user: User(
                id: UUID(),
                displayName: "Alex Thompson",
                nickname: "bullseye",
                email: "alex@example.com",
                handle: "@bullseye",
                avatarURL: nil,
                authProvider: .email,
                createdAt: Date().addingTimeInterval(-86400 * 7),
                lastSeenAt: Date().addingTimeInterval(-7200),
                totalWins: 12,
                totalLosses: 9
            ),
            createdAt: Date().addingTimeInterval(-86400 * 3), // 3 days ago
            type: .sent
        )
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Received Requests Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Received Requests")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color("TextPrimary"))
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 12) {
                            ForEach(receivedRequests) { request in
                                ReceivedRequestCard(
                                    request: request,
                                    isProcessing: false,
                                    onAccept: {},
                                    onDeny: {}
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Sent Requests Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sent Requests")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color("TextPrimary"))
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 12) {
                            ForEach(sentRequests) { request in
                                SentRequestCard(
                                    request: request,
                                    isProcessing: false
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 16)
            }
            .background(Color("BackgroundPrimary"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Friend Requests")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color("TextPrimary"))
                }
            }
        }
    }
}
