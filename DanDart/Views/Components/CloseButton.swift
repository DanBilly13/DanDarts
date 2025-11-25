//
//  CloseButton.swift
//  DanDart
//
//  Created by Billingham Daniel on 2025-11-23.
//

import SwiftUI

struct CloseButton: View {
    var size: CGFloat = 24
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    AppColor.inputBackground,              // circle background
                    AppColor.interactivePrimaryBackground  // X color
                )
                .font(.system(size: size, weight: .semibold))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CloseButton(action: {})
}
