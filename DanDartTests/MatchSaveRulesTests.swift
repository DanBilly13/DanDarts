//
//  MatchSaveRulesTests.swift
//  DanDartTests
//
//  What a finished match writes to Supabase: guest handling and solo practice.
//

import Foundation
import Testing
@testable import DanDart

struct MatchSaveRulesTests {

    private func member(_ name: String) -> Player {
        Player(displayName: name, nickname: name.lowercased(), isGuest: false, userId: UUID())
    }

    private func guest(_ name: String) -> Player {
        Player(displayName: name, nickname: "", isGuest: true)
    }

    // MARK: - winner_id

    @Test func memberWinnerIsKept() {
        let me = member("Me")
        let opponent = member("Them")

        let result = MatchSaveRules.memberWinnerId(winnerId: me.userId, players: [me, opponent])

        #expect(result == me.userId)
    }

    @Test func guestWinnerIsNotWrittenToTheWinnerColumn() {
        let me = member("Me")
        let g = guest("Guest")

        // View models pass `winner.userId ?? winner.id`, i.e. the guest's own id.
        let result = MatchSaveRules.memberWinnerId(winnerId: g.userId ?? g.id, players: [me, g])

        #expect(result == nil)
    }

    @Test func noWinnerStaysNil() {
        let me = member("Me")

        #expect(MatchSaveRules.memberWinnerId(winnerId: nil, players: [me]) == nil)
    }

    // MARK: - participants

    @Test func guestsGetNoParticipantRow() {
        let me = member("Me")
        let other = member("Other")
        let g = guest("Guest")

        let result = MatchSaveRules.participantPlayers([me, g, other])

        #expect(result.map(\.id) == [me.id, other.id])
    }

    @Test func aGuestOnlyRosterHasNoParticipants() {
        #expect(MatchSaveRules.participantPlayers([guest("A"), guest("B")]).isEmpty)
    }

    // MARK: - practice

    @Test func aSoloMatchDoesNotUpdateStats() {
        #expect(MatchSaveRules.shouldUpdateStats(playerCount: 1) == false)
    }

    @Test func aMatchWithAnOpponentUpdatesStats() {
        #expect(MatchSaveRules.shouldUpdateStats(playerCount: 2))
        #expect(MatchSaveRules.shouldUpdateStats(playerCount: 6))
    }

    @Test func aMatchAgainstAGuestStillUpdatesStats() {
        // Two players (one a guest) is not practice: the member is credited a win or loss.
        #expect(MatchSaveRules.shouldUpdateStats(playerCount: 2))
    }
}
