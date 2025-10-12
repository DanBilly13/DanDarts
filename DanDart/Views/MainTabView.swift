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
    
    var body: some View {
        VStack(spacing: 0) {
            // Simple header
            Text("Games")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding()
            
            // Simple list
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(games) { game in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(game.title)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(game.subtitle)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("Players: \(game.players)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Button("Play") {
                                print("Selected: \(game.title)")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct FriendsTabView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            TopBar()
            
            // Content Area
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 60, weight: .medium))
                        .foregroundColor(Color("AccentPrimary"))
                    
                    Text("Friends")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color("TextPrimary"))
                    
                    Text("Connect with other dart players")
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
