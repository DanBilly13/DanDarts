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
    @ObservedObject private var toastManager = FriendRequestToastManager.shared
    @State private var showProfile: Bool = false
    @State private var pendingRequestCount: Int = 0
    @State private var selectedTab: Int = 0
    @State private var showPasswordChangeAlert = false
    @Environment(\.scenePhase) private var scenePhase

    private struct InviteTokenToClaim: Identifiable {
        let id: String
        let token: String
    }

    @State private var inviteTokenToClaim: InviteTokenToClaim? = nil
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
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
            .environmentObject(friendsService)
            
            // Toast Overlay - appears above all tabs
            VStack {
                FriendRequestToastContainer(
                    onNavigate: { toast in
                        handleToastNavigation(toast)
                    },
                    onAccept: { friendshipId in
                        handleAcceptRequest(friendshipId)
                    },
                    onDeny: { friendshipId in
                        handleDenyRequest(friendshipId)
                    }
                )
                .padding(.top, 16) // Just below status bar
                
                Spacer()
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: toastManager.currentToast?.id)
            .zIndex(999) // Ensure toast appears above all other content
        }
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
            
            // Set toast suppression based on current tab
            toastManager.suppressRequestReceivedToasts = (selectedTab == 1)

            if inviteTokenToClaim == nil, let token = PendingInviteStore.shared.getToken() {
                inviteTokenToClaim = InviteTokenToClaim(id: token, token: token)
            }
            
            // Setup realtime subscription on app launch if user is authenticated
            if let userId = authService.currentUser?.id {
                print("🔵 [MainTabView] User authenticated, setting up realtime subscription")
                print("🔵 [MainTabView] User ID: \(userId)")
                Task {
                    await friendsService.setupRealtimeSubscription(userId: userId)
                }
            } else {
                print("⚠️ [MainTabView] No authenticated user, skipping realtime subscription")
            }
            
            // Listen for friend request changes
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("FriendRequestsChanged"),
                object: nil,
                queue: .main
            ) { _ in
                print("🎯 [MainTabView] ========================================")
                print("🎯 [MainTabView] Received FriendRequestsChanged notification")
                print("🎯 [MainTabView] Current badge count: \(pendingRequestCount)")
                print("🎯 [MainTabView] Thread: \(Thread.current)")
                print("🎯 [MainTabView] ========================================")
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
        .onChange(of: selectedTab) { _, newValue in
            // Update toast suppression based on selected tab
            // Tab 1 = Friends tab, suppress requestReceived toasts there
            toastManager.suppressRequestReceivedToasts = (newValue == 1)
        }
        .onChange(of: authService.currentUser?.id) { oldValue, newValue in
            loadPendingRequestCount()

            if inviteTokenToClaim == nil, let token = PendingInviteStore.shared.getToken() {
                inviteTokenToClaim = InviteTokenToClaim(id: token, token: token)
            }
            
            // Setup or remove realtime subscription based on user state
            if let userId = newValue {
                // User logged in - setup subscription
                Task {
                    await friendsService.setupRealtimeSubscription(userId: userId)
                }
            } else if oldValue != nil {
                // User logged out - remove subscription
                Task {
                    await friendsService.removeRealtimeSubscription()
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Check for pending requests when app returns to foreground
            if newPhase == .active && oldPhase == .background {
                print("🔄 [App] App returned to foreground")
                if let userId = authService.currentUser?.id {
                    Task {
                        await friendsService.checkForPendingRequestsOnReturn(userId: userId)
                    }
                }
            }
        }
    }
    
    private func loadPendingRequestCount() {
        print("🎯 [MainTabView] loadPendingRequestCount() called")
        print("🎯 [MainTabView] Current user: \(authService.currentUser?.id.uuidString ?? "nil")")
        
        guard let currentUser = authService.currentUser else {
            print("⚠️ [MainTabView] No current user, setting badge to 0")
            pendingRequestCount = 0
            return
        }
        
        Task {
            do {
                print("🎯 [MainTabView] Querying pending requests for user: \(currentUser.id)")
                let count = try await friendsService.getPendingRequestCount(userId: currentUser.id)
                print("✅ [MainTabView] Query returned count: \(count)")
                await MainActor.run {
                    print("🎯 [MainTabView] Updating badge count from \(pendingRequestCount) to \(count)")
                    pendingRequestCount = count
                    print("✅ [MainTabView] Badge count updated successfully")
                }
            } catch {
                print("❌ [MainTabView] Failed to load pending request count: \(error)")
                await MainActor.run {
                    pendingRequestCount = 0
                }
            }
        }
    }
    
    private func handleToastNavigation(_ toast: FriendRequestToast) {
        switch toast.type {
        case .requestReceived:
            // Navigate to Friends tab (where requests are shown)
            selectedTab = 1
        case .requestAccepted:
            // Navigate to Friends tab to see new friend
            selectedTab = 1
        case .requestDenied:
            // Just dismiss - no navigation needed
            break
        }
    }
    
    private func handleAcceptRequest(_ friendshipId: UUID) {
        Task {
            do {
                try await friendsService.acceptFriendRequest(requestId: friendshipId)
                
                // Success haptic feedback
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                
                // Dismiss toast after success
                await MainActor.run {
                    FriendRequestToastManager.shared.dismissCurrentToast()
                }
                
                // Reload pending request count
                loadPendingRequestCount()
            } catch {
                print("❌ Failed to accept friend request from toast: \(error)")
                
                // Error haptic feedback
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                #endif
            }
        }
    }
    
    private func handleDenyRequest(_ friendshipId: UUID) {
        Task {
            do {
                try await friendsService.denyFriendRequest(requestId: friendshipId)
                
                // Light haptic feedback (subtle)
                #if canImport(UIKit)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                #endif
                
                // Dismiss toast after success
                await MainActor.run {
                    FriendRequestToastManager.shared.dismissCurrentToast()
                }
                
                // Reload pending request count
                loadPendingRequestCount()
            } catch {
                print("❌ Failed to deny friend request from toast: \(error)")
                
                // Error haptic feedback
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                #endif
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
#Preview("Main Tab") {
    MainTabView()
        .environmentObject(AuthService())
}

#Preview("Main Tab - Dark") {
    MainTabView()
        .environmentObject(AuthService())
        .preferredColorScheme(.dark)
}

#Preview("Main Tab - With Toast") {
    let authService = AuthService()
    let toastManager = FriendRequestToastManager.shared
    
    MainTabView()
        .environmentObject(authService)
        .onAppear {
            // Show a sample toast after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let toast = FriendRequestToast(
                    type: .requestReceived,
                    user: User.mockUser1,
                    message: "New friend request from \(User.mockUser1.displayName)",
                    friendshipId: UUID()
                )
                toastManager.showToast(toast)
            }
        }
}
