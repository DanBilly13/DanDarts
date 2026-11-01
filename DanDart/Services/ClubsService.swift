//
//  ClubsService.swift
//  Dart Freak
//
//  Service for clubs: the caller's clubs, finding and joining, creating, admin actions,
//  friend suggestions, reporting and the "let club members find me" switch. Every call goes
//  through the club functions from migrations 093-098; the apps never write the club tables.
//
//  The functions that change data report a result code instead of raising (see ClubActionResult).
//  Thrown errors are network or server failures.
//

import Foundation
import Supabase

@MainActor
final class ClubsService: ObservableObject {
    private let supabaseService = SupabaseService.shared

    // MARK: - Search state

    @Published private(set) var searchResults: [ClubSearchResult] = []
    @Published private(set) var isSearching = false
    @Published private(set) var searchFailed = false
    private var searchTask: Task<Void, Never>?

    /// Searching starts at this many characters; the server needs two.
    static let minimumSearchLength = 2
    private static let searchDebounce: UInt64 = 500_000_000 // 0.5 s, like FriendSearchView

    // MARK: - My clubs

    /// Goes up each time the caller's clubs change (created, joined, left), so the Clubs tab knows to reload.
    @Published private(set) var myClubsVersion = 0

    func myClubs() async throws -> [Club] {
        try await rows("my_clubs")
    }

    // MARK: - Find

