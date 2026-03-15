//
//  VoicePermissionManager.swift
//  DanDart
//
//  Service for managing microphone permissions and voice chat preferences
//  Phase 12.1: Voice Permission and Settings
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

/// Manages microphone permissions and app-level voice chat preferences
/// Decoupled from VoiceChatService to prevent permission dialogs from interfering with match flow
class VoicePermissionManager: ObservableObject {
    static let shared = VoicePermissionManager()
    
    // MARK: - Published State
    
    /// Current iOS microphone authorization status
    @Published private(set) var microphoneAuthorizationStatus: AVAudioSession.RecordPermission
    
    /// App-level voice chat preference (stored in UserDefaults)
    @Published var isVoiceEnabledInApp: Bool {
        didSet {
            UserDefaults.standard.set(isVoiceEnabledInApp, forKey: UserDefaultsKeys.voiceChatEnabled)
            print("🎤 [VoicePermissionManager] Voice preference changed to: \(isVoiceEnabledInApp)")
        }
    }
    
    /// Whether the initial Remote Games permission prompt has been attempted
    @Published private(set) var hasAttemptedInitialPrompt: Bool {
        didSet {
            UserDefaults.standard.set(hasAttemptedInitialPrompt, forKey: UserDefaultsKeys.initialPromptAttempted)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Whether voice chat is usable (permission granted AND app preference enabled)
    var isVoiceUsable: Bool {
        microphoneAuthorizationStatus == .granted && isVoiceEnabledInApp
    }
    
    // MARK: - UserDefaults Keys
    
    private enum UserDefaultsKeys {
        static let voiceChatEnabled = "voice_chat_enabled"
        static let initialPromptAttempted = "voice_chat_initial_prompt_attempted"
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load preferences from UserDefaults
        self.isVoiceEnabledInApp = UserDefaults.standard.object(forKey: UserDefaultsKeys.voiceChatEnabled) as? Bool ?? true
        self.hasAttemptedInitialPrompt = UserDefaults.standard.bool(forKey: UserDefaultsKeys.initialPromptAttempted)
        
        // Get current permission status
        self.microphoneAuthorizationStatus = AVAudioSession.sharedInstance().recordPermission
        
        print("🎤 [VoicePermissionManager] Initialized")
        print("   - Permission status: \(microphoneAuthorizationStatus)")
        print("   - App preference: \(isVoiceEnabledInApp ? "enabled" : "disabled")")
        print("   - Initial prompt attempted: \(hasAttemptedInitialPrompt)")
        print("   - Voice usable: \(isVoiceUsable)")
        
        // Observe app lifecycle to refresh permission status
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// Refresh the current microphone authorization status
    func refreshPermissionStatus() {
        let newStatus = AVAudioSession.sharedInstance().recordPermission
        if newStatus != microphoneAuthorizationStatus {
            print("🎤 [VoicePermissionManager] Permission status changed: \(microphoneAuthorizationStatus) → \(newStatus)")
            microphoneAuthorizationStatus = newStatus
        }
    }
    
    /// Request microphone permission if needed
    /// Should only be called from stable UI contexts (Remote Games tab, Profile settings)
    /// - Returns: True if permission was granted
    @MainActor
    func requestMicrophonePermissionIfNeeded() async -> Bool {
        // Check current status
        refreshPermissionStatus()
        
        // Only request if not determined
        guard microphoneAuthorizationStatus == .undetermined else {
            print("ℹ️ [VoicePermissionManager] Permission already determined: \(microphoneAuthorizationStatus)")
            return microphoneAuthorizationStatus == .granted
        }
        
        print("🎤 [VoicePermissionManager] Requesting microphone permission...")
        
        // Mark that we've attempted the initial prompt
        hasAttemptedInitialPrompt = true
        
        // Request permission
        let granted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        // Update status
        refreshPermissionStatus()
        
        if granted {
            print("✅ [VoicePermissionManager] Microphone permission granted")
        } else {
            print("❌ [VoicePermissionManager] Microphone permission denied")
        }
        
        return granted
    }
    
    /// Set the app-level voice chat preference
    /// - Parameter enabled: Whether voice chat should be enabled
    func setVoiceEnabled(_ enabled: Bool) {
        isVoiceEnabledInApp = enabled
    }
    
    /// Open iOS Settings app to allow user to change microphone permission
    func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            print("❌ [VoicePermissionManager] Failed to create settings URL")
            return
        }
        
        print("📱 [VoicePermissionManager] Opening iOS Settings...")
        
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    /// Get a human-readable description of the current voice availability
    func getAvailabilityDescription() -> String {
        switch microphoneAuthorizationStatus {
        case .granted:
            return isVoiceEnabledInApp ? "Enabled" : "Off"
        case .denied:
            return "Microphone Access Off"
        case .undetermined:
            return "Not Set Up Yet"
        @unknown default:
            return "Unavailable"
        }
    }
    
    // MARK: - Private Methods
    
    @objc private func appDidBecomeActive() {
        // Refresh permission status when app becomes active
        // (user might have changed it in Settings)
        refreshPermissionStatus()
    }
}
