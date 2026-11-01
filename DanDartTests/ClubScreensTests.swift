//
//  ClubScreensTests.swift
//  DanDartTests
//
//  The small rules behind the Clubs screens: the tile letter and colour, the subtitle text,
//  and the name check that mirrors the database.
//

import Foundation
import Testing
@testable import DanDart

struct ClubScreensTests {

    @Test func tileLetterIsTheFirstLetterOrNumber() {
        #expect(ClubTileStyle.letter(for: "the Crown") == "T")
        #expect(ClubTileStyle.letter(for: "  Friday Lads") == "F")
        #expect(ClubTileStyle.letter(for: "-501 Club") == "5")
        #expect(ClubTileStyle.letter(for: "!!!") == "?")
        #expect(ClubTileStyle.letter(for: "") == "?")
    }

    @Test func tileColourIsStableAndInRange() throws {
        let id = try #require(UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        let first = ClubTileStyle.colorIndex(for: id, count: 4)
        #expect(first == ClubTileStyle.colorIndex(for: id, count: 4))
        #expect((0..<4).contains(first))
        #expect(ClubTileStyle.colorIndex(for: id, count: 0) == 0)
    }

    @Test func subtitleReadsNaturally() {
        #expect(ClubText.subtitle(town: "Leeds", memberCount: 14) == "Leeds · 14 players")
        #expect(ClubText.subtitle(town: nil, memberCount: 1) == "1 player")
        #expect(ClubText.subtitle(town: "", memberCount: 6, extra: "You're admin") == "6 players · You're admin")
    }

    @Test func lengthLimitCountsCodePointsLikeTheDatabase() {
        #expect(CreateClubView.clamped("abcdef", to: 4) == "abcd")
        #expect(CreateClubView.clamped("abc", to: 4) == "abc")
        // "é" written as e + combining accent is one character but two code points.
        let accented = String(repeating: "e\u{0301}", count: 25)
        #expect(accented.count == 25)
        #expect(CreateClubView.clamped(accented, to: 40).unicodeScalars.count == 40)
    }

    @Test func clubDestinationsCompareAndHashByTheirValues() {
        #expect(Destination.findClub == Destination.findClub)
        #expect(Destination.createClub(name: "Crown") == Destination.createClub(name: "Crown"))
        #expect(Destination.createClub(name: "Crown") != Destination.createClub(name: "Lion"))
        #expect(Destination.findClub != Destination.createClub(name: ""))
        #expect(Destination.createClub(name: "Crown").hashValue == Destination.createClub(name: "Crown").hashValue)
    }

    @Test func nameNeedsThreeLettersOrNumbers() {
        #expect(CreateClubView.isValidName("The Crown"))
        #expect(CreateClubView.isValidName("501"))
        #expect(!CreateClubView.isValidName("ab"))
        #expect(!CreateClubView.isValidName("a b"))
        #expect(!CreateClubView.isValidName("---  ---"))
        #expect(!CreateClubView.isValidName(""))
    }
}
