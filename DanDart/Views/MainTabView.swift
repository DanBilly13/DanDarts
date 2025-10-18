//
//  MainTabView.swift
//  DanDart
//
//  Main tab navigation structure for authenticated users
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var authService: AuthService
    
    var body: some View {
        TabView {
            // Games Tab
            GamesTabView()
                .tabItem {
                    Image(systemName: "target")
                    Text("Games")
                }
                .tag(0)
            
            // Friends Tab
            FriendsTabView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Friends")
                }
                .tag(1)
            
            // History Tab
            HistoryTabView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("History")
                }
                .tag(2)
        }
        .accentColor(Color("AccentPrimary"))
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
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Top Bar
                TopBar()
                
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
                GameSetupView(game: game)
                    .background(Color.black)
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
    var body: some View {
        FriendsListView()
    }
}

struct HistoryTabView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            TopBar()
            
            // Content Area
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 60, weight: .medium))
                        .foregroundColor(Color("AccentPrimary"))
                    
                    Text("History")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color("TextPrimary"))
                    
                    Text("View your game history and stats")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("BackgroundPrimary"))
        }
        .background(Color("BackgroundPrimary"))
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
