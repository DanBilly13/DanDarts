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
    case remoteLobby(match: RemoteMatch, opponent: User, currentUser: User, cancelledMatchIds: Binding<Set<UUID>>, onCancel: () -> Void, onUnfreeze: () -> Void)
    case remoteGameplay(matchId: UUID, challenger: User, receiver: User, currentUserId: UUID)
    
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
        case (.remoteLobby(let m1, let o1, let c1, _, _, _), .remoteLobby(let m2, let o2, let c2, _, _, _)):
            return m1.id == m2.id && o1.id == o2.id && c1.id == c2.id
        case (.remoteGameplay(let id1, let ch1, let r1, let u1), .remoteGameplay(let id2, let ch2, let r2, let u2)):
            return id1 == id2 && ch1.id == ch2.id && r1.id == r2.id && u1 == u2
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
        case .remoteLobby(let match, let opponent, let currentUser, _, _, _):
            hasher.combine("remoteLobby")
            hasher.combine(match.id)
            hasher.combine(opponent.id)
            hasher.combine(currentUser.id)
        case .remoteGameplay(let matchId, let challenger, let receiver, let currentUserId):
            hasher.combine("remoteGameplay")
            hasher.combine(matchId)
            hasher.combine(challenger.id)
            hasher.combine(receiver.id)
            hasher.combine(currentUserId)
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
    
    // Closures wired to @State path at NavigationStack root
    var pushClosure: ((Destination) -> Void)?
    var popClosure: (() -> Void)?
    var popToRootClosure: (() -> Void)?
    
    // Duplicate-push guard (temporary debug safety)
    private var lastNavKey: String?
    private var lastNavTime: CFTimeInterval = 0
    
    private init() {}
    
    // MARK: - Navigation Methods
    
    /// Push a new destination onto the navigation stack
    func push(_ destination: Destination,
              file: StaticString = #fileID,
              line: UInt = #line) {
        let destinationType = destinationName(for: destination)
        let navKey = "\(destinationType)"
        let now = CACurrentMediaTime()
        
        // Duplicate-push guard: drop if same destination within 0.1s
        if let lastKey = lastNavKey, lastKey == navKey, (now - lastNavTime) < 0.1 {
            print("[Router] DROP duplicate push(.\(destinationType)) @ \(file):\(line) [within \(String(format: "%.3f", now - lastNavTime))s]")
            return
        }
        
        lastNavKey = navKey
        lastNavTime = now
        
        print("[Router] push(.\(destinationType)) @ \(file):\(line)")
        pushClosure?(destination)
    }
    
    /// Pop the last destination from the stack
    func pop(file: StaticString = #fileID,
             line: UInt = #line) {
        print("[Router] pop() @ \(file):\(line)")
        popClosure?()
    }
    
    /// Pop to root (clear entire stack)
    func popToRoot(file: StaticString = #fileID,
                   line: UInt = #line) {
        print("[Router] popToRoot() @ \(file):\(line)")
        popToRootClosure?()
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
            
        case .remoteGameSetup:
            EmptyView() // Requires selectedTab binding - use view(for:selectedTab:) instead
            
        case .remoteLobby(let match, let opponent, let currentUser, let cancelledMatchIds, let onCancel, let onUnfreeze):
            RemoteLobbyView(match: match, opponent: opponent, currentUser: currentUser, onCancel: onCancel, onUnfreeze: onUnfreeze, cancelledMatchIds: cancelledMatchIds)
            
        case .remoteGameplay:
            EmptyView() // Requires selectedTab binding - handled in MainTabView instead
            
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
    
    /// Build the appropriate view for a given route with selectedTab binding (for remote game setup)
    @ViewBuilder
    func view(for route: Route, selectedTab: Binding<Int>) -> some View {
        switch route.destination {
        case .remoteGameSetup(let game, let opponent):
            RemoteGameSetupView(game: game, preselectedOpponent: opponent, selectedTab: selectedTab)
            
        default:
            view(for: route) // Fallback to regular view method
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get a human-readable name for a destination (for logging)
    private func destinationName(for destination: Destination) -> String {
        switch destination {
        case .gameSetup: return "gameSetup"
        case .preGameHype: return "preGameHype"
        case .countdownGameplay: return "countdownGameplay"
        case .halveItGameplay: return "halveItGameplay"
        case .knockoutGameplay: return "knockoutGameplay"
        case .suddenDeathGameplay: return "suddenDeathGameplay"
        case .killerGameplay: return "killerGameplay"
        case .remoteGameSetup: return "remoteGameSetup"
        case .remoteLobby: return "remoteLobby"
        case .remoteGameplay: return "remoteGameplay"
        case .gameEnd: return "gameEnd"
        }
    }
}
