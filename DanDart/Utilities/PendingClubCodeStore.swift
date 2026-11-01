//
//  PendingClubCodeStore.swift
//  Dart Freak
//
//  Holds the code from a tapped club link until the app can act on it, the same way
//  PendingInviteStore does for friend invites. A link can arrive while the person is signed
//  out, or before the main screen exists; the code waits here and the join sheet picks it up.
//

import Foundation

final class PendingClubCodeStore {
    static let shared = PendingClubCodeStore()

    /// Posted when a club link has been stored, so a running main screen can show the join sheet.
    static let linkReceived = Notification.Name("ClubLinkReceived")

    private let key = "pendingClubCode"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Stores the code, ignoring anything that isn't a valid club code.
    func setCode(_ code: String) {
        guard let clean = ClubLink.normalizedCode(code) else { return }
        defaults.set(clean, forKey: key)
    }

    func getCode() -> String? {
        defaults.string(forKey: key)
    }

    func clearCode() {
        defaults.removeObject(forKey: key)
    }

    /// Returns the waiting code and forgets it, so the sheet only shows once.
    func consumeCode() -> String? {
        let code = getCode()
        clearCode()
        return code
    }

    /// Call from every place the app receives a URL. Returns true when the URL was a club link
    /// (so the caller stops looking at it), after storing the code and telling the main screen.
    @discardableResult
    func receive(_ url: URL) -> Bool {
        guard let code = ClubLink.code(from: url) else { return false }
        setCode(code)
        NotificationCenter.default.post(name: Self.linkReceived, object: nil)
        return true
    }
}
