//
//  Router.swift
//  Dart Freak
//
//  Router-based navigation system for centralized, testable navigation
//

import Foundation
import SwiftUI

// Shared state for game setup (players, options)
final class GameSetupState: ObservableObject {
    @Published var selectedPlayers: [Player] = []
    @Published var selectedOption: Int = 0
}

// MARK: - Destination

/// All possible navigation destinations in the app
enum Destination: Hashable {
    // Games flow
    case gameSetup(game: Game)
    case preGameHype(game: Game, players: [Player], matchFormat: Int, halveItDifficulty: HalveItDifficulty? = nil, knockoutLives: Int? = nil, killerLives: Int? = nil)
    case countdownGameplay(game: Game, players: [Player], matchFormat: Int)
    case halveItGameplay(game: Game, players: [Player], difficulty: HalveItDifficulty)
    case knockoutGameplay(game: Game, players: [Player], startingLives: Int)
    case suddenDeathGameplay(game: Game, players: [Player], startingLives: Int)
    case killerGameplay(game: Game, players: [Player], startingLives: Int)
    
    // Remote games flow
    case remoteGameSetup(game: Game, opponent: User?)
    case remoteLobby(match: RemoteMatch, opponent: User, currentUser: User, onCancel: () -> Void)
    case remoteGameplay(match: RemoteMatch, opponent: User, currentUser: User)
    
    // End game
    case gameEnd(game: Game, winner: Player, players: [Player], onPlayAgain: () -> Void, onBackToGames: () -> Void, matchFormat: Int?, legsWon: [UUID: Int]?, matchId: UUID?)
    
    // Note: We can't include closures in Hashable, so gameEnd will need special handling
    static func == (lhs: Destination, rhs: Destination) -> Bool {
        switch (lhs, rhs) {
        case (.gameSetup(let g1), .gameSetup(let g2)):
            return g1.id == g2.id
        case (.preGameHype(let g1, let p1, let m1, _, _, _), .preGameHype(let g2, let p2, let m2, _, _, _)):
            return g1.id == g2.id && p1.map(\.id) == p2.map(\.id) && m1 == m2
        case (.countdownGameplay(let g1, let p1, let m1), .countdownGameplay(let g2, let p2, let m2)):
            return g1.id == g2.id && p1.map(\.id) == p2.map(\.id) && m1 == m2
        case (.halveItGameplay(let g1, let p1, let d1), .halveItGameplay(let g2, let p2, let d2)):
            return g1.id == g2.id && p1.map(\.id) == p2.map(\.id) && d1 == d2
        case (.knockoutGameplay(let g1, let p1, let l1), .knockoutGameplay(let g2, let p2, let l2)):
            return g1.id == g2.id && p1.map(\.id) == p2.map(\.id) && l1 == l2
        case (.suddenDeathGameplay(let g1, let p1, let l1), .suddenDeathGameplay(let g2, let p2, let l2)):
            return g1.id == g2.id && p1.map(\.id) == p2.map(\.id) && l1 == l2
        case (.killerGameplay(let g1, let p1, let l1), .killerGameplay(let g2, let p2, let l2)):
            return g1.id == g2.id && p1.map(\.id) == p2.map(\.id) && l1 == l2
        case (.remoteGameSetup(let g1, let o1), .remoteGameSetup(let g2, let o2)):
            return g1.id == g2.id && o1?.id == o2?.id
        case (.remoteLobby(let m1, let o1, let c1, _), .remoteLobby(let m2, let o2, let c2, _)):
            return m1.id == m2.id && o1.id == o2.id && c1.id == c2.id
        case (.remoteGameplay(let m1, let o1, let c1), .remoteGameplay(let m2, let o2, let c2)):
            return m1.id == m2.id && o1.id == o2.id && c1.id == c2.id
        case (.gameEnd, .gameEnd):
            return true // Special case - can't compare closures
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .gameSetup(let game):
            hasher.combine("gameSetup")
            hasher.combine(game.id)
        case .preGameHype(let game, let players, let matchFormat, _, _, _):
            hasher.combine("preGameHype")
            hasher.combine(game.id)
            hasher.combine(players.map(\.id))
            hasher.combine(matchFormat)
        case .countdownGameplay(let game, let players, let matchFormat):
            hasher.combine("countdownGameplay")
            hasher.combine(game.id)
            hasher.combine(players.map(\.id))
            hasher.combine(matchFormat)
        case .halveItGameplay(let game, let players, let difficulty):
            hasher.combine("halveItGameplay")
            hasher.combine(game.id)
            hasher.combine(players.map(\.id))
            hasher.combine(difficulty)
        case .knockoutGameplay(let game, let players, let startingLives):
            hasher.combine("knockoutGameplay")
            hasher.combine(game.id)
            hasher.combine(players.map(\.id))
            hasher.combine(startingLives)
        case .suddenDeathGameplay(let game, let players, let startingLives):
            hasher.combine("suddenDeathGameplay")
            hasher.combine(game.id)
            hasher.combine(players.map(\.id))
            hasher.combine(startingLives)
        case .killerGameplay(let game, let players, let startingLives):
            hasher.combine("killerGameplay")
            hasher.combine(game.id)
            hasher.combine(players.map(\.id))
            hasher.combine(startingLives)
        case .remoteGameSetup(let game, let opponent):
            hasher.combine("remoteGameSetup")
            hasher.combine(game.id)
            hasher.combine(opponent?.id)
        case .remoteLobby(let match, let opponent, let currentUser, _):
            hasher.combine("remoteLobby")
            hasher.combine(match.id)
            hasher.combine(opponent.id)
            hasher.combine(currentUser.id)
        case .remoteGameplay(let match, let opponent, let currentUser):
            hasher.combine("remoteGameplay")
            hasher.combine(match.id)
            hasher.combine(opponent.id)
            hasher.combine(currentUser.id)
        case .gameEnd:
            hasher.combine("gameEnd")
        }
    }
}

