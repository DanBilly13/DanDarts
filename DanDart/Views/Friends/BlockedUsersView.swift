//
//  BlockedUsersView.swift
//  Dart Freak
//
//  View for managing blocked users
//  Task 307: Create Block List Management
//

import SwiftUI

struct BlockedUsersView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @StateObject private var friendsService = FriendsService()
    
    @State private var blockedUsers: [User] = []
    @State private var isLoading: Bool = false
    @State private var loadError: String?
    @State private var unblockingUserId: UUID? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.backgroundPrimary
                    .ignoresSafeArea()
                
                if isLoading && blockedUsers.isEmpty {
                    // Loading State
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(AppColor.interactivePrimaryBackground)
                        
                        Text("Loading...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                    }
                } else if blockedUsers.isEmpty {
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "hand.raised.slash")
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(AppColor.textSecondary)
                        
                        VStack(spacing: 8) {
                            Text("No blocked users")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AppColor.textPrimary)
                            
                            Text("Users you block will appear here")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppColor.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 32)
                } else {
                    // Blocked Users List
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(blockedUsers) { user in
                                BlockedUserCard(
                                    user: user,
                                    isUnblocking: unblockingUserId == user.id,
                                    onUnblock: { unblockUser(user) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Blocked Users")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColor.textPrimary)
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
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                }
            }
            .onAppear {
                loadBlockedUsers()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Load blocked users
    private func loadBlockedUsers() {
        guard let currentUserId = authService.currentUser?.id else {
            return
        }
        
        isLoading = true
        loadError = nil
        
        Task {
            do {
                blockedUsers = try await friendsService.loadBlockedUsers(userId: currentUserId)
                isLoading = false
            } catch {
                print("❌ Load blocked users error: \(error)")
                loadError = "Failed to load blocked users"
                isLoading = false
            }
        }
    }
    
    /// Unblock a user
    private func unblockUser(_ user: User) {
        guard let currentUserId = authService.currentUser?.id else {
            return
        }
        
        unblockingUserId = user.id
        
        Task {
            do {
                // Unblock the user
                try await friendsService.unblockUser(userId: currentUserId, blockedUserId: user.id)
                
                // Light haptic feedback
                let lightFeedback = UIImpactFeedbackGenerator(style: .light)
                lightFeedback.impactOccurred()
                
                // Remove from list
                blockedUsers.removeAll { $0.id == user.id }
                
                // Clear unblocking state
                unblockingUserId = nil
                
            } catch {
                print("❌ Unblock user error: \(error)")
                unblockingUserId = nil
                
                // Error haptic feedback
                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
        }
    }
}

// MARK: - Blocked User Card

struct BlockedUserCard: View {
    let user: User
    let isUnblocking: Bool
    let onUnblock: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Player Card
            PlayerCard(player: user.toPlayer())
            
            // Unblock Button
            Button(action: onUnblock) {
                ZStack {
                    if isUnblocking {
                        ProgressView()
                            .tint(AppColor.textSecondary)
                    } else {
                        Image(systemName: "hand.raised.slash.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColor.textSecondary)
                    }
                }
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(AppColor.textSecondary.opacity(0.15))
                )
            }
            .disabled(isUnblocking)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColor.inputBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview("Empty State") {
    BlockedUsersView()
        .environmentObject(AuthService.mockAuthenticated)
}

#Preview("With Blocked Users") {
    BlockedUsersViewPreview()
}

#Preview("Loading State") {
    BlockedUsersViewLoadingPreview()
}

// Preview wrapper with mock data
struct BlockedUsersViewPreview: View {
    @StateObject private var authService = AuthService.mockAuthenticated
    
    var body: some View {
        BlockedUsersViewWithMockData()
            .environmentObject(authService)
    }
}

// Mock view with blocked users
struct BlockedUsersViewWithMockData: View {
    @State private var blockedUsers: [User] = [
        User.mockUser2,
        User.mockUser3,
        User(
            id: UUID(),
            displayName: "John Smith",
            nickname: "jsmith",
            email: "john@example.com",
            handle: "@jsmith",
            avatarURL: nil,
            authProvider: .email,
            createdAt: Date().addingTimeInterval(-86400 * 45),
            lastSeenAt: Date().addingTimeInterval(-86400 * 2),
            totalWins: 8,
            totalLosses: 15
        )
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(blockedUsers) { user in
                            BlockedUserCard(
                                user: user,
                                isUnblocking: false,
                                onUnblock: {}
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Blocked Users")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColor.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {}) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                }
            }
        }
    }
}

// Preview wrapper for loading state
struct BlockedUsersViewLoadingPreview: View {
    @StateObject private var authService = AuthService.mockAuthenticated
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.backgroundPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(AppColor.interactivePrimaryBackground)
                    
                    Text("Loading...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Blocked Users")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColor.textPrimary)
                }
            }
        }
        .environmentObject(authService)
    }
}
