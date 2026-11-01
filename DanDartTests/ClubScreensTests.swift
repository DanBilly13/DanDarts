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

    // MARK: - Club page

    private func member(_ relationship: ClubRelationship, role: ClubRole = .member) -> ClubMember {
        ClubMember(id: UUID(), displayName: "Sam", nickname: "sam", avatarURL: nil, role: role, joinedAt: Date(), relationship: relationship)
    }

    @Test func codeIsShownInTwoReadableHalves() {
        #expect(ClubLink.displayCode("FL7K2Q") == "FL7 K2Q")
        #expect(ClubLink.displayCode("ABC") == "ABC")
        #expect(ClubLink.shortLink(forCode: "FL7K2Q") == "dartfreak.com/c/FL7K2Q")
    }

    @Test func leaveMessageDependsOnWhoLeaves() {
        #expect(ClubText.leaveMessage(isAdmin: true, memberCount: 1).contains("deleted"))
        #expect(ClubText.leaveMessage(isAdmin: false, memberCount: 1).contains("deleted"))
        #expect(ClubText.leaveMessage(isAdmin: true, memberCount: 5).contains("admin"))
        #expect(ClubText.leaveMessage(isAdmin: false, memberCount: 5).contains("rejoin"))
    }

    @Test func friendCountOnlyCountsFriends() {
        let members = [member(.friend), member(.friend), member(.requestSent), member(.none), member(.selfUser)]
        #expect(ClubText.friendCount(in: members) == 2)
        #expect(ClubText.friendCount(in: []) == 0)
    }

    @Test func updatingAMemberChangesOnlyTheRelationship() {
        let original = member(.none, role: .admin)
        let changed = original.updating(relationship: .requestSent)
        #expect(changed.relationship == .requestSent)
        #expect(changed.id == original.id)
        #expect(changed.role == .admin)
        #expect(changed.displayName == original.displayName)
    }

    @Test func updatingAClubKeepsTheRest() throws {
        let id = try #require(UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        let club = Club(id: id, name: "Crown", town: "Leeds", visibility: .open, memberCount: 4, joinCode: "ABC234", role: .admin, joinedAt: Date())
        let changed = club.updating(visibility: .invite, joinCode: "XYZ567")
        #expect(changed.visibility == .invite)
        #expect(changed.joinCode == "XYZ567")
        #expect(changed.memberCount == 4)
        #expect(changed.isAdmin)
        #expect(club.updating(memberCount: 3).memberCount == 3)
        #expect(club.updating().joinCode == "ABC234")
    }

    @Test func clubDetailDestinationsCompareByClubId() throws {
        let id = try #require(UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        let other = try #require(UUID(uuidString: "99999999-2222-3333-4444-555555555555"))
        let a = Club(id: id, name: "Crown", town: nil, visibility: .open, memberCount: 4, joinCode: "ABC234", role: .member, joinedAt: Date())
        let sameClubLater = a.updating(memberCount: 9)
        let b = Club(id: other, name: "Lion", town: nil, visibility: .open, memberCount: 4, joinCode: "ABC235", role: .member, joinedAt: Date())
        #expect(Destination.clubDetail(a) == Destination.clubDetail(sameClubLater))
        #expect(Destination.clubDetail(a).hashValue == Destination.clubDetail(sameClubLater).hashValue)
        #expect(Destination.clubDetail(a) != Destination.clubDetail(b))
        #expect(Destination.clubDetail(a) != Destination.findClub)
    }
}
