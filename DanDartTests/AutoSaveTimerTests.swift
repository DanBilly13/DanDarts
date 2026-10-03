//
//  AutoSaveTimerTests.swift
//  DanDartTests
//
//  The wait-then-fire part of auto-save, run with very short durations.
//

import Foundation
import Testing
@testable import DanDart

@MainActor
struct AutoSaveTimerTests {

    private final class Counter { var count = 0 }

    @Test func firesOnceAfterTheDuration() async {
        let counter = Counter()

        await AutoSaveTimer.run(after: 0.02) { counter.count += 1 }

        #expect(counter.count == 1)
    }

    @Test func doesNotFireBeforeTheDuration() async {
        let counter = Counter()
        let task = Task { @MainActor in
            await AutoSaveTimer.run(after: 0.4) { counter.count += 1 }
        }

        try? await Task.sleep(for: .milliseconds(50))
        #expect(counter.count == 0)

        task.cancel()
        await task.value
    }

    @Test func doesNotFireWhenCancelledFirst() async {
        let counter = Counter()
        let task = Task { @MainActor in
            await AutoSaveTimer.run(after: 0.3) { counter.count += 1 }
        }

        task.cancel()
        await task.value

        #expect(counter.count == 0)
    }

    @Test func canFireAgainAfterAnEarlierRunWasCancelled() async {
        let counter = Counter()
        let cancelled = Task { @MainActor in
            await AutoSaveTimer.run(after: 0.3) { counter.count += 1 }
        }
        cancelled.cancel()
        await cancelled.value

        await AutoSaveTimer.run(after: 0.02) { counter.count += 1 }

        #expect(counter.count == 1)
    }
}
