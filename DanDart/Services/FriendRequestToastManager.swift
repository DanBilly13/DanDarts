//
//  FriendRequestToastManager.swift
//  Dart Freak
//
//  Manages toast notifications for friend request events
//

import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#endif

@MainActor
class FriendRequestToastManager: ObservableObject {
    static let shared = FriendRequestToastManager()
    
    @Published var currentToast: FriendRequestToast?
    @Published var toastQueue: [FriendRequestToast] = []
    
    /// Animation configuration for toast transitions
    let animationConfig: ToastAnimationConfig
    
    private var dismissTask: Task<Void, Never>?
    
    private init(animationConfig: ToastAnimationConfig = .bouncy) {
        self.animationConfig = animationConfig
    }
    
    /// Show a toast notification with optional delay
    /// - Parameters:
    ///   - toast: The toast to show
    ///   - delay: Optional delay in seconds before showing (useful for app launch/return)
    func showToast(_ toast: FriendRequestToast, delay: Double? = nil) {
        print("🎯 [ToastManager] showToast called")
        print("🎯 [ToastManager] Toast type: \(toast.type)")
        print("🎯 [ToastManager] User: \(toast.user.displayName)")
        print("🎯 [ToastManager] Delay: \(delay ?? 0)s")
        print("🎯 [ToastManager] Current toast: \(currentToast != nil ? "exists" : "nil")")
        
        // If there's already a toast showing, queue this one
        if currentToast != nil {
            print("🎯 [ToastManager] Queuing toast (current toast exists)")
            toastQueue.append(toast)
            return
        }
        
        // Apply delay if specified
        let delaySeconds = delay ?? 0
        
        Task {
            if delaySeconds > 0 {
                print("🎯 [ToastManager] Waiting \(delaySeconds)s before showing toast")
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
            
            print("🎯 [ToastManager] Setting currentToast")
            currentToast = toast
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Only auto-dismiss for non-interactive toasts
            // requestReceived has Accept/Deny buttons, so user must manually dismiss
            if toast.type != .requestReceived {
                print("🎯 [ToastManager] Toast displayed, auto-dismiss in 3.5s")
                dismissTask?.cancel()
                dismissTask = Task {
                    try? await Task.sleep(nanoseconds: 3_500_000_000) // 3.5 seconds
                    await dismissCurrentToast()
                }
            } else {
                print("🎯 [ToastManager] Toast displayed, NO auto-dismiss (interactive toast with buttons)")
                dismissTask?.cancel() // Cancel any existing dismiss task
            }
        }
    }
    
    /// Dismiss the current toast
    func dismissCurrentToast() {
        dismissTask?.cancel()
        currentToast = nil
        
        // Show next toast in queue if any
        if !toastQueue.isEmpty {
            let nextToast = toastQueue.removeFirst()
            // Small delay before showing next toast
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                showToast(nextToast)
            }
        }
    }
    
    /// Clear all toasts
    func clearAll() {
        dismissTask?.cancel()
        currentToast = nil
        toastQueue.removeAll()
    }
}

// MARK: - Toast Model

struct FriendRequestToast: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let user: User
    let message: String
    let friendshipId: UUID?  // For accept/deny actions on received requests
    
    enum ToastType: Equatable {
        case requestReceived
        case requestAccepted
        case requestDenied
        
        var iconName: String {
            switch self {
            case .requestReceived:
                return "plus.circle.fill"
            case .requestAccepted:
                return "checkmark.circle.fill"
            case .requestDenied:
                return "x.circle.fill"
            }
        }
        
        var iconColor: Color {
            switch self {
            case .requestReceived:
                return AppColor.interactivePrimaryBackground
            case .requestAccepted:
                return .green
            case .requestDenied:
                return AppColor.interactivePrimaryBackground
            }
        }
        
        var iconBackgroundColor: Color {
            switch self {
            case .requestReceived:
                return AppColor.justWhite
            case .requestAccepted:
                return AppColor.justBlack
            case .requestDenied:
                return AppColor.justWhite
            }
        }
        
        
    }
    
    static func == (lhs: FriendRequestToast, rhs: FriendRequestToast) -> Bool {
        lhs.id == rhs.id
    }
}
