//
//  GameplaySettings.swift
//  Dart Freak
//
//  In-game preferences. Stored the same way SoundManager stores its toggle.
//

import Foundation

final class GameplaySettings: ObservableObject {
    static let shared = GameplaySettings()

    private static let autoSaveKey = "autoSaveEnabled"

    private let defaults: UserDefaults

    /// Save a complete visit automatically once the Save Score button has filled. Off by default.
    @Published var autoSaveEnabled: Bool {
        didSet { defaults.set(autoSaveEnabled, forKey: Self.autoSaveKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.autoSaveEnabled = defaults.object(forKey: Self.autoSaveKey) as? Bool ?? false
    }
}
