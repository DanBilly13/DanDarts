//
//  FriendRequestToastView.swift
//  Dart Freak
//
//  Toast notification view for friend request events
//

import SwiftUI

struct FriendRequestToastView: View {
    let toast: FriendRequestToast
    let onTap: () -> Void
    let onDismiss: () -> Void
    let onAccept: ((UUID) -> Void)?
    let onDeny: ((UUID) -> Void)?
    let isProcessing: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content (avatar, message, dismiss)
            HStack(spacing: 12) {
                // User Avatar with Icon Badge
                ZStack(alignment: .topTrailing) {
                    // Avatar
                    AsyncAvatarImage(
                        avatarURL: toast.user.avatarURL,
                        size: 40,
                        placeholderIcon: "person.fill"
                    )
                    
                    // Icon Badge
                    Image(systemName: toast.type.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(toast.type.iconColor)
                        .background(
                            Circle()
                                .fill(toast.type.iconBackgroundColor)
                                .frame(width: 16, height: 16)
                        )
                        .offset(x: 8, y: -4)
                }
                
                // Message
                Text(toast.message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColor.justBlack)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: 0)
                
                // Dismiss Button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColor.inputBackground)
                        .frame(width: 24, height: 24)
                        .background(AppColor.justWhite)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColor.justWhite)
            .contentShape(Rectangle())
            .onTapGesture {
                // Only navigate if no action buttons present
                if toast.type != .requestReceived || toast.friendshipId == nil {
                    onTap()
                }
            }
            
            // Action Buttons (only for requestReceived with friendshipId)
            if toast.type == .requestReceived, let friendshipId = toast.friendshipId {
                HStack(spacing: 12) {
                    // Deny Button
                    AppButton(role: .secondaryOutline, controlSize: .small, isDisabled: isProcessing, compact: true) {
                        onDeny?(friendshipId)
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .tint(AppColor.interactivePrimaryBackground)
                        } else {
                            Label("Deny", systemImage: "xmark")
                        }
                    }
                    
                    // Accept Button
                    AppButton(role: .primary, controlSize: .small, isDisabled: isProcessing, compact: true) {
                        onAccept?(friendshipId)
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .tint(AppColor.textOnPrimary)
                        } else {
                            Label("Accept", systemImage: "checkmark")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(AppColor.justWhite)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
    }
}

// MARK: - Toast Container with Animation

struct FriendRequestToastContainer: View {
    @ObservedObject var toastManager = FriendRequestToastManager.shared
    let onNavigate: (FriendRequestToast) -> Void
    let onAccept: (UUID) -> Void
    let onDeny: (UUID) -> Void
    
    @State private var isProcessing = false
    
    var body: some View {
        VStack {
            if let toast = toastManager.currentToast {
                FriendRequestToastView(
                    toast: toast,
                    onTap: {
                        onNavigate(toast)
                        toastManager.dismissCurrentToast()
                    },
                    onDismiss: {
                        toastManager.dismissCurrentToast()
                    },
                    onAccept: { friendshipId in
                        isProcessing = true
                        onAccept(friendshipId)
                    },
                    onDeny: { friendshipId in
                        isProcessing = true
                        onDeny(friendshipId)
                    },
                    isProcessing: isProcessing
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toastManager.currentToast?.id)
            }
            
            Spacer()
        }
        .onChange(of: toastManager.currentToast?.id) { _ in
            isProcessing = false
        }
    }
}

// MARK: - Preview

#Preview("Friend Request Received") {
    FriendRequestToastView(
        toast: FriendRequestToast(
            type: .requestReceived,
            user: User.mockUser1,
            message: "New friend request from \(User.mockUser1.displayName)",
            friendshipId: UUID()
        ),
        onTap: {},
        onDismiss: {},
        onAccept: { _ in print("Accept") },
        onDeny: { _ in print("Deny") },
        isProcessing: false
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Request Accepted") {
    FriendRequestToastView(
        toast: FriendRequestToast(
            type: .requestAccepted,
            user: User.mockUser2,
            message: "\(User.mockUser2.displayName) accepted your friend request",
            friendshipId: nil
        ),
        onTap: {},
        onDismiss: {},
        onAccept: nil,
        onDeny: nil,
        isProcessing: false
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Request Denied") {
    FriendRequestToastView(
        toast: FriendRequestToast(
            type: .requestDenied,
            user: User.mockUser3,
            message: "\(User.mockUser3.displayName) declined your friend request",
            friendshipId: nil
        ),
        onTap: {},
        onDismiss: {},
        onAccept: nil,
        onDeny: nil,
        isProcessing: false
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}
