//
//  DeleteAccountConfirmation.swift
//  DanDart
//
//  The typed confirmation that unlocks Delete Account.
//

import Foundation

enum DeleteAccountConfirmation {
    static let word = "DELETE"

    /// True when `text` is the word `word`, ignoring case and surrounding whitespace.
    static func isConfirmed(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(word) == .orderedSame
    }
}
