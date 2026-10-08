//
//  CricketCatalogTests.swift
//  DanDartTests
//
//  Cricket replaces the unfinished English Cricket in the game catalog.
//

import Foundation
import Testing
@testable import DanDart

struct CricketCatalogTests {

    @Test func theCatalogListsCricketForTwoToFourPlayers() {
        let cricket = Game.loadGames().first { $0.title == "Cricket" }

        #expect(cricket != nil)
        #expect(cricket?.players == "2-4")
    }

    @Test func englishCricketIsGone() {
        #expect(Game.loadGames().contains { $0.title == "English Cricket" } == false)
    }

    @Test func cricketUsesTheCricketCoverImage() {
        let cricket = Game.loadGames().first { $0.title == "Cricket" }

        #expect(cricket?.coverImageName == "cricket")
    }

    @Test func theInstructionsExplainCutThroat() {
        let cricket = Game.loadGames().first { $0.title == "Cricket" }

        #expect(cricket?.instructions.contains("Cut-Throat.") == true)
        #expect(cricket?.instructions.contains("lowest score wins") == true)
    }
}
