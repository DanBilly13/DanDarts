//
//  CricketKeypad.swift
//  Dart Freak
//
//  The Cricket input pad: 20 to 15, the outer bull (25), the inner bull (Bull), Miss and
//  delete, in the same 5-column grid and button style as the other games. Tap a number for a
//  single; long-press for a double or treble. 25 and Bull have no menu: outer bull is one
//  mark, inner bull is two.
//

import SwiftUI

struct CricketKeypad: View {
    let onScoreSelected: (Int, ScoreType) -> Void
    let onDelete: () -> Void
    let canDelete: Bool

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
            ForEach([20, 19, 18, 17, 16, 15], id: \.self) { number in
                ScoringButton(title: "\(number)", baseValue: number, onScoreSelected: onScoreSelected)
            }

            ScoringButton(title: "25", baseValue: 25, onScoreSelected: onScoreSelected, allowsMenu: false)
            ScoringButton(title: "Bull", baseValue: 50, onScoreSelected: onScoreSelected)
            ScoringButton(title: "Miss", baseValue: 0, onScoreSelected: onScoreSelected)

            DeleteButton(onDelete: onDelete, isDisabled: !canDelete)
        }
    }
}

#Preview("Cricket Keypad") {
    CricketKeypad(onScoreSelected: { _, _ in }, onDelete: {}, canDelete: true)
        .padding()
        .background(AppColor.backgroundPrimary)
}
