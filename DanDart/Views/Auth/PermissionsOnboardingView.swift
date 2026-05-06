//
//  PermissionsOnboardingView.swift
//  Dart Freak
//
//  Onboarding step shown to new sign-ups after profile setup.
//  Captures user intent for notifications and voice chat as local toggles, then
//  triggers iOS permission dialogs sequentially when the user taps Done.
//

import SwiftUI

struct PermissionsOnboardingView: View {
    @EnvironmentObject private var authService: AuthService
    
    // Local intent toggles - default ON. These do NOT trigger iOS dialogs on change.
    // Permission requests are only fired sequentially when the user taps Done.
    @State private var notificationsIntent: Bool = true
    @State private var voiceIntent: Bool = true
    @State private var isCompleting: Bool = false
    
    var body: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer()
                            .frame(height: 100)
                        // Header
                        VStack(spacing: 16) {
                            Image("DartHeadOnly")
                                .resizable()
                                .scaledToFit()
                                .frame( height: 120)
                            VStack(spacing: 8) {
                            Text("Connect with the crew")
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(AppColor.textPrimary)
                                .multilineTextAlignment(.center)
                            
                           
                                Text("Choose your alerts. You can always edit these in Settings later")
                                    .font(.system(.callout, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColor.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)

                                    
                            }
                            .padding(.horizontal, 24)
                            
                        }
                        
                        // Toggle Rows
                        VStack(spacing: 0) {
                            permissionRow(
                                icon: "bell.fill",
                                title: "Notifications",
                                subtitle: "Get alerted for friend requests and incoming remote challenges.",
                                isOn: $notificationsIntent
                            )
                            
                            Divider()
                                .background(AppColor.textSecondary.opacity(0.2))
                                .padding(.leading, 60)
                            
                            permissionRow(
                                icon: "mic.fill",
                                title: "Voice Chat",
                                subtitle: "Live audio during remote matches.",
                                isOn: $voiceIntent
                            )
                        }
                        
                        
                        Spacer(minLength: 16)
                    }
                    .padding(.bottom, 16)
                }
                
                // Done Button
                AppButton(role: .primary,
                          controlSize: .regular,
                          isDisabled: isCompleting,
                          action: {
                              Task { await handleDone() }
                          }) {
                    HStack {
                        if isCompleting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColor.textOnPrimary))
                                .scaleEffect(0.8)
                        }
                        Text(isCompleting ? "Setting up..." : "Done")
                    }
                }
                .opacity(isCompleting ? 0.6 : 1.0)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Row
    
    private func permissionRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(AppColor.interactivePrimaryBackground)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColor.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.green)
                .disabled(isCompleting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    // MARK: - Actions
    
    private func handleDone() async {
        isCompleting = true
        defer { isCompleting = false }
        
        print("🆕 [PermissionsOnboarding] Done tapped - notifications:\(notificationsIntent) voice:\(voiceIntent)")
        
        // 1. Notifications: only request if user left toggle on
        if notificationsIntent {
            do {
                try await NotificationService.shared.setNotificationsEnabled(true)
                print("✅ [PermissionsOnboarding] Notifications enabled")
            } catch NotificationService.NotificationError.permissionDenied {
                print("ℹ️ [PermissionsOnboarding] Notifications permission denied by user")
            } catch {
                print("❌ [PermissionsOnboarding] Notifications request failed: \(error)")
            }
        } else {
            print("⏭️ [PermissionsOnboarding] Notifications skipped (toggle off)")
        }
        
        // 2. Voice chat: only request if user left toggle on
        if voiceIntent {
            let granted = await VoicePermissionManager.shared.requestMicrophonePermissionIfNeeded()
            VoicePermissionManager.shared.setVoiceEnabled(true)
            VoicePermissionManager.shared.logState("permissions onboarding voice enabled granted=\(granted)")
            print("\(granted ? "✅" : "ℹ️") [PermissionsOnboarding] Voice request finished granted:\(granted)")
        } else {
            VoicePermissionManager.shared.setVoiceEnabled(false)
            VoicePermissionManager.shared.logState("permissions onboarding voice skipped")
            print("⏭️ [PermissionsOnboarding] Voice skipped (toggle off) - app preference set to off")
        }
        
        // 3. Mark onboarding complete and proceed to MainTabView
        authService.completePermissionsOnboarding()
    }
}

// MARK: - Preview

#Preview {
    PermissionsOnboardingView()
        .environmentObject(AuthService())
}
