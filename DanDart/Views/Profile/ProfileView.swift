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
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirmation: Bool = false
    @State private var showEditProfileV2: Bool = false
    @State private var showClearMatchesConfirmation: Bool = false
    @State private var showResetTipsConfirmation: Bool = false
    @State private var navigationPath: [ProfileDestination] = []
    
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
