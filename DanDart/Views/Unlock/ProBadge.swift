//
//  ProBadge.swift
//  DanDart
//
//  The small "PRO" chip on anything that needs DartFreak Pro (game cards, history rows).
//  One signal only: the chip says what it is, the button underneath still says what it does.
//

import SwiftUI

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(0.6)
            .foregroundColor(AppColor.justWhite)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.55), in: Capsule())
            .accessibilityLabel("Needs DartFreak Pro")
    }
}
