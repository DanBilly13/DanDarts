//
//  NotificationPreferencesTests.swift
//  DanDartTests
//
//  The Notifications toggle: a user's "off" must survive token syncs, sign-out/in and
//  relaunches, and the toggle must not claim "on" when iOS won't deliver anything.
//

import Foundation
import Testing
import UserNotifications
@testable import DanDart

struct NotificationPreferencesTests {

    /// A throwaway store so tests never touch the real app settings.
    private func freshDefaults() -> UserDefaults {
        let name = "NotificationPreferencesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - opt-out preference

    @Test func nobodyIsOptedOutByDefault() {
        let prefs = NotificationPreferences(defaults: freshDefaults())

        #expect(prefs.isOptedOut(userId: UUID()) == false)
    }

    @Test func turningNotificationsOffIsRemembered() {
        let defaults = freshDefaults()
        let user = UUID()
        NotificationPreferences(defaults: defaults).setOptedOut(true, userId: user)

        #expect(NotificationPreferences(defaults: defaults).isOptedOut(userId: user))
    }

    @Test func turningThemBackOnClearsIt() {
        let defaults = freshDefaults()
        let user = UUID()
        let prefs = NotificationPreferences(defaults: defaults)
        prefs.setOptedOut(true, userId: user)
        prefs.setOptedOut(false, userId: user)

        #expect(prefs.isOptedOut(userId: user) == false)
    }

    @Test func eachUserOnTheDeviceHasTheirOwnChoice() {
        let prefs = NotificationPreferences(defaults: freshDefaults())
        let me = UUID()
        let someoneElse = UUID()
        prefs.setOptedOut(true, userId: me)

        #expect(prefs.isOptedOut(userId: me))
        #expect(prefs.isOptedOut(userId: someoneElse) == false)
    }

    // MARK: - what a token sync writes

    @Test func aSyncActivatesTheTokenByDefault() {
        #expect(NotificationStatePolicy.tokenShouldBeActive(optedOut: false))
    }

    @Test func aSyncNeverReactivatesATokenTheUserSwitchedOff() {
        // The bug: every sync wrote is_active = true, undoing the user's "off".
        #expect(NotificationStatePolicy.tokenShouldBeActive(optedOut: true) == false)
    }

    // MARK: - what the toggle shows

    @Test func onWhenTheTokenIsActiveAndIOSAllowsNotifications() {
        for status in [UNAuthorizationStatus.authorized, .provisional, .ephemeral] {
            #expect(NotificationStatePolicy.isEnabled(tokenActive: true, authorization: status))
        }
    }

    @Test func offWhenTheTokenIsInactiveEvenIfIOSAllows() {
        #expect(NotificationStatePolicy.isEnabled(tokenActive: false, authorization: .authorized) == false)
    }

    @Test func offWhenIOSHasNotificationsDisabledEvenIfTheTokenIsActive() {
        #expect(NotificationStatePolicy.isEnabled(tokenActive: true, authorization: .denied) == false)
    }

    @Test func offBeforeIOSHasBeenAsked() {
        #expect(NotificationStatePolicy.isEnabled(tokenActive: true, authorization: .notDetermined) == false)
    }

    @Test func onlyADeniedPermissionNeedsTheTurnOnInIOSSettingsHint() {
        #expect(NotificationStatePolicy.needsIOSSettingsHint(authorization: .denied))
        #expect(NotificationStatePolicy.needsIOSSettingsHint(authorization: .authorized) == false)
        #expect(NotificationStatePolicy.needsIOSSettingsHint(authorization: .notDetermined) == false)
    }
}
