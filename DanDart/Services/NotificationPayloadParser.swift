import Foundation

struct NotificationPayloadParser {
    static func parseIntent(from userInfo: [AnyHashable: Any]) -> NotificationRouteIntent? {
        let matchIdString = (userInfo["matchId"] as? String)
            ?? (userInfo["match_id"] as? String)
            ?? (userInfo["matchID"] as? String)

        guard let matchIdString,
              let matchId = UUID(uuidString: matchIdString) else {
            return nil
        }

        let typeString = (userInfo["type"] as? String)?.lowercased()
        let highlightString = (userInfo["highlight"] as? String)?.lowercased()

        let highlightStyle: NotificationRouteIntent.HighlightStyle

        if highlightString == "incoming" || typeString == "challenge_received" {
            highlightStyle = .incoming
        } else if highlightString == "ready" || typeString == "match_ready" {
            highlightStyle = .ready
        } else {
            highlightStyle = .incoming
        }

        return NotificationRouteIntent(
            matchId: matchId,
            destination: .remoteTab,
            highlightStyle: highlightStyle
        )
    }
}
