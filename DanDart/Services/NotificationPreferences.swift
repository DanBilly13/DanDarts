//
//  NotificationPreferences.swift
//  Dart Freak
//
//  What the Notifications toggle means, kept free of networking so it can be tested.
//
//  The server only sends to push_tokens rows with is_active = true, and the toggle shows
//  that flag. Several things used to write it: the user's toggle, every token sync (always
//  true), sign-out (false) and the server (false for a dead token). The sync writing true
//  silently undid the user's "off". The user's choice is now remembered here, on the device,
//  and every sync writes the flag from it.
//

import Foundation
import UserNotifications

/// The user's own "notifications off" choice, per user, stored on this device.
struct NotificationPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(for userId: UUID) -> String {
        "notifications_opted_out_\(userId.uuidString.lowercased())"
    }

    /// True once the user has switched notifications off on this device and not back on.
    func isOptedOut(userId: UUID) -> Bool {
        defaults.bool(forKey: key(for: userId))
    }

    func setOptedOut(_ optedOut: Bool, userId: UUID) {
        defaults.set(optedOut, forKey: key(for: userId))
    }
}

enum NotificationStatePolicy {
    /// What a token sync should write to `is_active`: on, unless the user switched it off.
    static func tokenShouldBeActive(optedOut: Bool) -> Bool {
        !optedOut
    }

    /// What the toggle shows: only "on" if the server will send AND iOS will deliver.
    static func isEnabled(tokenActive: Bool, authorization: UNAuthorizationStatus) -> Bool {
        guard tokenActive else { return false }
        switch authorization {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    /// Notifications are blocked in iOS Settings: the toggle can't fix that, so Settings says so.
    static func needsIOSSettingsHint(authorization: UNAuthorizationStatus) -> Bool {
        authorization == .denied
    }
}
