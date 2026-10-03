//
//  KillerUndoTests.swift
//  DanDartTests
//
//  Deleting a dart in Killer must reverse what that dart did (lives, Killer status,
//  elimination), not just remove it from the visit row.
//

import Foundation
import Testing
@testable import DanDart

@MainActor
struct KillerUndoTests {

    /// Three players with fixed numbers: A=20 (throws first), B=19, C=18, 3 lives each.
    private func makeGame() -> (vm: KillerViewModel, a: Player, b: Player, c: Player) {
        let a = Player(displayName: "A", nickname: "a")
        let b = Player(displayName: "B", nickname: "b")
        let c = Player(displayName: "C", nickname: "c")
        let vm = KillerViewModel(players: [a, b, c], startingLives: 3)
        vm.playerNumbers = [a.id: 20, b.id: 19, c.id: 18]
        return (vm, a, b, c)
    }

    /// A throws its own double (20): becomes a Killer.
    private func makeAKiller(_ vm: KillerViewModel) {
        vm.recordThrow(value: 20, multiplier: 2)
    }

    private func lives(_ vm: KillerViewModel, _ p: Player) -> Int {
        vm.displayPlayerLives[p.id] ?? -1
    }

    // MARK: - lives

    @Test func undoingAHitRestoresTheVictimsLife() {
        let g = makeGame()
        makeAKiller(g.vm)
        g.vm.recordThrow(value: 19, multiplier: 1) // hits B
        #expect(lives(g.vm, g.b) == 2)

        g.vm.deleteThrow()

        #expect(lives(g.vm, g.b) == 3)
        #expect(g.vm.playerLives[g.b.id] == 3)
        #expect(g.vm.currentThrow.count == 1)
    }

    @Test func undoingATripleRestoresAllThreeLives() {
        let g = makeGame()
        makeAKiller(g.vm)
        g.vm.recordThrow(value: 19, multiplier: 3) // B 3 -> 0
        g.vm.deleteThrow()

        #expect(lives(g.vm, g.b) == 3)
    }

    @Test func undoingAHitOnYourOwnNumberRestoresYourLife() {
        let g = makeGame()
        makeAKiller(g.vm)
        g.vm.recordThrow(value: 20, multiplier: 1) // A hits own number
        #expect(lives(g.vm, g.a) == 2)

        g.vm.deleteThrow()

        #expect(lives(g.vm, g.a) == 3)
    }

    // MARK: - Killer status

    @Test func undoingTheDoubleThatMadeYouAKillerClearsKillerStatus() {
        let g = makeGame()
        makeAKiller(g.vm)
        #expect(g.vm.isKiller[g.a.id] == true)

        g.vm.deleteThrow()

        #expect(g.vm.isKiller[g.a.id] == false)
        #expect(g.vm.currentThrow.isEmpty)
    }

    // MARK: - elimination

    @Test func undoingAKillBringsThePlayerBack() async {
        let g = makeGame()
        makeAKiller(g.vm)
        g.vm.recordThrow(value: 19, multiplier: 3) // eliminates B
        #expect(lives(g.vm, g.b) == 0)
        #expect(g.vm.eliminationOrder.count == 1)

        g.vm.deleteThrow()

        #expect(lives(g.vm, g.b) == 3)
        #expect(g.vm.eliminationOrder.isEmpty)
        #expect(g.vm.activePlayers.contains { $0.id == g.b.id })
    }

    @Test func aKillUndoneStraightAwayIsNotReAppliedByTheFadeTimer() async {
        let g = makeGame()
        makeAKiller(g.vm)
        g.vm.recordThrow(value: 19, multiplier: 3)
        g.vm.deleteThrow() // inside the 0.5 s fade window

        // The fade timer is 0.5 s. Wait well past it: under load (tests run in parallel) a short
        // wait can finish before the timer does, which would let this pass without testing anything.
        try? await Task.sleep(for: .milliseconds(1500))

        #expect(g.vm.eliminatedPlayers.isEmpty)
        #expect(g.vm.activePlayers.count == 3)
    }

