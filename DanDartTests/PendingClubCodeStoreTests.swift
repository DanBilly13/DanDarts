//
//  PendingClubCodeStoreTests.swift
//  DanDartTests
//
//  The code from a tapped club link waits in the store until the join sheet can show it.
//

import Foundation
import Testing
@testable import DanDart

struct PendingClubCodeStoreTests {

    /// A throw-away defaults database so the tests never touch the real one.
    private func makeStore() throws -> PendingClubCodeStore {
        let name = "PendingClubCodeStoreTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return PendingClubCodeStore(defaults: defaults)
    }

    @Test func aValidCodeIsKeptInTidyForm() throws {
        let store = try makeStore()
        store.setCode("fl7 k2q")
        #expect(store.getCode() == "FL7K2Q")
    }

    @Test func anInvalidCodeIsIgnored() throws {
        let store = try makeStore()
        store.setCode("hello")
        store.setCode("FL7K2")
        store.setCode("FL0K2Q") // 0 is not in the alphabet
        #expect(store.getCode() == nil)
    }

    @Test func aBadCodeDoesNotReplaceAGoodOne() throws {
        let store = try makeStore()
        store.setCode("FL7K2Q")
        store.setCode("nope")
        #expect(store.getCode() == "FL7K2Q")
    }

    @Test func consumingReturnsTheCodeOnlyOnce() throws {
        let store = try makeStore()
        store.setCode("FL7K2Q")
        #expect(store.consumeCode() == "FL7K2Q")
        #expect(store.consumeCode() == nil)
    }

    @Test func clubLinksAreStoredAndOtherLinksAreNot() throws {
        let store = try makeStore()
        let web = try #require(URL(string: "https://dartfreak.com/c/FL7K2Q"))
        let scheme = try #require(URL(string: "dartfreak://club?code=ab23cd"))
        let invite = try #require(URL(string: "https://dartfreak.com/invite?token=abc"))
        let auth = try #require(URL(string: "dartfreak://auth"))

        #expect(store.receive(web))
        #expect(store.getCode() == "FL7K2Q")

        #expect(store.receive(scheme))
        #expect(store.getCode() == "AB23CD")

        store.clearCode()
        #expect(!store.receive(invite))
        #expect(!store.receive(auth))
        #expect(store.getCode() == nil)
    }
}