// MARK: - Route

/// Wrapper around Destination for future extensibility (analytics, guards, etc.)
struct Route: Hashable {
    let destination: Destination
    
    init(_ destination: Destination) {
        self.destination = destination
    }
}

// MARK: - Router

/// Centralized navigation manager
@MainActor
class Router: ObservableObject {
    static let shared = Router()
    
    @Published var path = NavigationPath()
    
    private init() {}
    
    // MARK: - Navigation Methods
    
    /// Push a new destination onto the navigation stack
    func push(_ destination: Destination) {
        path.append(Route(destination))
    }
    
    /// Pop the last destination from the stack
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    
    /// Pop multiple destinations
    func pop(count: Int) {
        let actualCount = min(count, path.count)
        guard actualCount > 0 else { return }
        path.removeLast(actualCount)
    }
    
    /// Pop to root (clear entire stack)
    func popToRoot() {
        withAnimation {
            path = NavigationPath()
        }
    }
    
    /// Reset navigation to a specific destination
    func reset(to destination: Destination) {
        path = NavigationPath()
        path.append(Route(destination))
    }
    
    // MARK: - View Factory
    
    /// Build the appropriate view for a given route
    @ViewBuilder
    func view(for route: Route) -> some View {
        switch route.destination {
        case .gameSetup(let game):
            GameSetupView(game: game)
            
        case .preGameHype(let game, let players, let matchFormat, let halveItDifficulty, let knockoutLives, let killerLives):
            PreGameHypeView(
                game: game,
                players: players,
                matchFormat: matchFormat,
                halveItDifficulty: halveItDifficulty,
                knockoutLives: knockoutLives,
                killerLives: killerLives
            )
            
        case .countdownGameplay(let game, let players, let matchFormat):
            CountdownGameplayView(game: game, players: players, matchFormat: matchFormat)
            
        case .halveItGameplay(let game, let players, let difficulty):
            HalveItGameplayView(game: game, players: players, difficulty: difficulty)
            
        case .knockoutGameplay(let game, let players, let startingLives):
            KnockoutGameplayView(game: game, players: players, startingLives: startingLives)
            
        case .suddenDeathGameplay(let game, let players, let startingLives):
            SuddenDeathGameplayView(game: game, players: players, startingLives: startingLives)
            
        case .killerGameplay(let game, let players, let startingLives):
            KillerGameplayView(game: game, players: players, startingLives: startingLives)
            
        case .remoteGameSetup(let game, let opponent):
            RemoteGameSetupView(game: game, preselectedOpponent: opponent)
            
        case .remoteLobby(let match, let opponent, let currentUser, let onCancel):
            RemoteLobbyView(match: match, opponent: opponent, currentUser: currentUser, onCancel: onCancel)
            
        case .remoteGameplay(let match, let opponent, let currentUser):
            RemoteGameplayPlaceholderView(match: match, opponent: opponent, currentUser: currentUser)
            
        case .gameEnd(let game, let winner, let players, let onPlayAgain, let onBackToGames, let matchFormat, let legsWon, let matchId):
            GameEndView(
                game: game,
                winner: winner,
                players: players,
                onPlayAgain: onPlayAgain,
                onChangePlayers: {}, // Not used in current implementation
                onBackToGames: onBackToGames,
                matchFormat: matchFormat,
                legsWon: legsWon,
                matchId: matchId,
                matchResult: nil // Router doesn't have access to savedMatchResult
            )
        }
    }
}
