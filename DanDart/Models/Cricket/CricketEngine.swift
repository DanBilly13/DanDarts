//
//  CricketEngine.swift
//  Dart Freak
//
//  The Cricket (Tactics) rules, kept free of SwiftUI so they can be tested directly.
//
//  Close a target with 3 marks (single 1, double 2, treble 3). After that, extra marks
//  score the target's value, but only while at least one opponent has not closed it.
//  A target everyone has closed is dead. Win by closing all seven targets while your
//  points are at least every opponent's.
//

import Foundation

/// Declaration order is the scoreboard row order (20 down to 15, then the bull); keep it.
enum CricketTarget: Int, CaseIterable, Codable, Hashable {
    case twenty = 20
    case nineteen = 19
    case eighteen = 18
    case seventeen = 17
    case sixteen = 16
    case fifteen = 15
    case bull = 25

    /// Points per extra mark.
    var pointValue: Int { rawValue }

    /// Row label on the scoreboard.
    var label: String { self == .bull ? "B" : "\(rawValue)" }
}

/// One dart, as the rules see it: which target it hit and how many marks it was worth.
struct CricketDart: Equatable {
    let target: CricketTarget?
    let marks: Int

    static let miss = CricketDart(target: nil, marks: 0)

    /// Converts what the keypad sends. 25 is the outer bull (one mark), 50 the inner bull
    /// (two marks); the bull has no treble. Anything that isn't a Cricket number is a miss.
    static func from(baseValue: Int, scoreType: ScoreType) -> CricketDart {
        switch baseValue {
        case 50:
            return CricketDart(target: .bull, marks: 2)
        case 25:
            return CricketDart(target: .bull, marks: min(scoreType.multiplier, 2))
        default:
            guard let target = CricketTarget(rawValue: baseValue) else { return .miss }
            return CricketDart(target: target, marks: scoreType.multiplier)
        }
    }
}

/// How Cricket is scored. The raw value is what a match saves as `matchFormat`, so every
/// Cricket match saved before this option existed (format 1) reads as Standard.
enum CricketScoring: Int, Equatable {
    case standard = 1
    case cutThroat = 2

    /// Anything other than 2 is Standard.
    init(matchFormat: Int) {
        self = CricketScoring(rawValue: matchFormat) ?? .standard
    }

    var matchFormat: Int { rawValue }
}

struct CricketState: Equatable {
    /// Throwing order.
    let playerIds: [UUID]
    let scoring: CricketScoring
    /// Marks per player per target, 0...3. Three means closed.
    var markCounts: [UUID: [CricketTarget: Int]]
    var pointTotals: [UUID: Int]
    var currentPlayerIndex = 0
    /// Darts thrown in the current visit.
    var dartsThrown = 0
    var winnerId: UUID?

    init(playerIds: [UUID], scoring: CricketScoring = .standard) {
        precondition(!playerIds.isEmpty && Set(playerIds).count == playerIds.count,
                     "Cricket needs at least one player and no duplicate players")
        self.playerIds = playerIds
        self.scoring = scoring
        let empty = Dictionary(uniqueKeysWithValues: CricketTarget.allCases.map { ($0, 0) })
        markCounts = Dictionary(uniqueKeysWithValues: playerIds.map { ($0, empty) })
        pointTotals = Dictionary(uniqueKeysWithValues: playerIds.map { ($0, 0) })
    }

    var currentPlayerId: UUID { playerIds[currentPlayerIndex] }

    /// The visit has its three darts, or a dart has won the game. Save Score shows once this is true.
    var isVisitComplete: Bool { dartsThrown >= 3 || winnerId != nil }

    /// Another dart can be thrown in this visit.
    var canThrow: Bool { !isVisitComplete }

    func marks(for playerId: UUID, on target: CricketTarget) -> Int {
        markCounts[playerId]?[target] ?? 0
    }

    func points(for playerId: UUID) -> Int {
        pointTotals[playerId] ?? 0
    }

    func closedCount(for playerId: UUID) -> Int {
        CricketTarget.allCases.filter { marks(for: playerId, on: $0) >= 3 }.count
    }

    func hasClosedAll(_ playerId: UUID) -> Bool {
        closedCount(for: playerId) == CricketTarget.allCases.count
    }

    /// Every player has closed it: nobody can mark or score on it any more.
    func isDead(_ target: CricketTarget) -> Bool {
        playerIds.allSatisfy { marks(for: $0, on: target) >= 3 }
    }
}

