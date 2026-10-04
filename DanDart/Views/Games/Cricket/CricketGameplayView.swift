//
//  CricketGameplayView.swift
//  Dart Freak
//
//  The Cricket (Tactics) game screen, laid out like Killer: player columns on top, the
//  three-dart row, then the keypad and Save Score.
//

import SwiftUI

struct CricketGameplayView: View {
    let game: Game
    let players: [Player]

    @StateObject private var viewModel: CricketViewModel
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var authService: AuthService

    @State private var showInstructions = false
    @State private var showExitConfirmation = false

    init(game: Game, players: [Player]) {
        self.game = game
        self.players = players
        _viewModel = StateObject(wrappedValue: CricketViewModel(players: players))
    }

    private var boardColumns: [CricketBoardColumn] {
        viewModel.players.enumerated().map { index, player in
            CricketBoardColumn(
                id: player.id,
                name: CricketBoardColumn.firstName(of: player.displayName),
                avatarURL: player.avatarURL,
                color: CricketBoardColumn.color(forPlayerAt: index),
                markCounts: Dictionary(uniqueKeysWithValues: CricketTarget.allCases.map {
                    ($0, viewModel.state.marks(for: player.id, on: $0))
                }),
                points: viewModel.state.points(for: player.id),
                isCurrent: player.id == viewModel.state.currentPlayerId
            )
        }
    }

    private var deadTargets: Set<CricketTarget> {
        Set(CricketTarget.allCases.filter { viewModel.state.isDead($0) })
    }

    /// Content-area height (pt) below which the board and keypad use the compact layout.
    private static let compactHeightThreshold: CGFloat = 700

    private func content(compact: Bool) -> some View {
        VStack(spacing: 0) {
            // TOP HALF: scoreboard + current visit
            VStack {
                CricketBoardView(columns: boardColumns, deadTargets: deadTargets, compact: compact)
                    .padding(.horizontal, 16)

                Spacer(minLength: 0)

                CurrentThrowDisplay(
                    currentThrow: viewModel.currentThrow,
                    selectedDartIndex: viewModel.selectedDartIndex,
                    onDartTapped: { _ in },
                    showScore: false
                )
                .padding(.horizontal, 16)

                Spacer(minLength: 0)
            }
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: compact ? 8 : 16)
            }

            Spacer(minLength: 0)

            // BOTTOM HALF: keypad + Save Score
            VStack(spacing: 0) {
                CricketKeypad(
                    onScoreSelected: { baseValue, scoreType in
                        viewModel.recordThrow(value: baseValue, scoreType: scoreType)
                    },
                    onDelete: { viewModel.deleteThrow() },
                    canDelete: viewModel.canDelete
                )
                .padding(.horizontal, 16)

                Color.clear.frame(height: compact ? 12 : 24)

                ZStack {
                    AppButton(role: .primary, controlSize: .extraLarge, action: {}) {
                        Text("Save Score")
                    }
                    .opacity(0)
                    .disabled(true)

                    AutoSaveButton(
                        role: .primary,
                        isVisitComplete: viewModel.canSave,
                        isWinningThrow: viewModel.isWinningThrow,
                        resetKey: viewModel.currentThrow.autoSaveKey,
                        onSave: { viewModel.completeTurn() }
                    ) {
                        Label(viewModel.isWinningThrow ? "Game Over" : "Save Score",
                              systemImage: "checkmark.circle.fill")
                    }
                    .popAnimation(
                        active: viewModel.canSave,
                        duration: 0.28,
                        bounce: 0.22
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, compact ? 12 : 34)
            }
        }
    }

    var body: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()

            GeometryReader { geo in
                // Compact mode for short phones. `geo` is the content area below the navigation
                // bar, including the home-indicator strip (the bottom edge is ignored). Normal
                // layout needs about 677 pt, so: iPhone SE (667 total, ~603 here), iPhone 8 Plus
                // (~672 here) and Zoomed displays go compact; iPhone 12/13 mini and up (~720+)
                // and everything taller keep the normal layout. 700 sits between the two.
                let compact = geo.size.height < Self.compactHeightThreshold
                content(compact: compact)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .background(AppColor.backgroundPrimary)
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(game.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.justWhite)
            }

            ToolbarItem(placement: .topBarTrailing) {
                GameplayMenuButton(
                    showsAutoSave: true,
                    onInstructions: { showInstructions = true },
                    onRestart: {
                        router.pop()
                        router.push(.gameSetup(game: game))
                    },
                    onExit: { showExitConfirmation = true }
                )
            }
        }
        .toolbarBackground(AppColor.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .interactiveDismissDisabled()
        .ignoresSafeArea(.container, edges: .bottom)
        .sheet(isPresented: $showInstructions) {
            GameInstructionsView(game: game)
        }
        .alert("Exit Game?", isPresented: $showExitConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Exit", role: .destructive) {
                router.popToRoot()
            }
        } message: {
            Text("Your progress will be lost.")
        }
        .onAppear {
            // Inject authService for match saving
            viewModel.authService = authService
        }
        .onChange(of: viewModel.isGameOver) { _, isOver in
            if isOver, let winner = viewModel.winner {
                router.push(.gameEnd(
                    game: game,
                    winner: winner,
                    players: viewModel.players,
                    onPlayAgain: {
                        router.pop()
                        router.push(.preGameHype(game: game, players: players, matchFormat: 1))
                    },
                    onBackToGames: {
                        router.popToRoot()
                    },
                    matchFormat: nil,
                    legsWon: nil,
                    matchId: viewModel.matchId,
                    matchResult: nil
                ))
            }
        }
    }
}
