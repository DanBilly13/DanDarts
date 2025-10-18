//
//  ProfileView.swift
//  DanDart
//
//  User profile view with settings and logout
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var soundManager = SoundManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showLogoutConfirmation: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedAvatarImage: UIImage?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header (Reusable Component)
                    if let currentUser = authService.currentUser {
                        ProfileHeaderView(
                            player: currentUser.toPlayer(),
                            showEditButton: true,
                            selectedPhotoItem: $selectedPhotoItem,
                            selectedAvatarImage: selectedAvatarImage
                        )
                        .padding(.top, 24)
                    }
                    
                    // Settings Section
                    settingsSection
                    
                    // About Section
                    aboutSection
                    
                    // Log Out Button
                    logoutButton
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 16)
            }
            .background(Color("BackgroundPrimary"))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color("AccentPrimary"))
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
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedAvatarImage = uiImage
                        // TODO: Upload to server in future task
                    }
                }
            }
        }
    }
    
    // MARK: - Sub Views
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color("TextPrimary"))
            
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "person.circle",
                    title: "Edit Profile",
                    showChevron: true
                ) {
                    // TODO: Navigate to edit profile
                }
                
                Divider()
                    .background(Color("TextSecondary").opacity(0.2))
                    .padding(.leading, 44)
                
                // Sound Effects Toggle
                SettingsToggleRow(
                    icon: "speaker.wave.2",
                    title: "Sound Effects",
                    isOn: $soundManager.soundEffectsEnabled
                )
                
                Divider()
                    .background(Color("TextSecondary").opacity(0.2))
                    .padding(.leading, 44)
                
                SettingsRow(
                    icon: "bell",
                    title: "Notifications",
                    showChevron: true
                ) {
                    // TODO: Navigate to notifications settings
                }
                
                Divider()
                    .background(Color("TextSecondary").opacity(0.2))
                    .padding(.leading, 44)
                
                SettingsRow(
                    icon: "paintbrush",
                    title: "Appearance",
                    showChevron: true
                ) {
                    // TODO: Navigate to appearance settings
                }
                
                Divider()
                    .background(Color("TextSecondary").opacity(0.2))
                    .padding(.leading, 44)
                
                SettingsRow(
                    icon: "shield",
                    title: "Privacy",
                    showChevron: true
                ) {
                    // TODO: Navigate to privacy settings
                }
                
                Divider()
                    .background(Color("TextSecondary").opacity(0.2))
                    .padding(.leading, 44)
                
                SettingsRow(
                    icon: "questionmark.circle",
                    title: "Help & Support",
                    showChevron: true
                ) {
                    // TODO: Navigate to help
                }
            }
            .background(Color("InputBackground"))
            .cornerRadius(12)
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color("TextPrimary"))
            
            VStack(spacing: 0) {
                // App Version
                HStack(spacing: 16) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color("AccentPrimary"))
                        .frame(width: 28)
                    
                    Text("Version")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextPrimary"))
                    
                    Spacer()
                    
                    Text(appVersion)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color("TextSecondary"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                Divider()
                    .background(Color("TextSecondary").opacity(0.2))
                    .padding(.leading, 44)
                
                // Privacy Policy
                Button(action: {
                    if let url = URL(string: "https://dandarts.app/privacy") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "hand.raised")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color("AccentPrimary"))
                            .frame(width: 28)
                        
                        Text("Privacy Policy")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("TextPrimary"))
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color("TextSecondary"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .background(Color("TextSecondary").opacity(0.2))
                    .padding(.leading, 44)
                
                // Terms of Service
                Button(action: {
                    if let url = URL(string: "https://dandarts.app/terms") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color("AccentPrimary"))
                            .frame(width: 28)
                        
                        Text("Terms of Service")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("TextPrimary"))
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color("TextSecondary"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(Color("InputBackground"))
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
            .background(Color("InputBackground"))
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
                .foregroundColor(Color("AccentPrimary"))
                .frame(width: 28)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color("TextPrimary"))
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color("AccentPrimary"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var showChevron: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color("AccentPrimary"))
                    .frame(width: 28)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("TextPrimary"))
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color("TextSecondary"))
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
        .environmentObject(AuthService())
}
