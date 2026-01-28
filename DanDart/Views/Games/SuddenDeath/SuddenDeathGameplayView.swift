import SwiftUI

struct SuddenDeathGameplayView: View {
    let game: Game
    let players: [Player]
    let startingLives: Int
    
    @StateObject private var viewModel: SuddenDeathViewModel
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var router: Router
    @Environment(\.dismiss) private var dismiss
    
    @State private var showInstructions = false
    @State private var showExitConfirmation = false
    @State private var navigateToGameEnd = false
    @State private var showGameTip: Bool = false
    @State private var currentTip: GameTip? = nil
    
    init(game: Game, players: [Player], startingLives: Int) {
        self.game = game
        self.players = players
        self.startingLives = startingLives
        _viewModel = StateObject(wrappedValue: SuddenDeathViewModel(players: players, startingLives: startingLives))
    }
    
    var body: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()
            
            PositionedTip(
                xPercent: 0.5,
                yPercent: 0.55
            ) {
                if showGameTip, let tip = currentTip {
                    TipBubble(
                        systemImageName: tip.icon,
                        title: tip.title,
                        message1: tip.message1,
                        message2: tip.message2,
                        onDismiss: {
                            showGameTip = false
                            TipManager.shared.markTipAsSeen(for: game.title)
                        }
                    )
                    .padding(.horizontal, 24)
                }
            } background: {
                VStack(spacing: 0) {
                // TOP HALF — player cards + current throw
                VStack {
                    playerCardsRow
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                    
                    Spacer(minLength: 0)
                    
                    CurrentThrowDisplay(
                        currentThrow: viewModel.currentThrow,
                        selectedDartIndex: viewModel.selectedDartIndex,
                        onDartTapped: { index in
                            viewModel.selectDart(at: index)
                        },
                        showScore: true
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 0)
                    
                    Spacer(minLength: 0)
                }
                /*.safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 16)
                }*/
                
                // Flexible space between top and bottom halves
                Spacer(minLength: 0)
                
                // BOTTOM HALF — scoring grid + Save Score button
                VStack(spacing: 0) {
                    ScoringButtonGrid(
                        onScoreSelected: { baseValue, scoreType in
                            let scoredThrow = ScoredThrow(baseValue: baseValue, scoreType: scoreType)
                            viewModel.recordThrow(scoredThrow)
                        },
                        showBustButton: false
                    )
                    .padding(.horizontal, 16)
                    
                    Color.clear.frame(height: 24)
                    
                    ZStack {
                        AppButton(role: .primary, controlSize: .extraLarge, action: {}) {
                            Text("Save Score")
                        }
                        .opacity(0)
                        .disabled(true)
                        
                        AppButton(
                            role: .primary,
                            controlSize: .extraLarge,
                            action: { viewModel.completeTurn() }
                        ) {
                            Label("Save Score", systemImage: "checkmark.circle.fill")
                        }
                        .popAnimation(
                            active: viewModel.isTurnComplete,
                            duration: 0.28,
                            bounce: 0.22
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 34)
                }
            }
            }
        }
        .background(AppColor.backgroundPrimary)
        .navigationTitle("\(game.title) - R\(viewModel.roundNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                GameplayMenuButton(
                    onInstructions: { showInstructions = true },
                    onRestart: { viewModel.restartGame() },
                    onExit: { showExitConfirmation = true }
                )
            }
        }
        .toolbarBackground(AppColor.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled()
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            if TipManager.shared.shouldShowTip(for: game.title) {
                currentTip = TipManager.shared.getTip(for: game.title)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        showGameTip = true
                    }
                }
            }
        }
        .alert("Exit Game", isPresented: $showExitConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Leave Game", role: .destructive) {
                router.popToRoot()
            }
        } message: {
            Text("Are you sure you want to leave the game? Your progress will be lost.")
        }
        .sheet(isPresented: $showInstructions) {
            GameInstructionsView(game: game)
        }
        .onAppear {
            viewModel.authService = authService
        }
        .onChange(of: viewModel.isGameOver) { _, isOver in
            if isOver {
                navigateToGameEnd = true
            }
        }
        .navigationDestination(isPresented: $navigateToGameEnd) {
            GameEndView(
                game: game,
                winner: viewModel.winner ?? viewModel.players[0],
                players: viewModel.players,
                onPlayAgain: {
                    viewModel.restartGame()
                    navigateToGameEnd = false
                },
                onChangePlayers: {
                    navigateToGameEnd = false
                    dismiss()
                },
                onBackToGames: {
                    router.popToRoot()
                },
                matchFormat: nil,
                legsWon: nil,
                matchId: viewModel.matchId,
                matchResult: viewModel.savedMatchResult
            )
        }
    }
    
    // MARK: - Player Cards Row
    
    private var playerCardsRow: some View {
        // Only show players who still have lives remaining. During the active
        // round we continue to show just the active players so that once a
        // player is eliminated (lives drop to 0) they do not reappear in later
        // rounds after scores are saved.
        let playersToShow: [Player]
        if viewModel.roundScores.isEmpty {
            // Start of a round: show all active players.
            playersToShow = viewModel.activePlayers
        } else {
            // Mid-round: still restrict to players with lives remaining,
            // preventing previously eliminated players from reappearing.
            playersToShow = viewModel.players.filter { (viewModel.displayPlayerLives[$0.id] ?? 0) > 0 }
        }
        
        // Use PlayerCardLayout for consistent spacing and sizing
        let layout = PlayerCardLayout(playerCount: playersToShow.count)
        
        return HStack(spacing: layout.spacing) {
            ForEach(playersToShow) { player in
                SuddenDeathPlayerCard(
                    player: player,
                    roundScore: viewModel.roundScores[player.id],
                    lives: viewModel.displayPlayerLives[player.id] ?? 0,
                    startingLives: viewModel.startingLives,
                    isEliminated: viewModel.eliminatedPlayers.contains(player.id),
                    isInDanger: viewModel.playersInDanger.contains(player.id),
                    isCurrentPlayer: player.id == viewModel.currentPlayer.id,
                    showScoreAnimation: viewModel.scoreAnimationPlayerId == player.id,
                    showSkullWiggle: viewModel.showSkullWiggle,
                    playerIndex: viewModel.players.firstIndex(where: { $0.id == player.id }) ?? 0
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)        
    }
}

// MARK: - Sudden Death Player Card

struct SuddenDeathPlayerCard: View {
    let player: Player
    let roundScore: Int?
    let lives: Int
    let startingLives: Int
    let isEliminated: Bool
    let isInDanger: Bool
    let isCurrentPlayer: Bool
    let showScoreAnimation: Bool
    let showSkullWiggle: Bool
    let playerIndex: Int
    
    @State private var wiggleAngle: Double = 0
    
    private var firstName: String {
        player.displayName.split(separator: " ").first.map(String.init) ?? player.displayName
    }
    
    // Get player color based on index
    private var playerColor: Color {
        switch playerIndex {
        case 0: return AppColor.player1
        case 1: return AppColor.player2
        case 2: return AppColor.player3
        case 3: return AppColor.player4
        case 4: return AppColor.player5
        case 5: return AppColor.player6
        default: return AppColor.player1
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Skull indicator in fixed-height container to avoid layout shift
            ZStack {
                if isInDanger {
                    Image("skull")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(AppColor.textPrimary)
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(wiggleAngle))
                        .scaleEffect(showSkullWiggle ? 1.8 : 1.0)
                }
            }
            .frame(height: 32)
            
            // Avatar (with double ring for current player)
            PlayerAvatarWithRing(
                avatarURL: player.avatarURL,
                isCurrentPlayer: isCurrentPlayer,
                ringColor: playerColor,
                size: 64
            )
            VStack (spacing: 2) {
                // Name
                Text(firstName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(playerColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 56)
                
                // Round score ('-' until player has thrown) with pop animation on save
                Text(roundScore.map { "\($0)" } ?? "-")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(playerColor)
                    .scaleEffect(showScoreAnimation ? 1.35 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.4), value: showScoreAnimation)
                    .onChange(of: showScoreAnimation) { _, newValue in
                        if newValue {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        }
                    }
                
                // Lives row (hide if startingLives == 1)
                LivesDisplay(lives: lives, startingLives: startingLives)
            }
           
        }
        .padding(.vertical, 0)
        .onAppear {
            print("[SuddenDeathCard] appear for \(player.displayName) | isInDanger: \(isInDanger) | showSkullWiggle: \(showSkullWiggle)")
        }
        .onChange(of: isInDanger) { _, newValue in
            print("[SuddenDeathCard] isInDanger changed for \(player.displayName): \(newValue)")
        }
        .onChange(of: showSkullWiggle) { _, newValue in
            print("[SuddenDeathCard] showSkullWiggle changed for \(player.displayName): \(newValue) | isInDanger: \(isInDanger)")

            // Only animate when the flag turns on AND this player is in danger
            guard newValue, isInDanger else { return }

            // Reset to neutral
            wiggleAngle = 0

            withAnimation(.easeInOut(duration: 0.08).repeatCount(6, autoreverses: true)) {
                wiggleAngle = 12
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                wiggleAngle = 0 // reset to neutral
            }
        }
    }
}

