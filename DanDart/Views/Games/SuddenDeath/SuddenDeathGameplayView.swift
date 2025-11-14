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
    
    init(game: Game, players: [Player], startingLives: Int) {
        self.game = game
        self.players = players
        self.startingLives = startingLives
        _viewModel = StateObject(wrappedValue: SuddenDeathViewModel(players: players, startingLives: startingLives))
    }
    
    var body: some View {
        ZStack {
            Color("BackgroundPrimary")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top section: player cards row
                VStack(spacing: 12) {
                    playerCardsRow
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                }
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 8)
                }
                
                Spacer(minLength: 0)
                
                // Current throw display
                CurrentThrowDisplay(
                    currentThrow: viewModel.currentThrow,
                    selectedDartIndex: viewModel.selectedDartIndex,
                    onDartTapped: { index in
                        viewModel.selectDart(at: index)
                    },
                    showScore: true
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Spacer()
                
                // Bottom section: scoring grid + Save Score button
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
        .background(Color.black)
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
        .toolbarBackground(Color("BackgroundPrimary"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled()
        .ignoresSafeArea(.container, edges: .bottom)
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
                matchId: nil
            )
        }
    }
    
    // MARK: - Player Cards Row
    
    private var playerCardsRow: some View {
        // During an active round (roundScores non-empty) show all players so we
        // can still see who lost at the end of the round. Once scores are
        // cleared for the next round, only show active players.
        let playersToShow: [Player]
        if viewModel.roundScores.isEmpty {
            playersToShow = viewModel.activePlayers
        } else {
            playersToShow = viewModel.players
        }
        let spacing: CGFloat = playersToShow.count <= 3 ? 32 : -8
        
        return HStack(spacing: spacing) {
            ForEach(playersToShow) { player in
                SuddenDeathPlayerCard(
                    player: player,
                    roundScore: viewModel.roundScores[player.id],
                    lives: viewModel.displayPlayerLives[player.id] ?? 0,
                    startingLives: viewModel.startingLives,
                    isEliminated: viewModel.eliminatedPlayers.contains(player.id),
                    isInDanger: viewModel.playersInDanger.contains(player.id),
                    isCurrentPlayer: player.id == viewModel.currentPlayer.id,
                    showScoreAnimation: viewModel.scoreAnimationPlayerId == player.id
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: 120)
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
    
    private var firstName: String {
        player.displayName.split(separator: " ").first.map(String.init) ?? player.displayName
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Skull indicator in fixed-height container to avoid layout shift
            ZStack {
                if isInDanger {
                    Image("skull")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 18)
                }
            }
            .frame(height: 20)
            
            // Avatar (with double ring for current player)
            ZStack {
                if isCurrentPlayer {
                    // Outer accent ring
                    Circle()
                        .stroke(Color("AccentSecondary"), lineWidth: 2)
                        .frame(width: 64, height: 64)
                    // Inner black ring
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                        .frame(width: 60, height: 60)
                    // Avatar inside
                    AsyncAvatarImage(
                        avatarURL: player.avatarURL,
                        size: 56
                    )
                } else {
                    AsyncAvatarImage(
                        avatarURL: player.avatarURL,
                        size: 64
                    )
                }
            }
            
            // Name
            Text(firstName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color("TextPrimary"))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 56)
            
            // Round score ('-' until player has thrown) with pop animation on save
            Text(roundScore.map { "\($0)" } ?? "-")
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(Color("TextPrimary"))
                .scaleEffect(showScoreAnimation ? 1.35 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.4), value: showScoreAnimation)
                .onChange(of: showScoreAnimation) { _, newValue in
                    if newValue {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }
                }
            
            // Lives row (hide if startingLives == 1)
            if startingLives > 1 {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    Text("\(lives)")
                        .font(.footnote)
                        .foregroundColor(Color("TextSecondary"))
                }
            }
        }
        .padding(.vertical, 4)
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
