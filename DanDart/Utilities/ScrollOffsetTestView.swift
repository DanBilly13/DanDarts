//
//  ScrollOffsetTestView.swift
//  DanDart
//
//  Created by Billingham Daniel on 2025-11-22.
//

import SwiftUI

// Observable wrapper for counter so UI updates work inside TrackingScrollView
class CounterState: ObservableObject {
    @Published var value: Int = 0
}

struct ScrollOffsetTestView: View {
    @State private var offset: CGFloat = 0
    private let headerHeight: CGFloat = 220
    @StateObject private var counterState = CounterState()
    @State private var showCounterSheet: Bool = false

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
                    // Simple counter box + buttons
                    VStack(spacing: 8) {
                        Text("Counter: \(counterState.value)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.yellow.opacity(0.8))
                            .cornerRadius(12)

                        HStack(spacing: 12) {
                            Button {
                                print("🟢 [DIRECT] Before: counter = \(counterState.value)")
                                counterState.value += 1
                                print("🟢 [DIRECT] After: counter = \(counterState.value)")
                            } label: {
                                Text("+1 (direct)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.green.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }

                            Button {
                                print("🔵 [SHEET] Opening sheet, counter = \(counterState.value)")
                                showCounterSheet = true
                            } label: {
                                Text("Open Counter Sheet")
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }

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
            .environmentObject(counterState)

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
        .sheet(isPresented: $showCounterSheet) {
            VStack(spacing: 24) {
                Text("Counter Sheet")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("Current value: \(counterState.value)")
                    .font(.system(size: 18, weight: .medium))

                Button {
                    print("🟡 [SHEET +1] Before: counter = \(counterState.value)")
                    counterState.value += 1
                    print("🟡 [SHEET +1] After: counter = \(counterState.value)")
                } label: {
                    Text("+1")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button {
                    print("🔴 [SHEET DONE] Closing sheet, counter = \(counterState.value)")
                    showCounterSheet = false
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .regular))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    ScrollOffsetTestView()
        .frame(height: 400)
}