    /// Debounced search for the Find screen. Each call replaces the previous one; results land in `searchResults`.
    func search(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.count >= Self.minimumSearchLength else {
            searchResults = []
            isSearching = false
            searchFailed = false
            return
        }

        isSearching = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.searchDebounce)
            guard !Task.isCancelled, let self else { return }
            do {
                let results = try await self.searchClubs(trimmed)
                guard !Task.isCancelled else { return }
                self.searchResults = results
                self.searchFailed = false
            } catch {
                guard !Task.isCancelled else { return }
                self.searchResults = []
                self.searchFailed = true
            }
            self.isSearching = false
        }
    }

    func cancelSearch() {
        searchTask?.cancel()
        searchResults = []
        isSearching = false
        searchFailed = false
    }

    /// Open clubs whose name or town contains the text. Invite-only clubs never appear.
    func searchClubs(_ query: String) async throws -> [ClubSearchResult] {
        try await rows("search_clubs", params: QueryParams(query: query))
    }

    /// Nil when the club doesn't exist or is Invite-only and the caller isn't in it.
    func preview(clubId: UUID) async throws -> ClubPreview? {
        let found: [ClubPreview] = try await rows("get_club_preview", params: ClubIdParams(clubId: clubId))
        return found.first
    }

    /// For the "Join The Crown?" sheet. Nil when the code doesn't match a club (including old codes
    /// the admin has replaced). Works for Invite-only clubs too, because holding the code is what lets you join.
    func preview(code: String) async throws -> ClubCodePreview? {
        let found: [ClubCodePreview] = try await rows("preview_club_by_code", params: CodeParams(code: code))
        return found.first
    }

    // MARK: - Create and join

    /// For `.duplicate` the outcome's club id is the existing Open club, so the app can offer to join it.
    func createClub(name: String, town: String?, visibility: ClubVisibility) async throws -> ClubOutcome {
        let trimmedTown = town?.trimmingCharacters(in: .whitespacesAndNewlines)
        let params = CreateClubParams(
            name: name,
            town: (trimmedTown?.isEmpty ?? true) ? nil : trimmedTown,
            visibility: visibility.rawValue
        )
        return noteChange(in: try await outcome("create_club", params: params))
    }

    /// One-tap join for Open clubs.
    func joinClub(clubId: UUID) async throws -> ClubOutcome {
        noteChange(in: try await outcome("join_club", params: ClubIdParams(clubId: clubId)))
    }

    /// Joins any club, Open or Invite-only. Spaces, dashes and case in the code don't matter.
    func joinClub(code: String) async throws -> ClubOutcome {
        noteChange(in: try await outcome("join_club_by_code", params: CodeParams(code: code)))
    }

    func leaveClub(clubId: UUID) async throws -> ClubActionResult {
        let result = try await code("leave_club", params: ClubIdParams(clubId: clubId))
        if result.isOk { myClubsVersion += 1 }
        return result
    }

    private func noteChange(in outcome: ClubOutcome) -> ClubOutcome {
        if outcome.result.isOk { myClubsVersion += 1 }
        return outcome
    }

    // MARK: - Members and admin

    /// Members only; empty for anyone else.
    func members(clubId: UUID) async throws -> [ClubMember] {
        try await rows("club_members_list", params: ClubIdParams(clubId: clubId))
    }

    func setVisibility(clubId: UUID, visibility: ClubVisibility) async throws -> ClubActionResult {
        let result = try await code("set_club_visibility", params: SetVisibilityParams(clubId: clubId, visibility: visibility.rawValue))
        if result.isOk { myClubsVersion += 1 }
        return result
    }

    /// The old code stops working immediately. Returns the new code on success.
    func regenerateCode(clubId: UUID) async throws -> (result: ClubActionResult, joinCode: String?) {
        let found: [RegenerateRow] = try await rows("regenerate_club_code", params: ClubIdParams(clubId: clubId))
        guard let row = found.first else { return (.unknown("empty"), nil) }
        let result = ClubActionResult(code: row.result)
        if result.isOk { myClubsVersion += 1 }
        return (result, row.joinCode)
    }

    func removeMember(clubId: UUID, userId: UUID) async throws -> ClubActionResult {
        let result = try await code("remove_club_member", params: RemoveMemberParams(clubId: clubId, userId: userId))
        if result.isOk { myClubsVersion += 1 }
        return result
    }

    // MARK: - Suggestions

    func suggestions(limit: Int = 20) async throws -> [ClubSuggestion] {
        try await rows("club_suggestions", params: LimitParams(limit: limit))
    }

    func dismissSuggestion(userId: UUID) async throws -> ClubActionResult {
        try await code("dismiss_club_suggestion", params: UserIdParams(userId: userId))
    }

    // MARK: - Reporting

    enum ReportTarget: String {
        case club
        case user
    }

    func report(_ target: ReportTarget, id: UUID, reason: String? = nil) async throws -> ClubActionResult {
        try await code("report_content", params: ReportParams(targetType: target.rawValue, targetId: id, reason: reason))
    }

    // MARK: - "Let club members find me"

    private struct DiscoverableRow: Decodable {
        let clubDiscoverable: Bool

        enum CodingKeys: String, CodingKey {
            case clubDiscoverable = "club_discoverable"
        }
    }

    /// Defaults to true (the column default) if the row can't be read.
    func isDiscoverable(userId: UUID) async throws -> Bool {
        let found: [DiscoverableRow] = try await supabaseService.client
            .from("users")
            .select("club_discoverable")
            .eq("id", value: userId.uuidString)
            .execute()
            .value
        return found.first?.clubDiscoverable ?? true
    }

    /// Throws if no row was updated, so the switch never shows a choice that wasn't saved.
    func setDiscoverable(_ discoverable: Bool, userId: UUID) async throws {
        let updated: [DiscoverableRow] = try await supabaseService.client
            .from("users")
            .update(["club_discoverable": discoverable])
            .eq("id", value: userId.uuidString)
            .select("club_discoverable")
            .execute()
            .value
        guard !updated.isEmpty else { throw ClubsServiceError.settingNotSaved }
    }

    // MARK: - RPC plumbing

    private func rows<T: Decodable>(_ function: String) async throws -> [T] {
        let data = try await supabaseService.client.rpc(function).execute().data
        return try ClubsDecoding.decode([T].self, from: data)
    }

    private func rows<T: Decodable, P: Encodable & Sendable>(_ function: String, params: P) async throws -> [T] {
        let data = try await supabaseService.client.rpc(function, params: params).execute().data
        return try ClubsDecoding.decode([T].self, from: data)
    }

    /// For the functions that return a table of (result, club_id).
    private func outcome<P: Encodable & Sendable>(_ function: String, params: P) async throws -> ClubOutcome {
        let found: [OutcomeRow] = try await rows(function, params: params)
        guard let row = found.first else { return ClubOutcome(result: .unknown("empty"), clubId: nil) }
        return ClubOutcome(result: ClubActionResult(code: row.result), clubId: row.clubId)
    }

    /// For the functions that return a single code as text.
    private func code<P: Encodable & Sendable>(_ function: String, params: P) async throws -> ClubActionResult {
        let data = try await supabaseService.client.rpc(function, params: params).execute().data
        return ClubActionResult(code: try ClubsDecoding.decode(String.self, from: data))
    }

    // MARK: - Request shapes

    private struct OutcomeRow: Decodable {
        let result: String
        let clubId: UUID?

        enum CodingKeys: String, CodingKey {
            case result
            case clubId = "club_id"
        }
    }

    private struct RegenerateRow: Decodable {
        let result: String
        let joinCode: String?

        enum CodingKeys: String, CodingKey {
            case result
            case joinCode = "join_code"
        }
    }

    private struct CreateClubParams: Encodable, Sendable {
        let name: String
        let town: String?
        let visibility: String

        enum CodingKeys: String, CodingKey {
            case name = "p_name"
            case town = "p_town"
            case visibility = "p_visibility"
        }
    }

    private struct ClubIdParams: Encodable, Sendable {
        let clubId: UUID

        enum CodingKeys: String, CodingKey { case clubId = "p_club_id" }
    }

    private struct CodeParams: Encodable, Sendable {
        let code: String

        enum CodingKeys: String, CodingKey { case code = "p_code" }
    }

    private struct QueryParams: Encodable, Sendable {
        let query: String

        enum CodingKeys: String, CodingKey { case query = "p_query" }
    }

    private struct SetVisibilityParams: Encodable, Sendable {
        let clubId: UUID
        let visibility: String

        enum CodingKeys: String, CodingKey {
            case clubId = "p_club_id"
            case visibility = "p_visibility"
        }
    }

    private struct RemoveMemberParams: Encodable, Sendable {
        let clubId: UUID
        let userId: UUID

        enum CodingKeys: String, CodingKey {
            case clubId = "p_club_id"
            case userId = "p_user_id"
        }
    }

    private struct UserIdParams: Encodable, Sendable {
        let userId: UUID

        enum CodingKeys: String, CodingKey { case userId = "p_user_id" }
    }

    private struct LimitParams: Encodable, Sendable {
        let limit: Int

        enum CodingKeys: String, CodingKey { case limit = "p_limit" }
    }

    private struct ReportParams: Encodable, Sendable {
        let targetType: String
        let targetId: UUID
        let reason: String?

        enum CodingKeys: String, CodingKey {
            case targetType = "p_target_type"
            case targetId = "p_target_id"
            case reason = "p_reason"
        }
    }
}

enum ClubsServiceError: LocalizedError {
    case settingNotSaved

    var errorDescription: String? {
        switch self {
        case .settingNotSaved: return "Your setting couldn't be saved. Please try again."
        }
    }
}

// MARK: - Decoding

/// Decodes what the club functions send back. Kept apart from the service so tests can feed it text.
enum ClubsDecoding {
    private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let withoutFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Postgres sends timestamps like `2026-11-01T10:00:00.123456+00:00`, with or without the fraction.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = withFraction.date(from: text) ?? withoutFraction.date(from: text) {
                return date
            }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unrecognised date: \(text)")
            )
        }
        return try decoder.decode(type, from: data)
    }
}
