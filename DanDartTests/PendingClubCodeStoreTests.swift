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
        store.setCode("kt7 m2q")
        #expect(store.getCode() == "KT7M2Q")
    }

    @Test func anInvalidCodeIsIgnored() throws {
        let store = try makeStore()
        store.setCode("hello")
        store.setCode("KT7M2")
        store.setCode("KT0M2Q") // 0 is not in the alphabet
        #expect(store.getCode() == nil)
    }

    @Test func aBadCodeDoesNotReplaceAGoodOne() throws {
        let store = try makeStore()
        store.setCode("KT7M2Q")
        store.setCode("nope")
        #expect(store.getCode() == "KT7M2Q")
    }

    @Test func consumingReturnsTheCodeOnlyOnce() throws {
        let store = try makeStore()
        store.setCode("KT7M2Q")
        #expect(store.consumeCode() == "KT7M2Q")
        #expect(store.consumeCode() == nil)
    }

    @Test func clubLinksAreStoredAndOtherLinksAreNot() throws {
        let store = try makeStore()
        let web = try #require(URL(string: "https://dartfreak.com/c/KT7M2Q"))
        let scheme = try #require(URL(string: "dartfreak://club?code=ab23cd"))
        let invite = try #require(URL(string: "https://dartfreak.com/invite?token=abc"))
        let auth = try #require(URL(string: "dartfreak://auth"))

        #expect(store.receive(web))
        #expect(store.getCode() == "KT7M2Q")

        #expect(store.receive(scheme))
        #expect(store.getCode() == "AB23CD")

        store.clearCode()
        #expect(!store.receive(invite))
        #expect(!store.receive(auth))
        #expect(store.getCode() == nil)
    }
}
