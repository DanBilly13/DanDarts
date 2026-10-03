//
//  RemoteVisitBustTests.swift
//  DanDartTests
//
//  Remote visits must tell the server when a visit was a bust. The server defaults
//  is_bust to false, so leaving it out recorded every remote bust as a scored visit.
//

import Foundation
import Testing
@testable import DanDart

struct RemoteVisitBustTests {

    private let me = UUID()
    private let opponent = UUID()

    private func state(myScore: Int) -> CountdownState {
        CountdownState(
            startingScore: 301,
            scores: [me: myScore, opponent: 301],
            playerIds: [me, opponent],
            currentPlayerIndex: 0,
            currentLeg: 1,
            legsWon: [me: 0, opponent: 0],
            matchFormat: 1,
            isEnded: false,
            winnerId: nil
        )
    }

    private func visit(_ darts: [ScoredThrow], from score: Int) -> [CountdownEvent] {
        CountdownEngine.applyVisit(state: state(myScore: score), playerId: me, darts: darts).events
    }

    private func throwOf(_ base: Int, _ type: ScoreType = .single) -> ScoredThrow {
        ScoredThrow(baseValue: base, scoreType: type)
    }

    // MARK: - what counts as a bust

    @Test func goingBelowZeroIsABust() {
        let events = visit([throwOf(20, .triple), throwOf(20, .triple), throwOf(20, .triple)], from: 100)

        #expect(events.containsBust)
    }

    @Test func leavingOneIsABust() {
        let events = visit([throwOf(20), throwOf(20)], from: 41) // 41 - 40 = 1

        #expect(events.containsBust)
    }

    @Test func reachingZeroWithoutADoubleIsABust() {
        let events = visit([throwOf(20)], from: 20)

        #expect(events.containsBust)
    }

    @Test func aNormalScoringVisitIsNotABust() {
        let events = visit([throwOf(20), throwOf(20), throwOf(20)], from: 301)

        #expect(events.containsBust == false)
    }

    @Test func threeMissesLeaveTheScoreAloneButAreNotABust() {
        // The old "score unchanged" check read this as a bust.
        let events = visit([throwOf(0), throwOf(0), throwOf(0)], from: 301)

        #expect(events.containsBust == false)
    }

    @Test func checkingOutOnADoubleIsNotABust() {
        let events = visit([throwOf(20, .double)], from: 40)

        #expect(events.containsBust == false)
    }

    // MARK: - what is sent

    private func json(_ payload: RemoteMatchService.SaveVisitPayload) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func theSaveVisitPayloadCarriesIsBustTrue() throws {
        let body = try json(.init(match_id: "m", darts: [60, 60, 60], score_before: 100, score_after: 100, is_bust: true))

        #expect(body["is_bust"] as? Bool == true)
    }

    @Test func theSaveVisitPayloadCarriesIsBustFalse() throws {
        let body = try json(.init(match_id: "m", darts: [20, 20, 20], score_before: 301, score_after: 241, is_bust: false))

        #expect(body["is_bust"] as? Bool == false)
        #expect(body["score_after"] as? Int == 241)
    }
}
