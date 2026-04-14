//
//  NotificationService.swift
//  DanDart
//
//  Push notification management service for APNs
//  Phase 8: Push Notifications
//

import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class NotificationService: NSObject, ObservableObject {
    // MARK: - Singleton
    static let shared = NotificationService()
    
    // MARK: - Published Properties
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var pendingIntent: NotificationRouteIntent?
    @Published var notificationsEnabled: Bool = false
    
    // MARK: - Private Properties
    private let supabaseService = SupabaseService.shared
    private let authService = AuthService.shared
    private let userDefaults = UserDefaults.standard
    
    private let deviceInstallIdKey = "device_install_id"
    private let storedTokenKey = "apns_device_token"
    
    private var isTogglingNotifications = false
    
    // Store the last received token for retry attempts
    private var lastReceivedToken: String? {
        get { userDefaults.string(forKey: storedTokenKey) }
        set { userDefaults.set(newValue, forKey: storedTokenKey) }
    }
    
    // MARK: - Initialization
    private override init() {
        super.init()
        Task {
            await checkAuthorizationStatus()
            await loadNotificationState()
        }
    }
    
    // MARK: - Device Install ID
    
    /// Get or create device install ID (install-scoped, stored in UserDefaults)
    func getOrCreateDeviceInstallId() -> String {
        if let existing = userDefaults.string(forKey: deviceInstallIdKey) {
            return existing
        }
        let newId = UUID().uuidString
        userDefaults.set(newId, forKey: deviceInstallIdKey)
        return newId
    }
    
    /// Get device install ID if it exists (returns nil if not yet created)
    func getDeviceInstallId() -> String? {
        return userDefaults.string(forKey: deviceInstallIdKey)
    }
    
    // MARK: - APNs Environment Detection
    
    /// Detect APNs environment based on build configuration
    func getAPNsEnvironment() -> String {
        #if DEBUG
        return "sandbox"
        #else
        // TestFlight and App Store both use production
        return "production"
        #endif
    }
    
    // MARK: - Permission Management
    
    /// Request notification permissions from user
    func requestPermissions() async throws {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            
            if granted {
                print("✅ Notification permissions granted")
                await checkAuthorizationStatus()
                
                // Register for remote notifications on main thread
                #if canImport(UIKit)
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                #endif
            } else {
                print("❌ Notification permissions denied")
                await checkAuthorizationStatus()
            }
        } catch {
            print("❌ Failed to request notification permissions: \(error)")
            throw error
        }
    }
    
    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        authorizationStatus = settings.authorizationStatus
        
        switch settings.authorizationStatus {
        case .notDetermined:
            print("📱 Notification status: Not Determined")
        case .denied:
            print("❌ Notification status: Denied")
        case .authorized:
            print("✅ Notification status: Authorized")
        case .provisional:
            print("⚠️ Notification status: Provisional")
        case .ephemeral:
            print("⏱️ Notification status: Ephemeral")
        @unknown default:
            print("❓ Notification status: Unknown")
        }
    }
    
    // MARK: - Token Management
    
    /// Register for remote notifications and sync token to server
    func registerForRemoteNotifications() async throws {
        // This is called automatically by requestPermissions() when granted
        // The actual token will be delivered via AppDelegate methods
        print("📱 NotificationService.registerForRemoteNotifications() - waiting for token from system")
    }
    
    /// Sync push token to Supabase
    func syncPushToken(_ token: String) async throws {
        guard let userId = authService.currentUser?.id else {
            print("❌ Cannot sync push token - no authenticated user")
            throw NSError(domain: "NotificationService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        let deviceInstallId = getOrCreateDeviceInstallId()
        let environment = getAPNsEnvironment()
        
        print("📤 Syncing push token to Supabase...")
        print("   User ID: \(userId)")
        print("   Device Install ID: \(deviceInstallId)")
        print("   Environment: \(environment)")
        print("   Token: \(token.prefix(20))...")
        
        // Prepare token record as Codable struct
        struct PushTokenRecord: Codable {
            let user_id: String
            let device_install_id: String
            let platform: String
            let provider: String
            let environment: String
            let push_token: String
            let is_active: Bool
        }
        
        let tokenRecord = PushTokenRecord(
            user_id: userId.uuidString,
            device_install_id: deviceInstallId,
            platform: "ios",
            provider: "apns",
            environment: environment,
            push_token: token,
            is_active: true
        )
        
        do {
            // Upsert token record (insert or update if exists)
            // Specify onConflict to handle unique constraint on (user_id, device_install_id)
            try await supabaseService.client
                .from("push_tokens")
                .upsert(tokenRecord, onConflict: "user_id,device_install_id")
                .execute()
            
            // Store token locally for retry attempts
            lastReceivedToken = token
            
            print("✅ Push token synced successfully")
        } catch {
            print("❌ Failed to sync push token: \(error)")
            
            // Store token locally even on failure for retry
            lastReceivedToken = token
            
            throw error
        }
    }
    
    /// Deactivate current device token (called on logout)
    func deactivateCurrentDeviceToken() async {
        guard let userId = authService.currentUser?.id else {
            print("⚠️ Cannot deactivate token - no authenticated user")
            return
        }
        
        let deviceInstallId = getOrCreateDeviceInstallId()
        
        print("🔒 Deactivating push token for logout...")
        print("   User ID: \(userId)")
        print("   Device Install ID: \(deviceInstallId)")
        
        do {
            // Set is_active = false for this user/device combination
            try await supabaseService.client
                .from("push_tokens")
                .update(["is_active": false])
                .eq("user_id", value: userId.uuidString)
                .eq("device_install_id", value: deviceInstallId)
                .execute()
            
            print("✅ Push token deactivated successfully")
        } catch {
            print("❌ Failed to deactivate push token: \(error)")
            // Don't throw - logout should succeed even if token deactivation fails
        }
    }
    
    /// Activate current device token (opposite of deactivate)
    func activateCurrentDeviceToken() async {
        guard let userId = authService.currentUser?.id else {
            print("⚠️ Cannot activate token - no authenticated user")
            return
        }
        
        let deviceInstallId = getOrCreateDeviceInstallId()
        
        print("🔓 Activating push token...")
        print("   User ID: \(userId)")
        print("   Device Install ID: \(deviceInstallId)")
        
        do {
            // Set is_active = true for this user/device combination
            try await supabaseService.client
                .from("push_tokens")
                .update(["is_active": true])
                .eq("user_id", value: userId.uuidString)
                .eq("device_install_id", value: deviceInstallId)
                .execute()
            
            print("✅ Push token activated successfully")
        } catch {
            print("❌ Failed to activate push token: \(error)")
        }
    }
    
    /// Load current notification state from database
    func loadNotificationState() async {
        print("📥 [Load] loadNotificationState() called")
        
        // Guard: Don't reload state while a manual toggle is in progress
        guard !isTogglingNotifications else {
            print("⏭️ [Load] Skipping loadNotificationState - toggle operation in progress")
            return
        }
        
        guard let userId = authService.currentUser?.id else {
            print("⏭️ [Load] No authenticated user - notifications disabled")
            notificationsEnabled = false
            return
        }
        
        let deviceInstallId = getOrCreateDeviceInstallId()
        
        print("📥 [Load] Loading notification state from database...")
        print("   User ID: \(userId)")
        print("   Device Install ID: \(deviceInstallId)")
        
        do {
            struct PushTokenResponse: Decodable {
                let is_active: Bool
            }
            
            let response: [PushTokenResponse] = try await supabaseService.client
                .from("push_tokens")
                .select("is_active")
                .eq("user_id", value: userId.uuidString)
                .eq("device_install_id", value: deviceInstallId)
                .execute()
                .value
            
            if let tokenState = response.first {
                print("📊 [Load] Database returned is_active=\(tokenState.is_active)")
                notificationsEnabled = tokenState.is_active
                print("✅ [Load] notificationsEnabled set to \(notificationsEnabled)")
            } else {
                // No token record yet - default to false
                print("ℹ️ [Load] No token record found - defaulting to disabled")
                notificationsEnabled = false
                print("✅ [Load] notificationsEnabled set to false")
            }
        } catch {
            print("❌ Failed to load notification state: \(error)")
            notificationsEnabled = false
        }
    }
    
    /// Toggle notifications on/off (called from Settings UI)
    func setNotificationsEnabled(_ enabled: Bool) async throws {
        guard !isTogglingNotifications else {
            print("⏭️ Already toggling notifications - skipping")
            return
        }
        
        isTogglingNotifications = true
        defer { isTogglingNotifications = false }
        
        print("🔔 [Toggle] setNotificationsEnabled(\(enabled)) called")
        print("🔔 [Toggle] Setting notifications to: \(enabled ? "enabled" : "disabled")")
        
        if enabled {
            // Turning ON
            await checkAuthorizationStatus()
            
            switch authorizationStatus {
            case .authorized:
                // Permission already granted - activate token
                print("✅ Permission already granted - activating token")
                
                // Ensure token is synced
                if let token = lastReceivedToken {
                    try await syncPushToken(token)
                } else {
                    // Request token registration
                    #if canImport(UIKit)
                    await MainActor.run {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    #endif
                }
                
                print("📤 [Toggle] About to activate token in database (is_active=true)")
                await activateCurrentDeviceToken()
                print("✅ [Toggle] Database updated successfully (is_active=true)")
                notificationsEnabled = true
                print("✅ [Toggle] notificationsEnabled set to true")
                
            case .notDetermined:
                // Need to request permission
                print("❓ Permission not determined - requesting")
                try await requestPermissions()
                
                // Check result
                await checkAuthorizationStatus()
                if authorizationStatus == .authorized {
                    await activateCurrentDeviceToken()
                    notificationsEnabled = true
                } else {
                    notificationsEnabled = false
                    throw NotificationError.permissionDenied
                }
                
            case .denied:
                // Permission denied - cannot enable
                print("❌ Permission denied - cannot enable notifications")
                notificationsEnabled = false
                throw NotificationError.permissionDenied
                
            case .provisional, .ephemeral:
                // Treat as authorized
                await activateCurrentDeviceToken()
                notificationsEnabled = true
                
            @unknown default:
                notificationsEnabled = false
                throw NotificationError.unknownStatus
            }
        } else {
            // Turning OFF
            print("📤 [Toggle] About to deactivate token in database (is_active=false)")
            await deactivateCurrentDeviceToken()
            print("✅ [Toggle] Database updated successfully (is_active=false)")
            notificationsEnabled = false
            print("✅ [Toggle] notificationsEnabled set to false")
        }
    }
    
    /// Open iOS Settings app
    func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            print("❌ Failed to create settings URL")
            return
        }
        
        print("📱 Opening iOS Settings...")
        
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    /// Retry syncing stored token (called on app launch or auth state change)
    func retryTokenSyncIfNeeded() async {
        // Only retry if we have a stored token and an authenticated user
        guard let token = lastReceivedToken,
              authService.currentUser != nil else {
            print("⏭️ No token to retry or no authenticated user")
            return
        }
        
        print("🔄 Retrying token sync...")
        
        do {
            try await syncPushToken(token)
        } catch {
            print("❌ Token retry failed: \(error)")
            // Will retry again on next app launch
        }
    }
    
    // MARK: - Deep Link Handling
    
    /// Handle notification tap and create route intent
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let intent = NotificationPayloadParser.parseIntent(from: userInfo) else {
            print("⚠️ Notification tap received but payload could not be parsed")
            return
        }

        // Foreground policy (Phase 8): if app is already active, do not force navigation.
        #if canImport(UIKit)
        guard UIApplication.shared.applicationState != .active else {
            let idString = intent.matchId.map { String($0.uuidString.prefix(8)) } ?? "none"
            print("⏭️ Notification tap ignored (app active) matchId=\(idString)...")
            return
        }
        #endif

        let idString = intent.matchId.map { String($0.uuidString.prefix(8)) } ?? "none"
        print("📍 Enqueue notification intent matchId=\(idString)... highlight=\(intent.highlightStyle)")
        pendingIntent = intent
    }
    
    /// Clear consumed intent
    func clearIntent() {
        pendingIntent = nil
    }
    
    // MARK: - Error Types
    
    enum NotificationError: LocalizedError {
        case permissionDenied
        case unknownStatus
        case noAuthenticatedUser
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Notification permission denied"
            case .unknownStatus:
                return "Unknown notification status"
            case .noAuthenticatedUser:
                return "No authenticated user"
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Suppress foreground banners per Phase 8 contract
        // Rely on existing in-app Remote tab badge/UI
        completionHandler([])
    }
    
    /// Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        Task { @MainActor in
            NotificationService.shared.handleNotificationTap(userInfo: userInfo)
        }
        
        completionHandler()
    }
}

// MARK: - Notification Route Intent Model

/// Intent object for deep-linking from push notifications
struct NotificationRouteIntent: Equatable {
    let matchId: UUID?  // Optional - nil for friend requests (V1)
    let destination: Destination
    let highlightStyle: HighlightStyle
    var isConsumed: Bool = false
    
    enum Destination: Equatable {
        case remoteTab
        case friendsTab
    }
    
    enum HighlightStyle: Equatable {
        case incoming  // Scroll to pending challenges section
        case ready     // Scroll to ready matches section
        case friendRequest  // Friend request notification
    }
}