// MARK: - Previews

#Preview("Sudden Death - 2 Players") {
    NavigationStack {
        SuddenDeathGameplayView(
            game: Game(
                title: "Sudden Death",
                subtitle: "Lowest score loses a life",
                players: "2+ players",
                instructions: "Each player throws three darts per round. The lowest score(s) lose a life. Last player standing wins."
            ),
            players: [
                Player.mockGuest1,
                Player.mockGuest2
            ],
            startingLives: 3
        )
        .environmentObject(AuthService.mockAuthenticated)
    }
}

#Preview("Sudden Death - 3 Players") {
    NavigationStack {
        SuddenDeathGameplayView(
            game: Game(
                title: "Sudden Death",
                subtitle: "Lowest score loses a life",
                players: "2+ players",
                instructions: "Each player throws three darts per round. The lowest score(s) lose a life. Last player standing wins."
            ),
            players: [
                Player.mockGuest1,
                Player.mockGuest2,
                Player.mockGuest3
            ],
            startingLives: 3
        )
        .environmentObject(AuthService.mockAuthenticated)
    }
}

#Preview("Sudden Death - 4 Players") {
    NavigationStack {
        SuddenDeathGameplayView(
            game: Game(
                title: "Sudden Death",
                subtitle: "Lowest score loses a life",
                players: "2+ players",
                instructions: "Each player throws three darts per round. The lowest score(s) lose a life. Last player standing wins."
            ),
            players: [
                Player.mockGuest1,
                Player.mockGuest2,
                Player.mockGuest3,
                Player.mockConnected1
            ],
            startingLives: 3
        )
        .environmentObject(AuthService.mockAuthenticated)
    }
}

#Preview("Sudden Death - 5 Players") {
    NavigationStack {
        SuddenDeathGameplayView(
            game: Game(
                title: "Sudden Death",
                subtitle: "Lowest score loses a life",
                players: "2+ players",
                instructions: "Each player throws three darts per round. The lowest score(s) lose a life. Last player standing wins."
            ),
            players: [
                Player.mockGuest1,
                Player.mockGuest2,
                Player.mockGuest3,
                Player.mockConnected1,
                Player.mockConnected2
            ],
            startingLives: 3
        )
        .environmentObject(AuthService.mockAuthenticated)
    }
}

#Preview("Sudden Death - 6 Players") {
    NavigationStack {
        SuddenDeathGameplayView(
            game: Game(
                title: "Sudden Death",
                subtitle: "Lowest score loses a life",
                players: "2+ players",
                instructions: "Each player throws three darts per round. The lowest score(s) lose a life. Last player standing wins."
            ),
            players: [
                Player.mockGuest1,
                Player.mockGuest2,
                Player.mockGuest3,
                Player.mockConnected1,
                Player.mockConnected2,
                Player.mockConnected3
            ],
            startingLives: 3
        )
        .environmentObject(AuthService.mockAuthenticated)
    }
}
