//
//  TrendYScale.swift
//  Dart Freak
//
//  The y-axis of the 3-dart average trend chart, fitted to the data.
//

import Foundation

/// The y-axis of the 3-dart average trend: `min`...`max`, with a label at each of `ticks`.
struct TrendYScale: Equatable {
    let min: Double
    let max: Double
    let ticks: [Int]

    /// 0 at `min`, 1 at `max`; values outside the axis are clamped onto it.
    func fraction(for value: Double) -> Double {
        let clamped = Swift.min(Swift.max(value, min), max)
        return (clamped - min) / (max - min)
    }

    /// The fixed 0-180 axis, used when there is nothing to fit to.
    static let full = TrendYScale(min: 0, max: 180, ticks: [0, 60, 120, 180])

    private static let absoluteMax = 180.0 // a 3-dart average can never exceed a maximum visit
    private static let maxIntervals = 4
    private static let steps = [10, 20, 30, 60] // all divide 180, so capping at it keeps ticks on the grid

    /// Fits the axis to `averages`: padded a little so the line doesn't touch the
    /// edges, snapped to a round tick step, floored at 0 and capped at 180, instead
    /// of always drawing 0-180, which squashes a typical 40-80 average into the
    /// bottom of the chart. Pass the values from every chart that should be directly
    /// comparable (e.g. match and practice trends) so they share one scale.
    static func fitting(_ averages: [Double]) -> TrendYScale {
        guard let lo = averages.min(), let hi = averages.max() else { return .full }

        let pad = Swift.max((hi - lo) * 0.15, 5.0)
        let rawBottom = Swift.max(lo - pad, 0.0)
        let rawTop = Swift.min(hi + pad, absoluteMax)

        for step in steps {
            let stepD = Double(step)
            var bottom = (rawBottom / stepD).rounded(.down) * stepD
            var top = Swift.min((rawTop / stepD).rounded(.up) * stepD, absoluteMax)
            if top - bottom < stepD {
                // A flat or single-value series: give the axis at least one full step.
                if bottom + stepD <= absoluteMax { top = bottom + stepD } else { bottom = top - stepD }
            }
            if (top - bottom) / stepD <= Double(maxIntervals) || step == steps.last {
                return TrendYScale(min: bottom, max: top, ticks: Array(stride(from: Int(bottom), through: Int(top), by: step)))
            }
        }
        return .full
    }
}
