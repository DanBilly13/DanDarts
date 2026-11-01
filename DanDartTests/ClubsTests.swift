//
//  ClubsTests.swift
//  DanDartTests
//
//  What the club functions send back (decoded the way ClubsService does), their result codes,
//  club links, and the friend-request limit message.
//

import Foundation
import Testing
@testable import DanDart

struct ClubsDecodingTests {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try ClubsDecoding.decode(type, from: Data(json.utf8))
    }

    @Test func myClubsRowDecodesWithMicrosecondTimestamp() throws {
        let json = """
        [{"club_id":"11111111-1111-1111-1111-111111111111","name":"The Crown","town":"Leeds",
          "visibility":"open","member_count":12,"join_code":"K7M2QX","role":"admin",
          "joined_at":"2026-11-01T10:00:00.123456+00:00"}]
        """
        let clubs = try decode([Club].self, json)
        #expect(clubs.count == 1)
        let club = try #require(clubs.first)
        #expect(club.name == "The Crown")
        #expect(club.town == "Leeds")
        #expect(club.visibility == .open)
        #expect(club.memberCount == 12)
        #expect(club.joinCode == "K7M2QX")
        #expect(club.isAdmin)
        #expect(club.shareURL?.absoluteString == "https://dartfreak.com/c/K7M2QX")
    }

    @Test func timestampWithoutFractionDecodesToo() throws {
        let json = """
        [{"club_id":"11111111-1111-1111-1111-111111111111","name":"Friday Lads","town":null,
          "visibility":"invite","member_count":4,"join_code":"ABCDEF","role":"member",
          "joined_at":"2026-11-01T10:00:00+00:00"}]
        """
        let club = try #require(try decode([Club].self, json).first)
        #expect(club.town == nil)
        #expect(club.visibility == .invite)
        #expect(!club.isAdmin)
        #expect(club.joinedAt == Date(timeIntervalSince1970: 1_793_527_200))
    }

    @Test func searchResultDecodesAvatarsAndMembership() throws {
        let json = """
        [{"club_id":"22222222-2222-2222-2222-222222222222","name":"Crown Inn","town":null,
          "member_count":3,"avatars":["https://x/a.png","https://x/b.png"],"is_member":true},
         {"club_id":"33333333-3333-3333-3333-333333333333","name":"Crown Arms","town":"York",
          "member_count":0,"avatars":[],"is_member":false}]
        """
        let results = try decode([ClubSearchResult].self, json)
        #expect(results.count == 2)
        #expect(results[0].avatars.count == 2)
        #expect(results[0].isMember)
        #expect(results[1].avatars.isEmpty)
        #expect(!results[1].isMember)
    }

    @Test func previewDecodes() throws {
        let json = """
        [{"club_id":"22222222-2222-2222-2222-222222222222","name":"Crown Inn","town":"Leeds",
          "visibility":"open","member_count":3,"avatars":[],"is_member":false}]
        """
        let preview = try #require(try decode([ClubPreview].self, json).first)
        #expect(preview.visibility == .open)
        #expect(!preview.isMember)
    }

    @Test func membersDecodeEveryRelationshipAndTolerateUnknownOnes() throws {
        let relationships = ["self", "friend", "request_sent", "request_received", "blocked", "none", "something_new"]
        let rows = relationships.enumerated().map { index, value in
            """
            {"user_id":"\(String(format: "%08d", index))-0000-0000-0000-000000000000","display_name":"Person \(index)",
             "nickname":null,"avatar_url":null,"role":"member",
             "joined_at":"2026-11-01T10:00:00+00:00","relationship":"\(value)"}
            """
        }.joined(separator: ",")
        let members = try decode([ClubMember].self, "[\(rows)]")
        #expect(members.map(\.relationship) == [.selfUser, .friend, .requestSent, .requestReceived, .blocked, .none, .none])
    }

    @Test func suggestionDecodesWithAndWithoutClubName() throws {
        let json = """
        [{"user_id":"44444444-4444-4444-4444-444444444444","display_name":"Sam Rivera","nickname":"sam",
          "avatar_url":null,"club_name":"The Crown","shared_count":2},
         {"user_id":"55555555-5555-5555-5555-555555555555","display_name":"Jordan Lee","nickname":null,
          "avatar_url":"https://x/j.png","club_name":null,"shared_count":1}]
        """
        let suggestions = try decode([ClubSuggestion].self, json)
        #expect(suggestions[0].clubName == "The Crown")
        #expect(suggestions[0].sharedCount == 2)
        #expect(suggestions[1].clubName == nil)
    }

    @Test func singleTextResultDecodes() throws {
        let result = try decode(String.self, "\"not_admin\"")
        #expect(ClubActionResult(code: result) == .notAdmin)
    }

    @Test func badTimestampFails() {
        let json = """
        [{"club_id":"11111111-1111-1111-1111-111111111111","name":"X Club","town":null,
          "visibility":"open","member_count":1,"join_code":"ABCDEF","role":"member","joined_at":"yesterday"}]
        """
        #expect(throws: DecodingError.self) { try decode([Club].self, json) }
    }
}

