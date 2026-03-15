//
//  ProfileView.swift
//  Dart Freak
//
//  User profile view with settings and logout
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    private enum ProfileDestination: Hashable {
        case editProfile
        case privacy
        case terms
        case support
    }

    @EnvironmentObject var authService: AuthService
    @StateObject private var soundManager = SoundManager.shared
    @StateObject private var voicePermissionManager = VoicePermissionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirmation: Bool = false
    @State private var showEditProfileV2: Bool = false
    @State private var showClearMatchesConfirmation: Bool = false
    @State private var showResetTipsConfirmation: Bool = false
    @State private var showVoicePermissionAlert = false
    @State private var voiceAlertMessage = ""
    @State private var navigationPath: [ProfileDestination] = []
    @State private var isRefreshingProfile: Bool = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header (Reusable Component)
                    if let currentUser = authService.currentUser {
                        ProfileHeaderView(
                            player: currentUser.toPlayer()
                        ) {
                            HStack(spacing: 12) {
                                // Old Edit Profile (commented out for testing)
//                                AppButton(
//                                    role: .tertiaryOutline,
//                                    controlSize: .regular,
//                                    action: {
//                                        showEditProfile = true
//                                    }
//                                ) {
//                                    Text("Edit Profile")
//                                }

                                AppButton(
                                    role: .primary,
                                    controlSize: .regular,
                                    action: {
                                        navigationPath.append(.editProfile)
                                    }
                                ) {
                                    Text("Edit Profile")
                                }
                                .frame(maxWidth: 180)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.top, 24)
                    }
                    
                    // Settings Section
                    settingsSection
                    
                    #if DEBUG
                    // Developer Section
                    developerSection
                    #endif
                    
                    // About Section
                    aboutSection
                    
                    // Log Out Button
                    logoutButton
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 16)
            }
            .background(AppColor.surfacePrimary)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await refreshProfileIfPossible()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MatchCompleted"))) { _ in
                Task {
                    await refreshProfileIfPossible()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AppColor.textPrimary)
                }
            }
            .navigationDestination(isPresented: $showEditProfileV2) {
                EditProfileV2View()
                    .environmentObject(authService)
                    .background(AppColor.surfacePrimary)
            }
            .navigationDestination(for: ProfileDestination.self) { destination in
                switch destination {
                case .editProfile:
                    EditProfileV2View()
                        .environmentObject(authService)
                        .background(AppColor.surfacePrimary)
                case .privacy:
                    PrivacyPolicy()
                        .background(AppColor.surfacePrimary)
                case .terms:
                    TermsAndConditions()
                        .background(AppColor.surfacePrimary)
                case .support:
                    Support()
                        .background(AppColor.surfacePrimary)
                }
            }
            .alert("Log Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    Task {
                        await authService.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .alert("Clear Local Matches", isPresented: $showClearMatchesConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearLocalMatches()
                }
            } message: {
                Text("This will delete all locally stored match history. Matches synced to the cloud will not be affected.\n\nThis cannot be undone.")
            }
            .alert("Reset All Tips", isPresented: $showResetTipsConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAllTips()
                }
            } message: {
                Text("This will reset all game tips so they appear again on your next game.\n\nThis is a debug feature for testing.")
            }
            .alert("Voice Chat", isPresented: $showVoicePermissionAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    voicePermissionManager.openAppSettings()
                }
            } message: {
                Text(voiceAlertMessage)
            }
        }
    }

    @MainActor
    private func refreshProfileIfPossible() async {
        guard !isRefreshingProfile else { return }
        guard authService.currentUser != nil else { return }
        isRefreshingProfile = true
        defer { isRefreshingProfile = false }

        do {
            try await authService.refreshCurrentUser()
        } catch {
            print("❌ Failed to refresh profile stats: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func clearLocalMatches() {
        MatchStorageManager.shared.deleteAllMatches()
        print("✅ All local matches cleared")
        
        // Haptic feedback
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }
    
    private func resetAllTips() {
        TipManager.shared.resetAllTips()
        print("🔄 All game tips reset")
        
        // Haptic feedback
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }
    
    private func handleVoiceChatTap() {
        switch voicePermissionManager.microphoneAuthorizationStatus {
        case .granted:
            // Toggle is shown, button is disabled - do nothing
            break
            
        case .denied:
            // Show alert explaining permission is denied
            voiceAlertMessage = "Microphone access is turned off for DanDart. Enable it in Settings to use voice chat in remote matches."
            showVoicePermissionAlert = true
            
        case .undetermined:
            // Request permission from this stable context
            Task {
                await voicePermissionManager.requestMicrophonePermissionIfNeeded()
            }
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Sub Views
    
    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Developer")
                .font(.system(.footnote, design: .rounded))
                .fontWeight(.regular)
                .foregroundColor(AppColor.textPrimary)
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "arrow.counterclockwise.circle",
                    title: "Reset All Tips",
                    showChevron: false,
                    destructive: true
                ) {
                    showResetTipsConfirmation = true
                }
                
                Divider()
                    .background(AppColor.textSecondary.opacity(0.2))
                    .padding(.leading, 44)
                
                SettingsRow(
                    icon: "trash",
                    title: "Clear Local Matches",
                    showChevron: false,
                    destructive: true
                ) {
                    showClearMatchesConfirmation = true
                }
            }
            .background(AppColor.inputBackground)
            .cornerRadius(12)
        }
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(.footnote, design: .rounded))
                .fontWeight(.regular)
                .foregroundColor(AppColor.textPrimary)
            
            VStack(spacing: 0) {
                // Sound Effects Toggle
                SettingsToggleRow(
                    icon: "speaker.wave.2",
                    title: "Sound Effects",
                    isOn: $soundManager.soundEffectsEnabled
                )
                
                Divider()
                    .background(AppColor.textSecondary.opacity(0.2))
                    .padding(.leading, 44)
                
                // Voice Chat Setting
                voiceChatSettingRow
                
                Divider()
                    .background(AppColor.textSecondary.opacity(0.2))
                    .padding(.leading, 44)
                
                SettingsRow(
                    icon: "questionmark.circle",
                    title: "Help & Support",
                    showChevron: true
                ) {
                    navigationPath.append(.support)
                }
            }
            .background(AppColor.inputBackground)
            .cornerRadius(12)
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.system(.footnote, design: .rounded))
                .fontWeight(.regular)
                .foregroundColor(AppColor.textPrimary)
            
            VStack(spacing: 0) {
                // App Version
                HStack(spacing: 16) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                        .frame(width: 28)
                    
                    Text("Version")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textPrimary)
                    
                    Spacer()
                    
                    Text(appVersion)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColor.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                Divider()
                    .background(AppColor.textSecondary.opacity(0.2))
                    .padding(.leading, 44)
                
                // Privacy Policy
                Button(action: {
                    navigationPath.append(.privacy)
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "hand.raised")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                            .frame(width: 28)
                        
                        Text("Privacy Policy")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColor.textPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColor.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .background(AppColor.textSecondary.opacity(0.2))
                    .padding(.leading, 44)
                
                // Terms and Conditions
                Button(action: {
                    navigationPath.append(.terms)
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                            .frame(width: 28)
                        
                        Text("Terms and Conditions")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColor.textPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColor.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(AppColor.inputBackground)
            .cornerRadius(12)
        }
    }
    
    private var voiceChatSettingRow: some View {
        HStack(spacing: 16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(voiceChatIconColor)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Voice Chat")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColor.textPrimary)
                
                Text(voiceChatStatusText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppColor.textSecondary)
            }
            
            Spacer()
            
            if shouldShowToggle {
                Toggle("", isOn: $voicePermissionManager.isVoiceEnabledInApp)
                    .labelsHidden()
                    .tint(.green)
            } else {
                Button(action: handleVoiceChatTap) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColor.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    private var voiceChatStatusText: String {
        switch voicePermissionManager.microphoneAuthorizationStatus {
        case .granted:
            return voicePermissionManager.isVoiceEnabledInApp ? "Enabled" : "Off"
        case .denied:
            return "Microphone Access Off"
        case .undetermined:
            return voicePermissionManager.isVoiceEnabledInApp ? "Ready" : "Off"
        @unknown default:
            return "Unavailable"
        }
    }
    
    private var voiceChatIconColor: Color {
        switch voicePermissionManager.microphoneAuthorizationStatus {
        case .granted:
            return voicePermissionManager.isVoiceEnabledInApp 
                ? AppColor.interactivePrimaryBackground 
                : AppColor.textSecondary
        case .denied:
            return .orange
        case .undetermined:
            return AppColor.interactivePrimaryBackground
        @unknown default:
            return AppColor.textSecondary
        }
    }
    
    private var shouldShowToggle: Bool {
        // Show toggle for undetermined (default) and granted states
        // Only show chevron for denied state
        switch voicePermissionManager.microphoneAuthorizationStatus {
        case .granted, .undetermined:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private var logoutButton: some View {
        Button(action: {
            showLogoutConfirmation = true
        }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .medium))
                
                Text("Log Out")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(Color.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppColor.inputBackground)
            .cornerRadius(12)
        }
    }
}

// MARK: - Settings Row Components

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(AppColor.interactivePrimaryBackground)
                .frame(width: 28)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColor.textPrimary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var showChevron: Bool = true
    var destructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(destructive ? .red : AppColor.interactivePrimaryBackground)
                    .frame(width: 28)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(destructive ? .red : AppColor.textPrimary)
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environmentObject({
            let mockAuthService = AuthService()
            mockAuthService.currentUser = User(
                id: UUID(),
                displayName: "Daniel Billingham",
                nickname: "dantheman",
                email: "daniel@example.com",
                handle: "dantheman",
                avatarURL: "avatar1",
                authProvider: .email,
                createdAt: Date(),
                lastSeenAt: Date(),
                totalWins: 63,
                totalLosses: 24
            )
            mockAuthService.isAuthenticated = true
            return mockAuthService
        }())
}
