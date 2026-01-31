//
//  MainTabView.swift
//  Dart Freak
//
//  Main tab navigation structure for authenticated users
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var friendsService = FriendsService()
    @State private var showProfile: Bool = false
    @State private var pendingRequestCount: Int = 0

    private struct InviteTokenToClaim: Identifiable {
        let id: String
        let token: String
    }

    @State private var inviteTokenToClaim: InviteTokenToClaim? = nil
    
    var body: some View {
        TabView {
            // Games Tab
            GamesTabView(showProfile: $showProfile)
                .tabItem {
                    Image(systemName: "target")
                        .font(.system(size: 17, weight: .semibold))
                    //Text("Games")
                }
                .tag(0)
            
            // Friends Tab
            Group {
                if pendingRequestCount > 0 {
                    FriendsTabView(showProfile: $showProfile)
                        .tabItem {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 22, weight: .semibold))
                            //Text("Friends")
                        }
                        .badge(pendingRequestCount)
                        .tag(1)
                } else {
                    FriendsTabView(showProfile: $showProfile)
                        .tabItem {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 22, weight: .semibold))
                            //Text("Friends")
                        }
                        .tag(1)
                }
            }
            
            // History Tab
            HistoryTabView(showProfile: $showProfile)
                .tabItem {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .fontWeight(.bold)
                    //Text("History")
                }
                .tag(2)
        }
        .background(AppColor.backgroundPrimary)
        .accentColor(AppColor.interactivePrimaryBackground)
        .sheet(item: $inviteTokenToClaim, onDismiss: {
            PendingInviteStore.shared.clearToken()
        }) { token in
            InviteClaimView(token: token.token)
                .modernSheet(title: "Invite", detents: [.medium], background: AppColor.surfacePrimary)
        }
        .fullScreenCover(isPresented: $showProfile) {
            ProfileView()
                .environmentObject(authService)
        }
        .onAppear {
            configureTabBarAppearance()
            loadPendingRequestCount()

            if inviteTokenToClaim == nil, let token = PendingInviteStore.shared.getToken() {
                inviteTokenToClaim = InviteTokenToClaim(id: token, token: token)
            }
            
            // Listen for friend request changes
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("FriendRequestsChanged"),
                object: nil,
                queue: .main
            ) { _ in
                loadPendingRequestCount()
            }

            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("InviteLinkReceived"),
                object: nil,
                queue: .main
            ) { _ in
                if let token = PendingInviteStore.shared.getToken() {
                    inviteTokenToClaim = InviteTokenToClaim(id: token, token: token)
                }
            }
        }
        .onChange(of: authService.currentUser?.id) { _, _ in
            loadPendingRequestCount()

            if inviteTokenToClaim == nil, let token = PendingInviteStore.shared.getToken() {
                inviteTokenToClaim = InviteTokenToClaim(id: token, token: token)
            }
        }
    }
    
    private func loadPendingRequestCount() {
        guard let currentUser = authService.currentUser else {
            pendingRequestCount = 0
            return
        }
        
        Task {
            do {
                let count = try await friendsService.getPendingRequestCount(userId: currentUser.id)
                await MainActor.run {
                    pendingRequestCount = count
                }
            } catch {
                print("❌ Failed to load pending request count: \(error)")
                await MainActor.run {
                    pendingRequestCount = 0
                }
            }
        }
    }
    
    private func configureTabBarAppearance() {
        // Configure tab bar for dark mode
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppColor.backgroundPrimary)
        
        // Normal state
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColor.textSecondary)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColor.textSecondary)
        ]
        
        // Selected state
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColor.interactivePrimaryBackground)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppColor.interactivePrimaryBackground)
        ]
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

// MARK: - Tab Views

struct GamesTabView: View {
    let games = Game.loadGames()
    @StateObject private var router = Router.shared
    @EnvironmentObject private var authService: AuthService
    @Binding var showProfile: Bool
    @Namespace private var gameHeroNamespace
    
    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack {
                AppColor.backgroundPrimary
                    .padding(-60)
                    .ignoresSafeArea()

                // Games List Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(games) { game in
                            GameCard(game: game) {
                                router.push(.gameSetup(game: game))
                            }
                            .modifier(GameHeroSourceModifier(game: game, namespace: gameHeroNamespace))
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColor.backgroundPrimary)
            }
            .navigationTitle("Games")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ToolbarTitle(title: "Games")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ToolbarAvatarButton(avatarURL: authService.currentUser?.avatarURL) {
                        showProfile = true
                    }
                }
            }
            .customNavBar(title: "Games")
            .navigationDestination(for: Route.self) { route in
                switch route.destination {
                case .gameSetup(let game):
                    let view = GameSetupView(game: game)
                    if #available(iOS 18.0, *) {
                        view
                            .navigationTransition(
                                .zoom(sourceID: game.id, in: gameHeroNamespace)
                            )
                            .background(AppColor.backgroundPrimary)
                    } else {
                        view
                            .background(AppColor.backgroundPrimary)
                    }
                default:
                    router.view(for: route)
                        .background(AppColor.backgroundPrimary)
                }
            }
        }
        .background(
            AppColor.backgroundPrimary
                .padding(-60)
                .ignoresSafeArea()
        )
        .environmentObject(router)
    }
}

// MARK: - Hero Animation Modifier (iOS 18+)

private struct GameHeroSourceModifier: ViewModifier {
    let game: Game
    let namespace: Namespace.ID
    
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .matchedTransitionSource(id: game.id, in: namespace)
        } else {
            content
        }
    }
}

struct FriendsTabView: View {
    @Binding var showProfile: Bool
    
    var body: some View {
        FriendsListView()
    }
}

struct HistoryTabView: View {
    @Binding var showProfile: Bool
    
    var body: some View {
        MatchHistoryView()
    }
}

// MARK: - Preview
#Preview {
    MainTabView()
        .environmentObject(AuthService())
}

#Preview("Main Tab - Dark") {
    MainTabView()
        .environmentObject(AuthService())
        .preferredColorScheme(.dark)
}
