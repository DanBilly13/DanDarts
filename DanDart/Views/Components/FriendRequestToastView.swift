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
    
    // Animation configuration
    private let transition = ToastTransition()
    
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
                .transition(transition.entry)
                .animation(transition.slideIn, value: toastManager.currentToast?.id)
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

// MARK: - Animated Previews

#Preview("Animated - Default") {
    AnimatedToastPreview(config: .default)
}

#Preview("Animated - Snappy") {
    AnimatedToastPreview(config: .snappy)
}

#Preview("Animated - Smooth") {
    AnimatedToastPreview(config: .smooth)
}

#Preview("Animated - Bouncy") {
    AnimatedToastPreview(config: .bouncy)
}

// MARK: - Preview Helper

struct AnimatedToastPreview: View {
    let config: ToastAnimationConfig
    @State private var showToast = false
    
    private let transition: ToastTransition
    
    init(config: ToastAnimationConfig) {
        self.config = config
        self.transition = ToastTransition(config: config)
    }
    
    var body: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()
            
            VStack {
                // Animation info
                VStack(spacing: 8) {
                    Text("Animation: \(configName)")
                        .font(.headline)
                        .foregroundColor(AppColor.textPrimary)
                    
                    Text("Delay: \(String(format: "%.1f", config.initialDelay))s")
                        .font(.caption)
                        .foregroundColor(AppColor.textSecondary)
                    
                    Text("Slide-in: \(String(format: "%.2f", config.slideInResponse))s response, \(String(format: "%.2f", config.slideInDamping)) damping")
                        .font(.caption)
                        .foregroundColor(AppColor.textSecondary)
                }
                .padding()
                .background(AppColor.inputBackground)
                .cornerRadius(12)
                .padding()
                
                Spacer()
                
                // Control button
                Button {
                    showToast = false
                    // Delay to show animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showToast = true
                    }
                } label: {
                    Text("Show Toast Animation")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppColor.interactivePrimaryBackground)
                        .cornerRadius(12)
                }
                .padding()
            }
            
            // Toast overlay
            VStack {
                if showToast {
                    FriendRequestToastView(
                        toast: FriendRequestToast(
                            type: .requestReceived,
                            user: User.mockUser1,
                            message: "New friend request from \(User.mockUser1.displayName)",
                            friendshipId: UUID()
                        ),
                        onTap: {
                            withAnimation(transition.slideOut) {
                                showToast = false
                            }
                        },
                        onDismiss: {
                            withAnimation(transition.slideOut) {
                                showToast = false
                            }
                        },
                        onAccept: { _ in
                            withAnimation(transition.slideOut) {
                                showToast = false
                            }
                        },
                        onDeny: { _ in
                            withAnimation(transition.slideOut) {
                                showToast = false
                            }
                        },
                        isProcessing: false
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 60)
                    .transition(transition.entry)
                }
                
                Spacer()
            }
            .animation(transition.slideIn, value: showToast)
        }
        .onAppear {
            // Auto-show on appear with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + config.initialDelay) {
                showToast = true
            }
        }
    }
    
    private var configName: String {
        switch config.initialDelay {
        case 0.5: return "Snappy"
        case 0.6: return "Bouncy"
        case 0.8: return "Default"
        case 1.0: return "Smooth"
        default: return "Custom"
        }
    }
}
