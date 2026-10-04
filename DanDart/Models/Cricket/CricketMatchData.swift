//
//  CricketMatchData.swift
//  Dart Freak
//
//  What a Cricket match saves for each dart, and how History rebuilds the final board
//  from it. The JSON travels in `match_throws.game_metadata["cricket_darts"]`, the same
//  way Killer's `killer_darts` does, because that column is [String: String].
//

import Foundation

/// What one dart did, saved so the final board can be rebuilt later.
struct CricketDartMetadata: Codable, Hashable {
    /// 15...20, or 25 for the bull. nil for a miss.
    let target: Int?
    /// What the dart was worth (0 for a miss).
    let marks: Int
    /// Marks that counted towards closing (0...3). Overflow is not counted here.
    let marksAdded: Int
    let pointsScored: Int
}

enum CricketMatchData {
    static let metadataKey = "cricket_darts"

    /// One JSON string for a visit's darts. `dart_index` is each dart's position in `darts`,
    /// so a nil entry (a dart with no data) is skipped without shifting the others.
    /// nil when no dart has data.
    static func encode(_ darts: [CricketDartMetadata?]) -> String? {
        let entries = darts.enumerated().compactMap { index, dart -> [String: Any]? in
            guard let dart else { return nil }
            var entry: [String: Any] = [
                "dart_index": index,
                "marks": dart.marks,
                "marks_added": dart.marksAdded,
                "points": dart.pointsScored
            ]
            if let target = dart.target { entry["target"] = target }
            return entry
        }
        guard !entries.isEmpty else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: entries, options: [.sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// dart_index to metadata. Anything unreadable gives an empty map.
    static func decode(_ json: String) -> [Int: CricketDartMetadata] {
        guard let data = json.data(using: .utf8),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return [:]
        }
        var map: [Int: CricketDartMetadata] = [:]
        for entry in entries {
            guard let index = entry["dart_index"] as? Int else { continue }
            map[index] = CricketDartMetadata(
                target: entry["target"] as? Int,
                marks: entry["marks"] as? Int ?? 0,
                marksAdded: entry["marks_added"] as? Int ?? 0,
                pointsScored: entry["points"] as? Int ?? 0
            )
        }
        return map
    }

    /// Reads the Cricket darts out of a `game_metadata` dictionary loaded from Supabase.
    static func decodeAll(from gameMetadata: [String: Any]?) -> [Int: CricketDartMetadata] {
        guard let json = gameMetadata?[metadataKey] as? String else { return [:] }
        return decode(json)
    }
}

/// One player's final marks and points.
struct CricketPlayerBoard: Equatable {
    var markCounts: [CricketTarget: Int] = [:]
    var points = 0

    /// 0...3 (three is closed).
    func marks(on target: CricketTarget) -> Int {
        min(markCounts[target] ?? 0, 3)
    }
}

enum CricketBoardBuilder {
    /// Adds up every saved dart. Keyed by `MatchPlayer.id`.
    static func build(players: [MatchPlayer]) -> [UUID: CricketPlayerBoard] {
        var boards: [UUID: CricketPlayerBoard] = [:]
        for player in players {
            var board = CricketPlayerBoard()
            for turn in player.turns {
                for dart in turn.darts {
                    guard let metadata = dart.cricketMetadata else { continue }
                    if let rawTarget = metadata.target, let target = CricketTarget(rawValue: rawTarget) {
                        board.markCounts[target, default: 0] += metadata.marksAdded
                    }
                    board.points += metadata.pointsScored
                }
            }
            boards[player.id] = board
        }
        return boards
    }

    /// False for a match with no Cricket darts, which History shows with the generic view.
    static func hasData(in players: [MatchPlayer]) -> Bool {
        players.contains { player in
            player.turns.contains { turn in
                turn.darts.contains { $0.cricketMetadata != nil }
            }
        }
    }
}
