//
//  Club.swift
//  Dart Freak
//
//  Clubs: the shapes the Supabase club functions return (migrations 093-098) and the result
//  codes they report. The apps never read the club tables directly for anything but the
//  caller's own clubs, so every type here maps one RPC.
//

import Foundation

// MARK: - Basic values

enum ClubVisibility: String, Codable, CaseIterable {
    /// Searchable, one-tap join.
    case open
    /// Hidden from search; joined with a link or code.
    case invite
}

enum ClubRole: String, Codable {
    case admin
    case member
}

/// The caller's friendship with another club member, as `club_members_list` reports it.
enum ClubRelationship: String, Codable {
    case selfUser = "self"
    case friend
    case requestSent = "request_sent"
    case requestReceived = "request_received"
    case blocked
    case none

    /// An unknown value from a newer server is treated as "no relationship" rather than failing the whole list.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ClubRelationship(rawValue: raw) ?? .none
    }
}

// MARK: - Rows returned by the functions

/// One of the caller's clubs (`my_clubs`).
struct Club: Identifiable, Equatable, Decodable {
    let id: UUID
    let name: String
    let town: String?
    let visibility: ClubVisibility
    let memberCount: Int
    let joinCode: String
    let role: ClubRole
    let joinedAt: Date

    var isAdmin: Bool { role == .admin }

    /// The link members share. The bare domain on purpose: `www.dartfreak.com` redirects, and
    /// Apple does not follow redirects when it checks which links open the app.
    var shareURL: URL? { ClubLink.url(forCode: joinCode) }

    enum CodingKeys: String, CodingKey {
        case id = "club_id"
        case name
        case town
        case visibility
        case memberCount = "member_count"
        case joinCode = "join_code"
        case role
        case joinedAt = "joined_at"
    }
}

/// An Open club in search results (`search_clubs`).
struct ClubSearchResult: Identifiable, Equatable, Decodable {
    let id: UUID
    let name: String
    let town: String?
    let memberCount: Int
    /// Up to three avatar URLs, only from members who allow being found.
    let avatars: [String]
    let isMember: Bool

    enum CodingKeys: String, CodingKey {
        case id = "club_id"
        case name
        case town
        case memberCount = "member_count"
        case avatars
        case isMember = "is_member"
    }
}

/// What a non-member may see of an Open club, or a member of their own (`get_club_preview`).
struct ClubPreview: Identifiable, Equatable, Decodable {
    let id: UUID
    let name: String
    let town: String?
    let visibility: ClubVisibility
    let memberCount: Int
    let avatars: [String]
    let isMember: Bool

    enum CodingKeys: String, CodingKey {
        case id = "club_id"
        case name
        case town
        case visibility
        case memberCount = "member_count"
        case avatars
        case isMember = "is_member"
    }
}

/// A member of a club the caller belongs to (`club_members_list`).
struct ClubMember: Identifiable, Equatable, Decodable {
    let id: UUID
    let displayName: String
    let nickname: String?
    let avatarURL: String?
    let role: ClubRole
    let joinedAt: Date
    let relationship: ClubRelationship

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case displayName = "display_name"
        case nickname
        case avatarURL = "avatar_url"
        case role
        case joinedAt = "joined_at"
        case relationship
    }
}

/// Someone who shares a club with the caller and is not yet a friend (`club_suggestions`).
struct ClubSuggestion: Identifiable, Equatable, Decodable {
    let id: UUID
    let displayName: String
    let nickname: String?
    let avatarURL: String?
    /// One club they share with the caller, for the "from The Crown" line.
    let clubName: String?
    let sharedCount: Int

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case displayName = "display_name"
        case nickname
        case avatarURL = "avatar_url"
        case clubName = "club_name"
        case sharedCount = "shared_count"
    }
}

// MARK: - Result codes

