import Foundation

final class PendingInviteStore {
    static let shared = PendingInviteStore()

    private let tokenKey = "pendingInviteToken"

    private init() {}

    func setToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
    }

    func getToken() -> String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    func clearToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }

    func consumeToken() -> String? {
        let token = getToken()
        clearToken()
        return token
    }
}