    @Test func aPlayerBroughtBackCanBeHitAgain() {
        let g = makeGame()
        makeAKiller(g.vm)
        g.vm.recordThrow(value: 19, multiplier: 3)
        g.vm.deleteThrow()

        g.vm.recordThrow(value: 19, multiplier: 1) // B is a valid target again

        #expect(lives(g.vm, g.b) == 2)
    }

    // MARK: - which dart is undone

    @Test func deleteAlwaysUndoesTheLastDartEvenIfAnEarlierOneIsSelected() {
        let g = makeGame()
        makeAKiller(g.vm)                              // dart 1: becomes a Killer
        g.vm.recordThrow(value: 19, multiplier: 1)     // dart 2: B loses a life
        g.vm.selectedDartIndex = 0                     // user highlights dart 1

        g.vm.deleteThrow()

        // Dart 2 is undone (B's life back); dart 1 and A's Killer status are untouched.
        #expect(lives(g.vm, g.b) == 3)
        #expect(g.vm.isKiller[g.a.id] == true)
        #expect(g.vm.currentThrow.count == 1)
    }

    @Test func undoingSeveralDartsInARowUnwindsInOrder() {
        let g = makeGame()
        makeAKiller(g.vm)                              // dart 1
        g.vm.recordThrow(value: 19, multiplier: 1)     // dart 2: B 3 -> 2
        g.vm.recordThrow(value: 18, multiplier: 1)     // dart 3: C 3 -> 2

        g.vm.deleteThrow()
        #expect(lives(g.vm, g.c) == 3)
        #expect(lives(g.vm, g.b) == 2)

        g.vm.deleteThrow()
        #expect(lives(g.vm, g.b) == 3)
        #expect(g.vm.isKiller[g.a.id] == true)

        g.vm.deleteThrow()
        #expect(g.vm.isKiller[g.a.id] == false)
        #expect(g.vm.currentThrow.isEmpty)
    }

    @Test func deletingWithNothingThrownDoesNothing() {
        let g = makeGame()

        g.vm.deleteThrow()

        #expect(g.vm.currentThrow.isEmpty)
        #expect(lives(g.vm, g.a) == 3)
    }

    @Test func aMissCanBeUndoneToo() {
        let g = makeGame()
        g.vm.recordThrow(value: 5, multiplier: 1) // not a Killer yet, hits nothing
        g.vm.deleteThrow()

        #expect(g.vm.currentThrow.isEmpty)
    }

    @Test func theNextDartAfterAnUndoGoesInTheFreedSlot() {
        let g = makeGame()
        makeAKiller(g.vm)
        g.vm.recordThrow(value: 19, multiplier: 1)
        g.vm.deleteThrow()

        #expect(g.vm.selectedDartIndex == 1)
    }

    // MARK: - nothing to undo once the game is over

    @Test func canDeleteIsFalseOnceTheGameIsOver() {
        let g = makeGame()
        makeAKiller(g.vm)
        g.vm.recordThrow(value: 19, multiplier: 3)     // B out
        g.vm.recordThrow(value: 18, multiplier: 3)     // C out: A wins on this dart

        #expect(g.vm.isGameOver)
        #expect(g.vm.canDelete == false)
    }

    // MARK: - the next turn starts clean

    @Test func undoHistoryDoesNotCarryOverToTheNextPlayersTurn() {
        let g = makeGame()
        makeAKiller(g.vm)
        g.vm.recordThrow(value: 19, multiplier: 1)     // B 3 -> 2
        g.vm.recordThrow(value: 5, multiplier: 1)
        g.vm.completeTurn()                            // A's turn ends; B's turn

        g.vm.deleteThrow()                             // nothing thrown yet this turn

        #expect(lives(g.vm, g.b) == 2)                 // A's committed dart is not undone
        #expect(g.vm.currentThrow.isEmpty)
    }
}