struct ClubActionResultTests {

    @Test func everyCodeTheServerSendsIsMapped() {
        let expected: [(String, ClubActionResult)] = [
            ("ok", .ok), ("not_authenticated", .notAuthenticated), ("invalid_name", .invalidName),
            ("invalid_town", .invalidTown), ("invalid_visibility", .invalidVisibility),
            ("name_not_allowed", .nameNotAllowed), ("duplicate", .duplicate), ("club_limit", .clubLimit),
            ("not_found", .notFound), ("already_member", .alreadyMember), ("invalid_code", .invalidCode),
            ("try_again", .tryAgain), ("not_admin", .notAdmin), ("not_member", .notMember),
            ("invalid_type", .invalidType), ("use_leave", .useLeave)
        ]
        for (code, result) in expected {
            #expect(ClubActionResult(code: code) == result, "code \(code)")
        }
    }

    @Test func unknownCodeIsKept() {
        #expect(ClubActionResult(code: "brand_new") == .unknown("brand_new"))
    }

    @Test func onlyOkHasNoMessage() {
        #expect(ClubActionResult.ok.userMessage == nil)
        #expect(ClubActionResult.ok.isOk)
        let others: [ClubActionResult] = [
            .notAuthenticated, .invalidName, .invalidTown, .invalidVisibility, .nameNotAllowed, .duplicate,
            .clubLimit, .notFound, .alreadyMember, .invalidCode, .tryAgain, .notAdmin, .notMember,
            .invalidType, .useLeave, .unknown("x")
        ]
        for result in others {
            #expect(result.userMessage?.isEmpty == false, "\(result)")
            #expect(!result.isOk)
        }
    }

    @Test func clubLimitMessageSaysFive() {
        #expect(ClubActionResult.clubLimit.userMessage?.contains("5") == true)
    }
}

struct ClubLinkTests {

    @Test func codesAreCleanedLikeTheServerDoes() {
        #expect(ClubLink.normalizedCode("k7m2qx") == "K7M2QX")
        #expect(ClubLink.normalizedCode("K7M-2QX") == "K7M2QX")
        #expect(ClubLink.normalizedCode(" k7m 2qx ") == "K7M2QX")
    }

    @Test func badCodesAreRejected() {
        #expect(ClubLink.normalizedCode("") == nil)
        #expect(ClubLink.normalizedCode("K7M2Q") == nil)       // too short
        #expect(ClubLink.normalizedCode("K7M2QXA") == nil)     // too long
        #expect(ClubLink.normalizedCode("K7M20X") == nil)      // 0 is not in the alphabet
        #expect(ClubLink.normalizedCode("K7M2OX") == nil)      // O is not in the alphabet
        #expect(ClubLink.normalizedCode("K7M2LX") == nil)      // L is not in the alphabet
    }

    @Test func shareLinkUsesTheBareDomain() {
        #expect(ClubLink.url(forCode: "K7M2QX")?.absoluteString == "https://dartfreak.com/c/K7M2QX")
    }

    @Test func codeIsReadFromWebLinks() throws {
        let apex = try #require(URL(string: "https://dartfreak.com/c/k7m2qx"))
        let www = try #require(URL(string: "https://www.dartfreak.com/c/K7M2QX"))
        #expect(ClubLink.code(from: apex) == "K7M2QX")
        #expect(ClubLink.code(from: www) == "K7M2QX")
    }

    @Test func codeIsReadFromTheCustomScheme() throws {
        let url = try #require(URL(string: "dartfreak://club?code=k7m2qx"))
        #expect(ClubLink.code(from: url) == "K7M2QX")
    }

    @Test func otherLinksAreIgnored() throws {
        let urls = [
            "https://dartfreak.com/invite?token=abc",
            "https://dartfreak.com/c/",
            "https://dartfreak.com/c/K7M2QX/extra",
            "https://dartfreak.com/c/TOOSHORT",
            "https://example.com/c/K7M2QX",
            "http://dartfreak.com/c/K7M2QX",
            "dartfreak://club",
            "dartfreak://club?code=BAD",
            "dartfreak://reset-password?code=K7M2QX"
        ]
        for text in urls {
            let url = try #require(URL(string: text))
            #expect(ClubLink.code(from: url) == nil, "\(text)")
        }
    }
}

struct FriendRequestLimitTests {

    private struct LimitError: Error, CustomStringConvertible {
        let description: String
    }

    @Test func databaseLimitMessageIsRecognised() {
        #expect(FriendsError.isRequestLimit(LimitError(description: "PostgrestError(message: \"friend_request_limit\")")))
    }

    @Test func otherErrorsAreNot() {
        #expect(!FriendsError.isRequestLimit(LimitError(description: "duplicate key value")))
        #expect(!FriendsError.isRequestLimit(URLError(.notConnectedToInternet)))
    }

    @Test func limitHasAUserMessage() {
        #expect(FriendsError.requestLimit.errorDescription?.isEmpty == false)
    }
}
