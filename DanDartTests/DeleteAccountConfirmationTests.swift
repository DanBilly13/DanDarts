//
//  DeleteAccountConfirmationTests.swift
//  DanDartTests
//
//  The typed word that unlocks Delete Account.
//

import Foundation
import Testing
@testable import DanDart

struct DeleteAccountConfirmationTests {

    @Test func theExactWordConfirms() {
        #expect(DeleteAccountConfirmation.isConfirmed("DELETE"))
    }

    @Test func lowerAndMixedCaseConfirm() {
        #expect(DeleteAccountConfirmation.isConfirmed("delete"))
        #expect(DeleteAccountConfirmation.isConfirmed("Delete"))
    }

    @Test func surroundingSpacesAreIgnored() {
        #expect(DeleteAccountConfirmation.isConfirmed("  DELETE \n"))
    }

    @Test func emptyAndBlankTextDoNotConfirm() {
        #expect(!DeleteAccountConfirmation.isConfirmed(""))
        #expect(!DeleteAccountConfirmation.isConfirmed("   "))
    }

    @Test func partialOrExtraTextDoesNotConfirm() {
        #expect(!DeleteAccountConfirmation.isConfirmed("DELET"))
        #expect(!DeleteAccountConfirmation.isConfirmed("DELETE ME"))
        #expect(!DeleteAccountConfirmation.isConfirmed("DEL ETE"))
    }
}
