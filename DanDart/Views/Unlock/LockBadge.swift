//
//  LockBadge.swift
//  DanDart
//
//  Small lock pill drawn on game cards that need DartFreak Full.
//

import SwiftUI

struct LockBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
            Text("Full")
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(AppColor.justWhite)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.55), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Locked. Needs DartFreak Full.")
    }
}
