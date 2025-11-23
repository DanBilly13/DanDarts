//
//  ScrollOffsetTestView.swift
//  DanDart
//
//  Created by Billingham Daniel on 2025-11-22.
//

import SwiftUI

// Observable wrapper for items so UI updates work inside TrackingScrollView
class ItemsState: ObservableObject {
    @Published var items: [String] = []
}

struct ScrollOffsetTestView: View {
    @State private var offset: CGFloat = 0
    private let headerHeight: CGFloat = 220
    @StateObject private var itemsState = ItemsState()
    @State private var showAddSheet: Bool = false

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
                VStack(spacing: 0) {
                    // Top spacer to push content below header
                    Spacer()
                        .frame(height: headerHeight + 16)
                    
                    VStack(spacing: 16) {
                    // Header section
                    VStack(spacing: 8) {
                        Text("Test Section")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            print("🔵 [SHEET] Opening add sheet, items = \(itemsState.items.count)")
                            showAddSheet = true
                        } label: {
                            Text("Add Items")
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    
                    // Dynamic items section (like player cards)
                    if !itemsState.items.isEmpty {
                        VStack(spacing: 12) {
                            Text("Items (\(itemsState.items.count))")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ForEach(itemsState.items, id: \.self) { item in
                                HStack {
                                    Text(item)
                                        .font(.system(size: 16, weight: .medium))
                                    Spacer()
                                    Text("✓")
                                        .foregroundColor(.green)
                                }
                                .padding()
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Instructions section (like game instructions)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Instructions")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        
                        Text("This is a long instruction text that should not be truncated. It contains multiple lines of text to simulate the game instructions. The goal is to see if this text gets cut off when items are added above it. This should remain fully visible and scrollable at all times.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(0..<20) { i in
                        Text("Row \(i)")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .environmentObject(itemsState)

            // Debug overlay
            VStack {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "offset: %.1f", offset))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                        Text("items: \(itemsState.items.count)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                        Text("topPad: \(Int(headerHeight + 16))")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .padding(6)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 40)
                    .padding(.trailing, 12)
                }
                Spacer()
            }
            
            // Visual marker showing where content should start
            VStack {
                Rectangle()
                    .fill(Color.red.opacity(0.8))
                    .frame(height: 2)
                    .offset(y: headerHeight + 16 - offset)
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .sheet(isPresented: $showAddSheet) {
            VStack(spacing: 24) {
                Text("Add Items")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("Current items: \(itemsState.items.count)")
                    .font(.system(size: 18, weight: .medium))

                Button {
                    let newItem = "Item \(itemsState.items.count + 1)"
                    print("🟡 [SHEET ADD] Adding: \(newItem)")
                    itemsState.items.append(newItem)
                    print("🟡 [SHEET ADD] Total items: \(itemsState.items.count)")
                } label: {
                    Text("Add Item")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button {
                    print("🔴 [SHEET DONE] Closing sheet, items = \(itemsState.items.count)")
                    showAddSheet = false
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
