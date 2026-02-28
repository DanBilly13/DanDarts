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
    @StateObject private var remoteMatchService = RemoteMatchService()
    @ObservedObject private var toastManager = FriendRequestToastManager.shared
    @State private var showProfile: Bool = false
    @State private var pendingRequestCount: Int = 0
    @State private var pendingChallengeCount: Int = 0
    @State private var selectedTab: Int = 0
    @State private var showPasswordChangeAlert = false
    @Environment(\.scenePhase) private var scenePhase
    
    // Navigation bar state for tabs
    @State private var friendsShowSearch: Bool = false
    @State private var friendsIsCreatingInvite: Bool = false
    @State private var remoteShowGameSelection: Bool = false
    @State private var historyIsSearchPresented: Bool = false
    @State private var historyShowLocalMatches: Bool = true
    
    // Single global navigation state
    @Namespace private var gameHeroNamespace
    @StateObject private var router = Router.shared

    private struct InviteTokenToClaim: Identifiable {
        let id: String
        let token: String
    }

    @State private var inviteTokenToClaim: InviteTokenToClaim? = nil
    
    private var rootNavTitle: String {
        switch selectedTab {
        case 0: return "Games"
        case 1: return "Friends"
        case 2: return "Remote matches"
        case 3: return "History"
        default: return ""
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Text(rootNavTitle)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
                .fixedSize()
                .opacity(router.path.isEmpty ? 1 : 0)
                .animation(nil, value: router.path.isEmpty)
        }
        .sharedBackgroundVisibility(.hidden)
        
        if router.path.isEmpty {
            switch selectedTab {
            case 0:
                // Games tab
                ToolbarItem(placement: .topBarTrailing) {
                    ToolbarAvatarButton(avatarURL: authService.currentUser?.avatarURL) {
                        showProfile = true
                    }
                }
            case 1:
                // Friends tab
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        friendsIsCreatingInvite = true
                    } label: {
                        ZStack {
                            Text("Invite")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(AppColor.interactivePrimaryBackground)
                                .opacity(friendsIsCreatingInvite ? 0 : 1)
                            
                            if friendsIsCreatingInvite {
                                ProgressView()
                                    .tint(AppColor.interactivePrimaryBackground)
                            }
                        }
                        .frame(minWidth: 44)
                    }
                    .disabled(friendsIsCreatingInvite)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            friendsShowSearch = true
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                }
            case 2:
                // Remote tab
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        remoteShowGameSelection = true
                    } label: {
                        Text("Challenge")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                    .frame(minWidth: 44)
                }
            case 3:
                // History tab
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        historyShowLocalMatches.toggle()
                    } label: {
                        Image(systemName: historyShowLocalMatches ? "iphone" : "iphone.slash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(historyShowLocalMatches ? AppColor.interactivePrimaryBackground : AppColor.textSecondary)
                    }
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            historyIsSearchPresented = true
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                }
            default:
                ToolbarItem(placement: .topBarTrailing) {
                    EmptyView()
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack {
                TabView(selection: $selectedTab) {
                    // Games Tab
                    GamesTabView(
                        gameHeroNamespace: gameHeroNamespace,
                        showProfile: $showProfile,
                        selectedTab: $selectedTab
                    )
                    .tabItem {
                        Image(systemName: "target")
                            .font(.system(size: 17, weight: .semibold))
                        //Text("Games")
                    }
                    .tag(0)
                    
                    // Friends Tab
                    Group {
                        if pendingRequestCount > 0 {
                            FriendsTabView(
                                showProfile: $showProfile,
                                selectedTab: $selectedTab,
                                showSearch: $friendsShowSearch,
                                isCreatingInvite: $friendsIsCreatingInvite
                            )
                                .tabItem {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                    //Text("Friends")
                                }
                                .badge(pendingRequestCount)
                                .tag(1)
                        } else {
                            FriendsTabView(
                                showProfile: $showProfile,
                                selectedTab: $selectedTab,
                                showSearch: $friendsShowSearch,
                                isCreatingInvite: $friendsIsCreatingInvite
                            )
                                .tabItem {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                    //Text("Friends")
                                }
                                .tag(1)
                        }
                    }
                    
                    // Remote Tab
                    Group {
                        if pendingChallengeCount > 0 {
                            RemoteGamesTab(showGameSelection: $remoteShowGameSelection)
                                .tabItem {
                                    Image(systemName: "network")
                                        .font(.system(size: 17, weight: .semibold))
                                    //Text("Remote")
                                }
                                .badge(pendingChallengeCount)
                                .tag(2)
                        } else {
                            RemoteGamesTab(showGameSelection: $remoteShowGameSelection)
                                .tabItem {
                                    Image(systemName: "network")
                                        .font(.system(size: 17, weight: .semibold))
                                    //Text("Remote")
                                }
                                .tag(2)
                        }
                    }
                    
                    // History Tab
                    HistoryTabView(
                        showProfile: $showProfile,
                        isSearchPresented: $historyIsSearchPresented,
                        showLocalMatches: $historyShowLocalMatches
                    )
                        .tabItem {
                            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                .fontWeight(.bold)
                            //Text("History")
                        }
                        .tag(3)
                }
                .background(AppColor.backgroundPrimary)
                .accentColor(AppColor.interactivePrimaryBackground)
                
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .navigationDestination(for: Route.self) { route in
                destinationView(for: route)
                    .environmentObject(router)
                    .environmentObject(authService)
                    .environmentObject(friendsService)
                    .environmentObject(remoteMatchService)
            }
        }
        .environmentObject(router)
        .environmentObject(authService)
        .environmentObject(friendsService)
        .environmentObject(remoteMatchService)
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
            loadPendingChallengeCount()
            
            // Set toast suppression based on current tab
            toastManager.suppressRequestReceivedToasts = (selectedTab == 1)

            if inviteTokenToClaim == nil, let token = PendingInviteStore.shared.getToken() {
                inviteTokenToClaim = InviteTokenToClaim(id: token, token: token)
            }
            
            // Setup realtime subscriptions on app launch if user is authenticated
            if let userId = authService.currentUser?.id {
                print("🔵 [MainTabView] User authenticated, setting up realtime subscriptions")
                print("🔵 [MainTabView] User ID: \(userId)")
                Task {
                    await friendsService.setupRealtimeSubscription(userId: userId)
                    await remoteMatchService.setupRealtimeSubscription(userId: userId)
                }
            } else {
                print("⚠️ [MainTabView] No authenticated user, skipping realtime subscriptions")
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
            
            // Listen for remote challenge changes
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RemoteChallengesChanged"),
                object: nil,
                queue: .main
            ) { _ in
                print("🎯 [MainTabView] ========================================")
                print("🎯 [MainTabView] Received RemoteChallengesChanged notification")
                print("🎯 [MainTabView] Current challenge badge count: \(pendingChallengeCount)")
                print("🎯 [MainTabView] Thread: \(Thread.current)")
                print("🎯 [MainTabView] ========================================")
                loadPendingChallengeCount()
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
            loadPendingChallengeCount()

            if inviteTokenToClaim == nil, let token = PendingInviteStore.shared.getToken() {
                inviteTokenToClaim = InviteTokenToClaim(id: token, token: token)
            }
            
            // Setup or remove realtime subscriptions based on user state
            if let userId = newValue {
                // User logged in - setup subscriptions
                Task {
                    await friendsService.setupRealtimeSubscription(userId: userId)
                    await remoteMatchService.setupRealtimeSubscription(userId: userId)
                }
            } else if oldValue != nil {
                // User logged out - remove subscriptions
                Task {
                    await friendsService.removeRealtimeSubscription()
                    await remoteMatchService.removeRealtimeSubscription()
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
    
    private func loadPendingChallengeCount() {
        print("🎯 [MainTabView] loadPendingChallengeCount() called")
        print("🎯 [MainTabView] Current user: \(authService.currentUser?.id.uuidString ?? "nil")")
        
        guard let currentUser = authService.currentUser else {
            print("⚠️ [MainTabView] No current user, setting challenge badge to 0")
            pendingChallengeCount = 0
            return
        }
        
        Task {
            do {
                print("🎯 [MainTabView] Querying pending challenges for user: \(currentUser.id)")
                let count = try await remoteMatchService.getPendingChallengeCount(userId: currentUser.id)
                print("✅ [MainTabView] Query returned count: \(count)")
                await MainActor.run {
                    print("🎯 [MainTabView] Updating challenge badge count from \(pendingChallengeCount) to \(count)")
                    pendingChallengeCount = count
                    print("✅ [MainTabView] Challenge badge count updated successfully")
                }
            } catch {
                print("❌ [MainTabView] Failed to load pending challenge count: \(error)")
                await MainActor.run {
                    pendingChallengeCount = 0
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
    
    // MARK: - Destination View Builder
    
    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route.destination {
        case .gameSetup(let game):
            let view = GameSetupView(game: game)
            if #available(iOS 18.0, *) {
                view
                    .navigationTransition(.zoom(sourceID: game.id, in: gameHeroNamespace))
                    .navigationBarBackButtonHidden(true)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .background(AppColor.backgroundPrimary)
            } else {
                view
                    .navigationBarBackButtonHidden(true)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .background(AppColor.backgroundPrimary)
            }
        
        case .remoteGameSetup(let game, let opponent):
            let view = RemoteGameSetupView(game: game, preselectedOpponent: opponent, selectedTab: $selectedTab)
            if #available(iOS 18.0, *) {
                view
                    .navigationTransition(.zoom(sourceID: game.id, in: gameHeroNamespace))
                    .navigationBarBackButtonHidden(true)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .background(AppColor.backgroundPrimary)
            } else {
                view
                    .navigationBarBackButtonHidden(true)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .background(AppColor.backgroundPrimary)
            }
        
        case .remoteLobby(let match, let opponent, let currentUser, let cancelledMatchIds, let onCancel):
            RemoteLobbyView(match: match, opponent: opponent, currentUser: currentUser, onCancel: onCancel, cancelledMatchIds: cancelledMatchIds)
                .id("lobby-\(match.id.uuidString)")
                .background(AppColor.backgroundPrimary)
        
        case .remoteGameplay(let match, let opponent, let currentUser):
            RemoteGameplayPlaceholderView(match: match, opponent: opponent, currentUser: currentUser)
                .id("gameplay-\(match.id.uuidString)")
                .background(AppColor.backgroundPrimary)
        
        default:
            router.view(for: route, selectedTab: $selectedTab)
                .background(AppColor.backgroundPrimary)
        }
    }
}

// MARK: - Tab Views

struct GamesTabView: View {
    let games = Game.loadGames()
    let gameHeroNamespace: Namespace.ID
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var authService: AuthService
    @Binding var showProfile: Bool
    @Binding var selectedTab: Int
    
    var body: some View {
        ZStack {
            AppColor.backgroundPrimary
                .padding(-60)
                .ignoresSafeArea()

            // Games List Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Remote games section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Remote games")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColor.textPrimary)
                            .padding(.horizontal, 16)
                        
                        VStack(spacing: 12) {
                            GameCardRemote(game: Game.remote301) {
                                router.push(.remoteGameSetup(game: Game.remote301, opponent: nil))
                            }
                            .modifier(GameHeroSourceModifier(game: Game.remote301, namespace: gameHeroNamespace))
                            
                            GameCardRemote(game: Game.remote501) {
                                router.push(.remoteGameSetup(game: Game.remote501, opponent: nil))
                            }
                            .modifier(GameHeroSourceModifier(game: Game.remote501, namespace: gameHeroNamespace))
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Local games section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Local games")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColor.textPrimary)
                            .padding(.horizontal, 16)
                        
                        LazyVStack(spacing: 16) {
                            ForEach(games) { game in
                                GameCard(game: game) {
                                    router.push(.gameSetup(game: game))
                                }
                                .modifier(GameHeroSourceModifier(game: game, namespace: gameHeroNamespace))
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.backgroundPrimary)
        }
        .background(
            AppColor.backgroundPrimary
                .padding(-60)
                .ignoresSafeArea()
        )
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
    @EnvironmentObject private var router: Router
    @Binding var showProfile: Bool
    @Binding var selectedTab: Int
    @Binding var showSearch: Bool
    @Binding var isCreatingInvite: Bool
    
    var body: some View {
        FriendsListView(
            showSearch: $showSearch,
            isCreatingInvite: $isCreatingInvite
        )
    }
}

struct HistoryTabView: View {
    @Binding var showProfile: Bool
    @Binding var isSearchPresented: Bool
    @Binding var showLocalMatches: Bool
    
    var body: some View {
        MatchHistoryView(
            isSearchPresented: $isSearchPresented,
            showLocalMatches: $showLocalMatches
        )
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
