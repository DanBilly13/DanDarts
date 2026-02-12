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
    
    private var dismissTask: Task<Void, Never>?
    
    private init() {}
    
    /// Show a toast notification
    func showToast(_ toast: FriendRequestToast) {
        // If there's already a toast showing, queue this one
        if currentToast != nil {
            toastQueue.append(toast)
            return
        }
        
        // Show the toast
        currentToast = toast
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Auto-dismiss after 3.5 seconds
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000) // 3.5 seconds
            await dismissCurrentToast()
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
