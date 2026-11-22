//
//  LegacyPurchase.swift
//  DanDart
//
//  DartFreak used to cost money up front. Anyone whose first download was a build from
//  before the price went to free keeps everything, with no purchase needed.
//

import Foundation

enum LegacyPurchase {
    /// The first build number (CFBundleVersion) on the App Store once the price is Free.
    /// MUST equal the build released in the same moment the price changes (Task 17).
    static let firstFreeBuild = 55

    static func isLegacyPaidCustomer(originalAppVersion: String,
                                     firstFreeBuild: Int = firstFreeBuild) -> Bool {
        guard let build = Int(originalAppVersion.trimmingCharacters(in: .whitespaces)) else {
            return false
        }
        return build < firstFreeBuild
    }
}
