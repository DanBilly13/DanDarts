//
//  GameplaySettingsTests.swift
//  DanDartTests
//
//  The Auto-Save toggle: off by default and remembered.
//

import Foundation
import Testing
@testable import DanDart

struct GameplaySettingsTests {

    /// A throwaway store so tests never touch the real app settings.
    private func freshDefaults() -> UserDefaults {
        let name = "GameplaySettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func autoSaveIsOffByDefault() {
        #expect(GameplaySettings(defaults: freshDefaults()).autoSaveEnabled == false)
    }

    @Test func turningAutoSaveOnIsRemembered() {
        let defaults = freshDefaults()
        GameplaySettings(defaults: defaults).autoSaveEnabled = true

        #expect(GameplaySettings(defaults: defaults).autoSaveEnabled)
    }

    @Test func turningAutoSaveBackOffIsRemembered() {
        let defaults = freshDefaults()
        let settings = GameplaySettings(defaults: defaults)
        settings.autoSaveEnabled = true
        settings.autoSaveEnabled = false

        #expect(GameplaySettings(defaults: defaults).autoSaveEnabled == false)
    }

    @Test func theSettingIsStoredUnderAStableKey() {
        let defaults = freshDefaults()
        GameplaySettings(defaults: defaults).autoSaveEnabled = true

        #expect(defaults.bool(forKey: "autoSaveEnabled"))
    }
}
