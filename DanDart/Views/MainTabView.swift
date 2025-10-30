//
//  MainTabView.swift
//  DanDart
//
//  Main tab navigation structure for authenticated users
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var showProfile: Bool = false
    
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
            FriendsTabView(showProfile: $showProfile)
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Friends")
                }
                .tag(1)
            
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
    @State private var navigationPath = NavigationPath()
    @StateObject private var navigationManager = NavigationManager.shared
    @Binding var showProfile: Bool
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Top Bar
                TopBar(showProfile: $showProfile)
                
                // Games List Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(games) { game in
                            GameCard(game: game) {
                                navigationPath.append(game)
                            }
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("BackgroundPrimary"))
            }
            .background(Color("BackgroundPrimary"))
            .navigationDestination(for: Game.self) { game in
                if game.title == "Halve-It" {
                    HalveItSetupView(game: game)
                        .background(Color.black)
                } else {
                    GameSetupView(game: game)
                        .background(Color.black)
                }
            }
            .onChange(of: navigationManager.shouldDismissToGamesList) {
                if navigationManager.shouldDismissToGamesList {
                    navigationManager.resetDismissFlag()
                    navigationPath.removeLast(navigationPath.count)
                }
            }
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