/// What a club function reports. The functions return a code instead of raising, so the app
/// can show a clear message; anything unrecognised from a newer server becomes `.unknown`.
enum ClubActionResult: Equatable {
    case ok
    case notAuthenticated
    case invalidName
    case invalidTown
    case invalidVisibility
    case nameNotAllowed
    /// An Open club with this name and town exists; the outcome carries its id.
    case duplicate
    case clubLimit
    case notFound
    case alreadyMember
    case invalidCode
    /// A join-code collision that survived three retries (practically never).
    case tryAgain
    case notAdmin
    case notMember
    case invalidType
    /// An admin tried to remove themselves.
    case useLeave
    case unknown(String)

    init(code: String) {
        switch code {
        case "ok": self = .ok
        case "not_authenticated": self = .notAuthenticated
        case "invalid_name": self = .invalidName
        case "invalid_town": self = .invalidTown
        case "invalid_visibility": self = .invalidVisibility
        case "name_not_allowed": self = .nameNotAllowed
        case "duplicate": self = .duplicate
        case "club_limit": self = .clubLimit
        case "not_found": self = .notFound
        case "already_member": self = .alreadyMember
        case "invalid_code": self = .invalidCode
        case "try_again": self = .tryAgain
        case "not_admin": self = .notAdmin
        case "not_member": self = .notMember
        case "invalid_type": self = .invalidType
        case "use_leave": self = .useLeave
        default: self = .unknown(code)
        }
    }

    var isOk: Bool { self == .ok }

    /// Text for the user, or nil when there is nothing to say (success).
    var userMessage: String? {
        switch self {
        case .ok: return nil
        case .notAuthenticated: return "Please sign in again."
        case .invalidName: return "Club names need at least 3 letters or numbers."
        case .invalidTown: return "Town names can be up to 40 characters."
        case .nameNotAllowed: return "That name isn't allowed. Please pick another."
        case .duplicate: return "A club with that name already exists."
        case .clubLimit: return "You can be in up to 5 clubs. Leave one to join another."
        case .notFound: return "We couldn't find that club."
        case .alreadyMember: return "You're already in this club."
        case .invalidCode: return "That code doesn't match a club. Check it and try again."
        case .tryAgain: return "Something went wrong. Please try again."
        case .notAdmin: return "Only the club admin can do that."
        case .notMember: return "That person isn't in the club any more."
        case .useLeave: return "Use Leave club to leave your own club."
        case .invalidVisibility, .invalidType, .unknown: return "Something went wrong. Please try again."
        }
    }
}

/// A result code plus the club it refers to, when there is one (`create_club`, `join_club`,
/// `join_club_by_code`). For `.duplicate` the id is the existing club, so the app can offer to join it.
struct ClubOutcome: Equatable {
    let result: ClubActionResult
    let clubId: UUID?
}

// MARK: - Club links

enum ClubLink {
    /// Join codes use this alphabet (no 0, O, 1, I or L) and are six characters long.
    private static let alphabet = Set("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
    static let codeLength = 6

    /// Uppercases and drops spaces and dashes, as the server does. Returns nil unless what is left is a valid code.
    static func normalizedCode(_ raw: String) -> String? {
        let cleaned = String(raw.uppercased().filter { $0.isLetter || $0.isNumber })
        guard cleaned.count == codeLength, cleaned.allSatisfy({ alphabet.contains($0) }) else { return nil }
        return cleaned
    }

    /// `https://dartfreak.com/c/<CODE>`, the link members share.
    static func url(forCode code: String) -> URL? {
        URL(string: "https://dartfreak.com/c/\(code)")
    }

    /// Pulls a club code out of `https://dartfreak.com/c/<code>` (also `www.`) or
    /// `dartfreak://club?code=<code>`. Nil for anything else, or an invalid code.
    static func code(from url: URL) -> String? {
        if url.scheme?.lowercased() == "dartfreak", url.host?.lowercased() == "club" {
            let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value
            return value.flatMap(normalizedCode)
        }
        let host = url.host?.lowercased()
        guard url.scheme?.lowercased() == "https",
              host == "dartfreak.com" || host == "www.dartfreak.com" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == "c" else { return nil }
        return normalizedCode(parts[1])
    }
}
