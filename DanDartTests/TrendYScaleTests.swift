//
//  TrendYScaleTests.swift
//  DanDartTests
//
//  The fitted y-axis of the 3-dart average trend chart.
//

import Foundation
import Testing
@testable import DanDart

struct TrendYScaleTests {

    @Test func noDataFallsBackToTheFullAxis() {
        #expect(TrendYScale.fitting([]) == .full)
    }

    @Test func aSingleValueGetsATightAxisAroundIt() {
        let scale = TrendYScale.fitting([56.44])

        #expect(scale.min == 50)
        #expect(scale.max == 70)
        #expect(scale.ticks == [50, 60, 70])
    }

    @Test func aModerateSpreadSnapsToRoundTicksWithPadding() {
        let scale = TrendYScale.fitting([40, 80])

        #expect(scale.min == 20)
        #expect(scale.max == 100)
        #expect(scale.ticks == [20, 40, 60, 80, 100])
    }

    @Test func aVeryWideSpreadUsesTheFullAxis() {
        #expect(TrendYScale.fitting([20, 150]) == .full)
    }

    @Test func theAxisNeverGoesBelowZero() {
        let scale = TrendYScale.fitting([5, 15])

        #expect(scale.min == 0)
        #expect(scale.ticks == [0, 10, 20])
    }

    @Test func theAxisNeverGoesAbove180() {
        let scale = TrendYScale.fitting([175, 180])

        #expect(scale.max == 180)
        #expect(scale.ticks == [170, 180])
    }

    @Test func everyValueInTheSeriesLandsInsideTheAxis() {
        let values = [31.2, 47.9, 66.0, 58.4]
        let scale = TrendYScale.fitting(values)

        #expect(values.allSatisfy { $0 >= scale.min && $0 <= scale.max })
    }

    @Test func fractionMapsTheEndsAndClampsOutliers() {
        let scale = TrendYScale(min: 50, max: 70, ticks: [50, 60, 70])

        #expect(scale.fraction(for: 50) == 0)
        #expect(scale.fraction(for: 60) == 0.5)
        #expect(scale.fraction(for: 70) == 1)
        #expect(scale.fraction(for: 200) == 1)
        #expect(scale.fraction(for: 0) == 0)
    }

    @Test func aSharedScaleBuiltFromTwoSeriesFitsBoth() {
        let matches = [60.0, 85.0]
        let practice = [30.0]
        let shared = TrendYScale.fitting(matches + practice)

        #expect((matches + practice).allSatisfy { $0 >= shared.min && $0 <= shared.max })
    }
}