/// What one dart did. Drives sounds today; room for animations later.
struct CricketOutcome: Equatable {
    /// Marks that counted towards closing (0...3). Marks beyond the third are overflow and are not included; they show up as pointsScored instead. This is what gets saved per dart.
    var marksAdded = 0
    var pointsScored = 0
    var closedTarget = false
    var targetBecameDead = false
    var won = false
}

enum CricketEngine {
    /// Apply one dart for the player whose turn it is. Does nothing once the game is won
    /// or the visit already has three darts.
    static func apply(_ dart: CricketDart, to state: CricketState)
        -> (state: CricketState, outcome: CricketOutcome) {
        guard state.canThrow else { return (state, CricketOutcome()) }

        var next = state
        var outcome = CricketOutcome()
        let playerId = state.currentPlayerId
        next.dartsThrown += 1

        if let target = dart.target, dart.marks > 0 {
            let before = state.marks(for: playerId, on: target)
            let total = before + dart.marks
            let after = min(3, total)
            let overflow = total - after

            next.markCounts[playerId]?[target] = after
            outcome.marksAdded = after - before
            outcome.closedTarget = before < 3 && after == 3

            let openOpponents = state.playerIds.filter {
                $0 != playerId && state.marks(for: $0, on: target) < 3
            }
            if overflow > 0 && !openOpponents.isEmpty {
                let points = overflow * target.pointValue
                outcome.pointsScored = points
                switch state.scoring {
                case .standard:
                    next.pointTotals[playerId, default: 0] += points
                case .cutThroat:
                    for opponent in openOpponents { next.pointTotals[opponent, default: 0] += points }
                }
            }

            outcome.targetBecameDead = outcome.closedTarget && next.isDead(target)
        }

        switch state.scoring {
        case .standard:
            if next.hasClosedAll(playerId) {
                let bestOpponent = state.playerIds
                    .filter { $0 != playerId }
                    .map { next.points(for: $0) }
                    .max() ?? 0
                if next.points(for: playerId) >= bestOpponent {
                    next.winnerId = playerId
                    outcome.won = true
                }
            }
        case .cutThroat:
            if let winner = cutThroatWinner(in: next, thrower: playerId) {
                next.winnerId = winner
                outcome.won = true
            }
        }

        return (next, outcome)
    }

    /// Cut-Throat: the first player (thrower first, then throwing order) who has closed
    /// everything with points at or below every opponent's. Every player is checked, because
    /// points only rise: someone who closed earlier while another player was lower wins the
    /// moment that player is fed past them. Checking only the thrower could leave a game
    /// where every target is dead and nobody can ever win.
    private static func cutThroatWinner(in state: CricketState, thrower: UUID) -> UUID? {
        let candidates = [thrower] + state.playerIds.filter { $0 != thrower }
        return candidates.first { candidate in
            guard state.hasClosedAll(candidate) else { return false }
            let lowestOpponent = state.playerIds
                .filter { $0 != candidate }
                .map { state.points(for: $0) }
                .min() ?? Int.max
            return state.points(for: candidate) <= lowestOpponent
        }
    }

    /// Pass play to the next player. A finished game stays as it is.
    static func endVisit(_ state: CricketState) -> CricketState {
        guard state.winnerId == nil else { return state }
        var next = state
        next.currentPlayerIndex = (state.currentPlayerIndex + 1) % state.playerIds.count
        next.dartsThrown = 0
        return next
    }

    /// 1 for the winner, then by targets closed, then points (most for Standard, fewest for
    /// Cut-Throat), then throwing order.
    static func placements(for state: CricketState) -> [UUID: Int] {
        let ranked = state.playerIds.enumerated().sorted { lhs, rhs in
            let leftWon = lhs.element == state.winnerId
            let rightWon = rhs.element == state.winnerId
            if leftWon != rightWon { return leftWon }

            let leftClosed = state.closedCount(for: lhs.element)
            let rightClosed = state.closedCount(for: rhs.element)
            if leftClosed != rightClosed { return leftClosed > rightClosed }

            let leftPoints = state.points(for: lhs.element)
            let rightPoints = state.points(for: rhs.element)
            if leftPoints != rightPoints {
                return state.scoring == .cutThroat ? leftPoints < rightPoints : leftPoints > rightPoints
            }

            return lhs.offset < rhs.offset
        }

        var placements: [UUID: Int] = [:]
        for (position, entry) in ranked.enumerated() {
            placements[entry.element] = position + 1
        }
        return placements
    }
}
