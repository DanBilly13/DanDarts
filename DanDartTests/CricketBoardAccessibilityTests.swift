//
//  CricketBoardAccessibilityTests.swift
//  DanDartTests
//
//  The VoiceOver wording for the Cricket board: one sentence per target row.
//

import SwiftUI
import Testing
@testable import DanDart

struct CricketBoardAccessibilityTests {

    private func column(_ name: String, marks: [CricketTarget: Int] = [:], isCurrent: Bool = false) -> CricketBoardColumn {
        CricketBoardColumn(id: UUID(), name: name, avatarURL: nil, color: .white,
                           markCounts: marks, points: 0, isCurrent: isCurrent)
    }

    @Test func rowValueSaysClosedOneMarkAndNoMarksForEachPlayer() {
        let columns = [
            column("Dan", marks: [.twenty: 3]),
            column("Sam", marks: [.twenty: 1]),
            column("Alex")
        ]

        let value = CricketBoardAccessibility.rowValue(columns: columns, target: .twenty, isDead: false)

        #expect(value == "Dan closed, Sam 1 mark, Alex no marks")
    }

    @Test func twoMarksArePlural() {
        let columns = [column("Dan", marks: [.nineteen: 2]), column("Sam")]

        let value = CricketBoardAccessibility.rowValue(columns: columns, target: .nineteen, isDead: false)

        #expect(value == "Dan 2 marks, Sam no marks")
    }

    @Test func aDeadRowSaysNobodyCanScore() {
        let columns = [column("Dan", marks: [.fifteen: 3]), column("Sam", marks: [.fifteen: 3])]

        let value = CricketBoardAccessibility.rowValue(columns: columns, target: .fifteen, isDead: true)

        #expect(value == "Dan closed, Sam closed, dead, nobody can score")
    }

    @Test func theBullIsLabelledBullAndNumbersKeepTheirValue() {
        #expect(CricketBoardAccessibility.targetLabel(.bull) == "Bull")
        #expect(CricketBoardAccessibility.targetLabel(.twenty) == "20")
        #expect(CricketBoardAccessibility.targetLabel(.fifteen) == "15")
    }

    @Test func theHeaderSaysThrowingForTheCurrentPlayerOnly() {
        #expect(CricketBoardAccessibility.headerLabel(for: column("Dan", isCurrent: true)) == "Dan, 0 points, throwing")
        #expect(CricketBoardAccessibility.headerLabel(for: column("Sam")) == "Sam, 0 points")
    }
}
