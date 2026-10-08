//
//  MatchRecordEncodingTests.swift
//  DanDartTests
//
//  History reads the top-level matches.match_format column, so the insert payload must carry it.
//

import Foundation
import Testing
@testable import DanDart

struct MatchRecordEncodingTests {

    @Test func encodesMatchFormatAtTopLevelAndInMetadata() throws {
        let record = MatchRecord(
            id: UUID().uuidString,
            game_id: "cricket",
            started_at: "2026-10-08T10:00:00Z",
            ended_at: "2026-10-08T10:10:00Z",
            winner_id: nil,
            match_format: 2,
            metadata: MatchMetadata(match_format: 2, legs_won: [:], game_metadata: nil),
            game_type: "cricket",
            game_name: "Cricket",
            duration: 600,
            timestamp: "2026-10-08T10:10:00Z",
            players: "[]"
        )

        let data = try JSONEncoder().encode(record)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["match_format"] as? Int == 2)
        let metadata = try #require(json["metadata"] as? [String: Any])
        #expect(metadata["match_format"] as? Int == 2)
    }
}
