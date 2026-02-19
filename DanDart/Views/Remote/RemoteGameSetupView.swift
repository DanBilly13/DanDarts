//
//  RemoteGameSetupView.swift
//  Dart Freak
//
//  Remote game setup view for creating challenges
//  Shares visual patterns with GameSetupView but adapted for remote matches
//

import SwiftUI

struct RemoteGameSetupView: View {
    let game: Game
    let preselectedOpponent: User?
    
    @State private var selectedOpponent: User?
    @State private var showSearchPlayer: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedMatchFormat: Int = 0 // Best of 1
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var authService: AuthService
    @StateObject private var remoteMatchService = RemoteMatchService()
    @StateObject private var friendsCache = FriendsCache()
    
    private var config: RemoteGameSetupConfig {
        RemoteGameSetupConfig(game: game)
    }
    
    private var canSendChallenge: Bool {
        selectedOpponent != nil && !isCreating
    }
    
    init(game: Game, preselectedOpponent: User? = nil) {
        self.game = game
        self.preselectedOpponent = preselectedOpponent
    }
    
    var body: some View {
        // Layout constants (same as GameSetupView)
        let heroHeight: CGFloat = 280
        let topBarHeight: CGFloat = 58
        let contentSpacing: CGFloat = 32
        
        // Scroll animation values (same as GameSetupView)
        let collapseDistance: CGFloat = 220
        let collapseProgress = min(max(scrollOffset / collapseDistance, 0), 1)
        let topBarProgress = min(max((collapseProgress - 0.7) / 0.3, 0), 1)
        let imageScale = 1.0 + (collapseProgress * 0.08)
        let heroTitleOpacity = max(1.0 - (collapseProgress / 0.6), 0)
        
        ZStack(alignment: .top) {
            // Hero header (same pattern as GameSetupView)
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    ZStack {
                        LinearGradient(
                            colors: [
                                AppColor.interactivePrimaryBackground.opacity(0.6),
                                AppColor.interactivePrimaryBackground.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Image(config.game.coverImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaleEffect(imageScale)
                    }
                    .frame(height: heroHeight)
                    .clipped()
                    
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.3)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: heroHeight)
                    
                    Text(config.game.title)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.leading, 20)
                        .padding(.bottom, 24)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 2)
                        .opacity(heroTitleOpacity)
                }
                .frame(height: heroHeight)
                .frame(maxWidth: .infinity)
                .overlay(
                    Color.black.opacity(collapseProgress)
                )

                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            // Main content with scroll tracking
            TrackingScrollView(offset: $scrollOffset) {
                VStack(spacing: 32) {
                    // Match Format Section
                    VStack(spacing: 16) {
                        HStack {
                            Text(config.optionLabel)
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundColor(AppColor.textPrimary)
                            
                            Spacer()
                        }
                        
                        config.optionView(selection: $selectedMatchFormat)
                    }
                    
                    // Opponent Selection Section
                    VStack(spacing: 16) {
                        HStack {
                            Text("Opponent")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundColor(AppColor.textPrimary)
                            
                            Spacer()
                        }
                        
                        if let opponent = selectedOpponent {
                            // Show selected opponent
                            PlayerCard(
                                player: Player(
                                    displayName: opponent.displayName,
                                    nickname: opponent.nickname,
                                    avatarURL: opponent.avatarURL,
                                    isGuest: false,
                                    totalWins: opponent.totalWins,
                                    totalLosses: opponent.totalLosses,
                                    userId: opponent.id
                                ),
                                playerNumber: 2
                            )
                            .customSwipeAction(
                                title: "Remove",
                                systemImage: "xmark.circle",
                                role: .destructive
                            ) {
                                selectedOpponent = nil
                            }
                        } else {
                            // Choose opponent button
                            Button {
                                showSearchPlayer = true
                            } label: {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 20))
                                    Text("Choose opponent")
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(AppColor.textPrimary)
                                .padding(16)
                                .background(AppColor.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    
                    // Game Instructions
                    GameInstructionsContent(game: config.game)
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, heroHeight - topBarHeight + contentSpacing)
                .padding(.bottom, 100)
            }
            .background(Color.clear)
            
            // Sticky top bar (same pattern as GameSetupView)
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.black.opacity(0.3 * (1 - collapseProgress)))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    
                    Spacer()
                    
                    Text(config.game.title)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundColor(AppColor.textPrimary)
                        .opacity(topBarProgress)
                    
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.trailing, 16 + 28)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(
                    AppColor.backgroundPrimary
                        .opacity(topBarProgress)
                        .ignoresSafeArea(edges: .top)
                )
                
                Spacer()
            }
            
            // Bottom action bar
            VStack {
                Spacer()
                BottomActionContainer {
                    if selectedOpponent == nil {
                        GeometryReader { geo in
                            AppButton(role: .secondary, controlSize: .extraLarge) {
                                showSearchPlayer = true
                            } label: {
                                Label("Choose opponent", systemImage: "person.badge.plus")
                            }
                            .halfWidth(in: geo)
                        }
                        .frame(height: 80)
                    } else {
                        HStack(spacing: 12) {
                            AppButton(role: .secondary, controlSize: .extraLarge) {
                                showSearchPlayer = true
                            } label: {
                                Label("Change opponent", systemImage: "person.2")
                            }

                            AppButton(role: .primary, controlSize: .extraLarge, isDisabled: !canSendChallenge) {
                                sendChallenge()
                            } label: {
                                if isCreating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Send challenge")
                                }
                            }
                        }
                    }
                }
            }
        }
        .background(AppColor.backgroundPrimary.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showSearchPlayer) {
            ChooseOpponentSheet(
                selectedOpponent: $selectedOpponent,
                friendsCache: friendsCache
            )
            .modernSheet(
                title: "Choose Opponent",
                subtitle: "Select a friend to challenge",
                detents: [.large],
                background: AppColor.surfacePrimary
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                showError = false
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            if let preselected = preselectedOpponent {
                selectedOpponent = preselected
            }
        }
    }
    
    // MARK: - Send Challenge
    
    private func sendChallenge() {
        guard let opponent = selectedOpponent,
              let currentUserId = authService.currentUser?.id else {
            return
        }
        
        isCreating = true
        
        Task {
            do {
                let matchFormat = [1, 3, 5, 7][selectedMatchFormat]
                let matchId = try await remoteMatchService.createChallenge(
                    receiverId: opponent.id,
                    gameType: game.title, // "Remote 301" or "Remote 501"
                    matchFormat: matchFormat,
                    currentUserId: currentUserId
                )
                
                // Success haptic
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                
                await MainActor.run {
                    isCreating = false
                    dismiss()
                    // Navigate to Remote tab
                    router.selectedTab = 2 // Remote tab index
                }
                
                print("✅ Challenge created: \(matchId)")
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = "Failed to create challenge: \(error.localizedDescription)"
                    showError = true
                }
                
                // Error haptic
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                #endif
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RemoteGameSetupView(game: Game.remote301)
        .environmentObject(Router())
        .environmentObject(AuthService.shared)
}
