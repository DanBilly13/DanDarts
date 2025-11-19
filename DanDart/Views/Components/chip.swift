//
//  chip.swift
//  DanDart
//
//  Created by Billingham Daniel on 2025-11-03.
//

import SwiftUI

struct Chip: View {
    let title: String
    var foregroundColor: Color = Color("BackgroundPrimary")
    var backgroundColor: Color = Color("AccentPrimary")
    
    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
    }
}

#Preview {
    Chip(title: "Example")
}
