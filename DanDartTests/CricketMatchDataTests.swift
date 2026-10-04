//
//  CricketMatchDataTests.swift
//  DanDartTests
//
//  What a Cricket match saves per dart, and how History rebuilds the final board from it.
//

import Foundation
import Testing
@testable import DanDart

struct CricketMatchDataTests {

    private func dart(_ target: Int?, marks: Int, added: Int, points: Int = 0) -> CricketDartMetadata {
        CricketDartMetadata(target: target, marks: marks, marksAdded: added, pointsScored: points)
    }

    private func matchDart(_ metadata: CricketDartMetadata?) -> MatchDart {
        MatchDart(baseValue: 20, multiplier: 1, killerMetadata: nil, cricketMetadata: metadata)
    }

    private func player(_ name: String, turns: [[CricketDartMetadata?]]) -> MatchPlayer {
        let matchTurns = turns.enumerated().map { index, darts in
            MatchTurn(turnNumber: index + 1, darts: darts.map(matchDart),
                      scoreBefore: 0, scoreAfter: 0, isBust: false)
        }
        return MatchPlayer.from(player: Player(displayName: name, nickname: name.lowercased()),
                                finalScore: 0, startingScore: 0,
                                totalDartsThrown: matchTurns.reduce(0) { $0 + $1.darts.count },
                                turns: matchTurns)
    }

    // MARK: - JSON

    @Test func dartsSurviveAnEncodeDecodeRoundTrip() throws {
        let darts = [dart(20, marks: 3, added: 3), dart(nil, marks: 0, added: 0), dart(19, marks: 2, added: 1, points: 19)]

        let json = try #require(CricketMatchData.encode(darts))
        let decoded = CricketMatchData.decode(json)

        #expect(decoded.count == 3)
        #expect(decoded[0] == darts[0])
        #expect(decoded[1] == darts[1])
        #expect(decoded[2] == darts[2])
    }

    @Test func noDartsEncodeToNothing() {
        #expect(CricketMatchData.encode([]) == nil)
    }

    @Test func encodingKeepsEachDartsOriginalPosition() throws {
        let first = dart(20, marks: 3, added: 3)
        let third = dart(19, marks: 1, added: 1)

        let json = try #require(CricketMatchData.encode([first, nil, third]))
        let decoded = CricketMatchData.decode(json)

        #expect(Set(decoded.keys) == [0, 2])
        #expect(decoded[0] == first)
        #expect(decoded[2] == third)
        #expect(decoded[1] == nil)
    }

    @Test func encodingOnlyNilsGivesNothing() {
        #expect(CricketMatchData.encode([nil, nil]) == nil)
    }

    @Test func garbageDecodesToNothing() {
        #expect(CricketMatchData.decode("not json").isEmpty)
        #expect(CricketMatchData.decode("{\"a\": 1}").isEmpty)
    }

    @Test func decodeAllReadsTheCricketKeyFromGameMetadata() throws {
        let json = try #require(CricketMatchData.encode([dart(17, marks: 1, added: 1)]))

        let map = CricketMatchData.decodeAll(from: ["cricket_darts": json, "target_display": "x"])

        #expect(map[0]?.target == 17)
        #expect(CricketMatchData.decodeAll(from: nil).isEmpty)
        #expect(CricketMatchData.decodeAll(from: ["other": "y"]).isEmpty)
    }

    // MARK: - final board

    @Test func theBoardAddsUpMarksAndPoints() {
        let dan = player("Dan", turns: [
            [dart(20, marks: 3, added: 3), dart(20, marks: 1, added: 0, points: 20), dart(19, marks: 1, added: 1)],
            [dart(19, marks: 2, added: 2), nil, dart(nil, marks: 0, added: 0)]
        ])

        let board = CricketBoardBuilder.build(players: [dan])[dan.id]

        #expect(board?.marks(on: .twenty) == 3)
        #expect(board?.marks(on: .nineteen) == 3)
        #expect(board?.marks(on: .eighteen) == 0)
        #expect(board?.points == 20)
    }

    @Test func marksNeverShowMoreThanThree() {
        var board = CricketPlayerBoard()
        board.markCounts[.bull] = 5

        #expect(board.marks(on: .bull) == 3)
    }

    @Test func theBoardNeedsCricketDataToExist() {
        let withData = player("A", turns: [[dart(20, marks: 1, added: 1)]])
        let without = player("B", turns: [[nil]])

        #expect(CricketBoardBuilder.hasData(in: [withData]))
        #expect(CricketBoardBuilder.hasData(in: [without]) == false)
        #expect(CricketBoardBuilder.hasData(in: []) == false)
    }
}
