import Foundation
import SwiftUI

@MainActor
struct RemoteNotificationIntentConsumer {
    struct ListsSnapshot {
        let ready: [RemoteMatchWithPlayers]
        let pending: [RemoteMatchWithPlayers]
        let sent: [RemoteMatchWithPlayers]
        let active: RemoteMatchWithPlayers?

        func contains(matchId: UUID) -> Bool {
            if active?.match.id == matchId { return true }
            if ready.contains(where: { $0.match.id == matchId }) { return true }
            if pending.contains(where: { $0.match.id == matchId }) { return true }
            if sent.contains(where: { $0.match.id == matchId }) { return true }
            return false
        }
    }

    static func consume(
        intent: NotificationRouteIntent,
        loadMatches: () async -> Void,
        listsSnapshot: () -> ListsSnapshot,
        scrollTo: (UUID) -> Void,
        setHighlighted: (UUID?) -> Void,
        clearIntent: () -> Void
    ) async {
        await loadMatches()

        let snapshot = listsSnapshot()
        guard snapshot.contains(matchId: intent.matchId) else {
            clearIntent()
            return
        }

        await Task.yield()

        scrollTo(intent.matchId)
        setHighlighted(intent.matchId)

        try? await Task.sleep(nanoseconds: 1_250_000_000)

        setHighlighted(nil)
        clearIntent()
    }
}
