import Foundation

enum FlowDebug {
    static func log(_ msg: String, matchId: UUID? = nil, file: String = #fileID, line: Int = #line) {
        let ts = ISO8601DateFormatter().string(from: Date())
        let id = matchId.map { String($0.uuidString.prefix(8)) } ?? "--------"
        print("🧭 [FlowDebug \(ts)] [\(id)] \(msg)  (\(file):\(line))")
    }
}
