//
//  ScrollOffsetTestView.swift
//  DanDart
//
//  Created by Billingham Daniel on 2025-11-22.
//

import SwiftUI

struct ScrollOffsetTestView: View {
    @State private var offset: CGFloat = 0
    private let headerHeight: CGFloat = 220

    var body: some View {
        // Simple collapse progress: 0 at top, 1 after scrolling headerHeight
        let collapseDistance: CGFloat = headerHeight
        let collapseProgress = min(max(offset / collapseDistance, 0), 1)

        ZStack(alignment: .top) {
            // Header behind, flush with top, fades to black as content scrolls over it
            VStack(spacing: 0) {
                ZStack {
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text("Fixed Header")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(height: headerHeight)
                .overlay(
                    Color.black.opacity(collapseProgress)
                )

                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            // Scrolling content that can move over the header area
            TrackingScrollView(offset: $offset) {
                VStack(spacing: 16) {
                    ForEach(0..<40) { i in
                        Text("Row \(i)")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.top, headerHeight + 16)
                .padding(.bottom, 40)
            }

            // Debug overlay
            VStack {
                HStack {
                    Spacer()
                    Text(String(format: "offset: %.1f", offset))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 40)
                        .padding(.trailing, 12)
                }
                Spacer()
            }
        }
    }
}

#Preview {
    ScrollOffsetTestView()
        .frame(height: 400)
}
