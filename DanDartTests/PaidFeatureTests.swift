//
//  PaidFeatureTests.swift
//  DanDartTests
//
//  301 and 501 stay free forever; every other game needs DartFreak Full after the trial.
//

import Testing
@testable import DanDart

struct PaidFeatureTests {

    @Test func threeOhOneAndFiveOhOneAreFree() {
        #expect(GameAccess.isFree(gameType: "301"))
        #expect(GameAccess.isFree(gameType: "501"))
        #expect(GameAccess.isFree(gameType: " 501 "))
    }

    @Test func remoteThreeOhOneAndFiveOhOneAreFree() {
        for type in ["Remote 301", "Remote 501", "remote 501"] {
            #expect(GameAccess.isFree(gameType: type), "\(type) should be free")
        }
        #expect(!GameAccess.isFree(gameType: "Remote Cricket"))
    }

    @Test func partyGamesAreNotFree() {
        for type in ["cricket", "Cricket", "halve_it", "halve it", "knockout", "sudden_death", "sudden death", "killer", "Killer"] {
            #expect(!GameAccess.isFree(gameType: type), "\(type) should be locked")
        }
    }

    /// Runs against the real catalogue (the test host loads darts_games.json from the app bundle),
    /// so a game added later is locked unless it's deliberately made free.
    @Test func onlyThreeOhOneAndFiveOhOneInTheCatalogueAreFree() {
        let games = Game.loadGames()
        #expect(games.count > 2)
        for game in games {
            let shouldBeFree = game.title == "301" || game.title == "501"
            #expect(GameAccess.isFree(gameType: game.title) == shouldBeFree, "\(game.title)")
        }
        #expect(games.contains { $0.title == "301" })
        #expect(games.contains { $0.title == "501" })
    }

    @Test func everyFeatureHasCopy() {
        for feature in PaidFeature.allCases {
            #expect(!feature.lockedTitle.isEmpty)
            #expect(!feature.lockedMessage.isEmpty)
        }
    }

    @Test func paywallReasonsHaveDistinctIds() {
        let reasons = PaidFeature.allCases.map(PaywallReason.feature) + [.trialEnded]
        #expect(Set(reasons.map(\.id)).count == reasons.count)
    }

    @Test func lockedErrorNamesTheFeature() {
        let error = PaidFeatureLockedError(feature: .remoteMatches)
        #expect(error.errorDescription == "Remote matches need DartFreak Full.")
    }
}
