//
//  ProfileView.swift
//  Dart Freak
//
//  User profile view with stats and edit profile
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    private enum ProfileDestination: Hashable {
        case editProfile
        case settings
    }

    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var navigationPath = NavigationPath()
    @State private var isRefreshingProfile: Bool = false
    @StateObject private var statsService = ProfileStatsService.shared
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    if let currentUser = authService.currentUser {
                        ProfileHeaderView(
                            player: currentUser.toPlayer()
                        ) {
                            HStack(spacing: 12) {
                                AppButton(
                                    role: .primary,
                                    controlSize: .regular,
                                    action: {
                                        navigationPath.append(ProfileDestination.editProfile)
                                    }
                                ) {
                                    Text("Edit Profile")
                                }
                                .frame(maxWidth: 180)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                        
                        VStack(spacing: 48) {
                            ThreeDartAverageTrendChart(
                                dataPoints: statsService.threeDartAverageHistory
                            )
                            
                            DartsThrownPerLegBar(
                                avgDarts: statsService.avgDartsPerLeg,
                                rank: statsService.avgDartsRank,
                                gameType: "301"
                            )
                            
                            ScoringDistributionChart(
                                distribution: statsService.scoringDistribution
                            )
                            
                            PersonalBestBars(
                                highestVisit: statsService.highestVisit,
                                bestCheckout: statsService.bestCheckout,
                                checkoutPercentage: statsService.checkoutPercentage
                            )
                            
                            RecentFormTracker(
                                formResults: statsService.recentForm
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .background(AppColor.surfacePrimary)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await refreshProfileIfPossible()
                if let userId = authService.currentUser?.id {
                    await statsService.calculateStats(userId: userId)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MatchCompleted"))) { _ in
                Task {
                    await refreshProfileIfPossible()
                    if let userId = authService.currentUser?.id {
                        await statsService.calculateStats(userId: userId)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColor.justWhite)
                    }
                    .buttonStyle(.plain)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        navigationPath.append(ProfileDestination.settings)
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColor.justWhite)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationDestination(for: ProfileDestination.self) { destination in
                switch destination {
                case .editProfile:
                    EditProfileV2View()
                        .environmentObject(authService)
                        .background(AppColor.surfacePrimary)
                case .settings:
                    SettingsView()
                        .environmentObject(authService)
                        .background(AppColor.surfacePrimary)
                }
            }
            .navigationDestination(for: SettingsDestination.self) { destination in
                switch destination {
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
}

// MARK: - Settings Row Components

struct SettingsToggleRow: View {
    let icon: Image
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            icon
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
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
    let icon: Image
    let title: String
    var showChevron: Bool = true
    var destructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                icon
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
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
