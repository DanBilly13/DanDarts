import Foundation
import Supabase

@MainActor
final class InviteService: ObservableObject {
    private let supabaseService = SupabaseService.shared

    struct InviteInsert: Codable {
        let token: String
        let inviterId: UUID

        enum CodingKeys: String, CodingKey {
            case token
            case inviterId = "inviter_id"
        }
    }

    enum ClaimResult: Equatable {
        case claimed
        case alreadyFriends
        case pendingExists
        case blocked
        case expired
        case alreadyUsed
        case selfInvite
        case notAuthenticated
        case invalid
        case unknown(String)
    }

    private struct ClaimInviteRow: Decodable {
        let result: String
        let inviterId: UUID?

        enum CodingKeys: String, CodingKey {
            case result
            case inviterId = "inviter_id"
        }
    }

    func createInvite(inviterId: UUID) async throws -> URL {
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")

        let insert = InviteInsert(token: token, inviterId: inviterId)

        try await supabaseService.client
            .from("invites")
            .insert(insert)
            .execute()

        guard let url = URL(string: "https://www.dartfreak.com/invite?token=\(token)") else {
            throw URLError(.badURL)
        }

        return url
    }

    func claimInvite(token: String) async throws -> ClaimResult {
        let data = try await supabaseService.client.database
            .rpc("claim_invite", params: ["p_token": token])
            .execute()
            .data

        let decoder = JSONDecoder()
        let rows = try decoder.decode([ClaimInviteRow].self, from: data)
        let resultString = rows.first?.result ?? "unknown"

        switch resultString {
        case "claimed":
            return .claimed
        case "already_friends":
            return .alreadyFriends
        case "pending_exists":
            return .pendingExists
        case "blocked":
            return .blocked
        case "expired":
            return .expired
        case "already_used":
            return .alreadyUsed
        case "self_invite":
            return .selfInvite
        case "not_authenticated":
            return .notAuthenticated
        case "invalid":
            return .invalid
        default:
            return .unknown("Invite claim failed: \(resultString)")
        }
    }
}
