//
//  FriendRequestToastAnimations.swift
//  Dart Freak
//
//  Animation configurations for friend request toast notifications
//

import SwiftUI

/// Animation configuration for toast notifications
struct ToastAnimationConfig {
    /// Duration of the slide-in animation
    let slideInDuration: Double
    
    /// Duration of the slide-out animation
    let slideOutDuration: Double
    
    /// Spring response for slide-in
    let slideInResponse: Double
    
    /// Spring damping for slide-in
    let slideInDamping: Double
    
    /// Spring response for slide-out
    let slideOutResponse: Double
    
    /// Spring damping for slide-out
    let slideOutDamping: Double
    
    /// Delay before showing toast on app launch/return
    let initialDelay: Double
    
    /// Opacity animation duration
    let opacityDuration: Double
    
    /// Default configuration with smooth, notification-like animations
    static let `default` = ToastAnimationConfig(
        slideInDuration: 0.5,
        slideOutDuration: 0.4,
        slideInResponse: 0.5,
        slideInDamping: 0.75,
        slideOutResponse: 0.4,
        slideOutDamping: 0.8,
        initialDelay: 0.8,
        opacityDuration: 0.3
    )
    
    /// Snappy configuration for faster animations
    static let snappy = ToastAnimationConfig(
        slideInDuration: 0.35,
        slideOutDuration: 0.3,
        slideInResponse: 0.35,
        slideInDamping: 0.7,
        slideOutResponse: 0.3,
        slideOutDamping: 0.75,
        initialDelay: 0.5,
        opacityDuration: 0.2
    )
    
    /// Smooth configuration for slower, more elegant animations
    static let smooth = ToastAnimationConfig(
        slideInDuration: 0.7,
        slideOutDuration: 0.5,
        slideInResponse: 0.6,
        slideInDamping: 0.8,
        slideOutResponse: 0.5,
        slideOutDamping: 0.85,
        initialDelay: 1.0,
        opacityDuration: 0.4
    )
    
    /// Bouncy configuration for playful animations
    static let bouncy = ToastAnimationConfig(
        slideInDuration: 0.6,
        slideOutDuration: 0.4,
        slideInResponse: 0.5,
        slideInDamping: 0.6,
        slideOutResponse: 0.4,
        slideOutDamping: 0.7,
        initialDelay: 0.6,
        opacityDuration: 0.3
    )
}

/// Animation helper for toast transitions
struct ToastTransition {
    let config: ToastAnimationConfig
    
    init(config: ToastAnimationConfig = .default) {
        self.config = config
    }
    
    /// Slide-in animation from top
    var slideIn: Animation {
        .spring(
            response: config.slideInResponse,
            dampingFraction: config.slideInDamping
        )
    }
    
    /// Slide-out animation to top
    var slideOut: Animation {
        .spring(
            response: config.slideOutResponse,
            dampingFraction: config.slideOutDamping
        )
    }
    
    /// Opacity fade animation
    var opacity: Animation {
        .easeInOut(duration: config.opacityDuration)
    }
    
    /// Combined slide and opacity animation for entry
    var entry: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
}
