import Foundation

/// FlowDebug - Structured logging for remote match flow debugging
///
/// Area Label Convention (use as message prefixes):
/// - ACCEPT: Receiver accept flow
/// - JOIN: Challenger join flow
/// - LOAD: loadMatches() execution
/// - FREEZE: List freeze/unfreeze
/// - VISUAL_LOCK: Visual lock state
/// - FLOW_MATCH: flowMatch updates
/// - CARD_STATE: Card state mapping
/// - ROW: Row/card lifecycle
/// - LOBBY: Lobby view lifecycle
/// - LOBBY_EXIT: Lobby exit guards
/// - ROUTER: Navigation decisions
/// - REALTIME: Realtime event processing
/// - GAMEPLAY: Gameplay transition
/// - SNAPSHOT: State snapshot dumps
/// - EXIT: Exit guards and popToRoot
///
/// Example: FlowDebug.log("ACCEPT: TAP", matchId: matchId)
enum FlowDebug {
    static func log(_ msg: String, matchId: UUID? = nil, file: String = #fileID, line: Int = #line) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let id = matchId.map { String($0.uuidString.prefix(8)) } ?? "--------"
        print("🧭 [FlowDebug \(ts)] [\(id)] \(msg)  (\(file):\(line))")
    }
}
