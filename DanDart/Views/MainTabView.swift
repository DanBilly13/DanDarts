//
//  MainTabView.swift
//  DanDart
//
//  Main tab navigation structure for authenticated users
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var friendsService = FriendsService()
    @State private var showProfile: Bool = false
    @State private var pendingRequestCount: Int = 0
    
    var body: some View {
        TabView {
            // Games Tab
            GamesTabView(showProfile: $showProfile)
                .tabItem {
                    Image(systemName: "target")
                    Text("Games")
                }
                .tag(0)
            
            // Friends Tab
            Group {
                if pendingRequestCount > 0 {
                    FriendsTabView(showProfile: $showProfile)
                        .tabItem {
                            Image(systemName: "person.2.fill")
                            Text("Friends")
                        }
                        .badge(pendingRequestCount)
                        .tag(1)
                } else {
                    FriendsTabView(showProfile: $showProfile)
                        .tabItem {
                            Image(systemName: "person.2.fill")
                            Text("Friends")
                        }
                        .tag(1)
                }
            }
            
            // History Tab
            HistoryTabView(showProfile: $showProfile)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("History")
                }
                .tag(2)
        }
        .accentColor(Color("AccentPrimary"))
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .environmentObject(authService)
        }
        .onAppear {
            configureTabBarAppearance()
            loadPendingRequestCount()
            
            // Listen for friend request changes
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("FriendRequestsChanged"),
                object: nil,
                queue: .main
            ) { _ in
                loadPendingRequestCount()
            }
        }
        .onChange(of: authService.currentUser?.id) { _, _ in
            loadPendingRequestCount()
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
        tabBarAppearance.backgroundColor = UIColor(Color("BackgroundPrimary"))
        
        // Normal state
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color("TextSecondary"))
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color("TextSecondary"))
        ]
        
        // Selected state
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color("AccentPrimary"))
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color("AccentPrimary"))
        ]
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

// MARK: - Tab Views

struct GamesTabView: View {
    let games = Game.loadGames()
    @StateObject private var router = Router.shared
    @Binding var showProfile: Bool
    @Namespace private var gameHeroNamespace
    
    var body: some View {
        NavigationStack(path: $router.path) {
            VStack(spacing: 0) {
                // Top Bar
                TopBar(showProfile: $showProfile)
                
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
                .background(Color("BackgroundPrimary"))
            }
            .background(Color("BackgroundPrimary"))
            .navigationDestination(for: Route.self) { route in
                switch route.destination {
                case .gameSetup(let game):
                    let view = GameSetupView(game: game)
                    if #available(iOS 18.0, *) {
                        view
                            .navigationTransition(
                                .zoom(sourceID: game.id, in: gameHeroNamespace)
                            )
                            .background(Color.black)
                    } else {
                        view
                            .background(Color.black)
                    }
                default:
                    router.view(for: route)
                        .background(Color.black)
                }
            }
        }
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
