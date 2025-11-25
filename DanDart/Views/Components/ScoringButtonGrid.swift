//
//  ScoringButtonGrid.swift
//  DanDart
//
//  Reusable dartboard scoring input grid with long-press for doubles/triples
//  Used across multiple dart game modes
//

import SwiftUI

// MARK: - Scoring Button Grid

struct ScoringButtonGrid: View {
    let onScoreSelected: (Int, ScoreType) -> Void
    let showBustButton: Bool
    
    // Sequential numbers 1-20
    private let dartboardNumbers = Array(1...20)
    
    init(onScoreSelected: @escaping (Int, ScoreType) -> Void, showBustButton: Bool = true) {
        self.onScoreSelected = onScoreSelected
        self.showBustButton = showBustButton
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
            // Numbers 1-20
            ForEach(dartboardNumbers, id: \.self) { number in
                ScoringButton(
                    title: "\(number)",
                    baseValue: number,
                    onScoreSelected: onScoreSelected
                )
            }
            
            // 25
            ScoringButton(
                title: "25",
                baseValue: 25,
                onScoreSelected: onScoreSelected
            )
            
            // Bull
            ScoringButton(
                title: "Bull",
                baseValue: 50,
                onScoreSelected: onScoreSelected
            )
            
            // Miss
            ScoringButton(
                title: "Miss",
                baseValue: 0,
                onScoreSelected: onScoreSelected
            )
            
            // Bust (conditionally shown)
            if showBustButton {
                ScoringButton(
                    title: "Bust",
                    baseValue: -1, // -1 indicates bust
                    onScoreSelected: onScoreSelected
                )
            }
        }
    }
}

// MARK: - Scoring Button Component

struct ScoringButton: View {
    let title: String
    let baseValue: Int
    let onScoreSelected: (Int, ScoreType) -> Void
    
    @State private var isPressed = false
    @State private var isHighlighted = false
    @StateObject private var menuCoordinator = MenuCoordinator.shared
    @State private var buttonFrame: CGRect = .zero
    
    // Unique identifier for this button
    private var buttonId: String {
        "\(baseValue)-\(title)"
    }
    
    // Check if this button's menu is active
    private var isMenuActive: Bool {
        menuCoordinator.activeMenuId == buttonId
    }
    
    // Check if this button should be blurred (another menu is active)
    private var shouldBlur: Bool {
        menuCoordinator.activeMenuId != nil && menuCoordinator.activeMenuId != buttonId
    }
    
    // Calculate optimal menu position like Apple's context menu
    private var menuOffset: CGSize {
        let menuWidth: CGFloat = 120
        let menuHeight: CGFloat = 132 // 3 buttons × 44pt each
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        let buttonCenterX = buttonFrame.midX
        let buttonCenterY = buttonFrame.midY
        
        // Default positioning - above and centered
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = -menuHeight/2 - 32 - 16 // 16pt gap above button
        
        // Check if menu would go off left edge
        if buttonCenterX - menuWidth/2 < 16 {
            offsetX = 16 - buttonCenterX + menuWidth/2
        }
        
        // Check if menu would go off right edge
        if buttonCenterX + menuWidth/2 > screenWidth - 16 {
            offsetX = (screenWidth - 16) - buttonCenterX - menuWidth/2
        }
        
        // Check if menu would go off top edge
        if buttonCenterY + offsetY < 60 { // Account for safe area
            offsetY = 80 // Position below button instead
        }
        
        return CGSize(width: offsetX, height: offsetY)
    }
    
    // Don't show context menu for special buttons
    private var canShowContextMenu: Bool {
        baseValue > 0 && baseValue != 50 // Exclude Miss, Bust, and Bull
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Bull button (50)
                if baseValue == 50 {
                    // Two-circle design: blue inner, white outer ring
                    // When pressed: outer ring fades out, inner expands to full size
                    ZStack {
                        // Outer circle - AccentQuinary (white) with dynamic opacity
                        // Fades out when pressed to reveal solid blue button
                        Circle()
                            .fill(AppColor.player1.opacity(isHighlighted ? 1.0 : 0.8))
                            .frame(width: 64, height: 64)
                        
                        // Inner circle - InputBackground, fades out when pressed
                        Circle()
                            .fill(AppColor.player1)
                            .frame(width: 52, height: 52)
                            .opacity(isHighlighted ? 0.0 : 1.0)
                        
                        Text(title)
                            .font(.system(size: 17, weight: .semibold, design: .default))
                            .foregroundColor(isHighlighted ? AppColor.justWhite : AppColor.justWhite)
                    }
                } else if baseValue == 25 {
                    // Two-circle design: dark inner, green outer ring
                    // When pressed: outer fills to 100%, inner fades out, text becomes black
                    ZStack {
                        // Outer circle - AccentSecondary (green) with dynamic opacity
                        // Default: 60% opacity, Pressed: 100% for solid green button
                        Circle()
                            .fill(AppColor.player2.opacity(isHighlighted ? 1.0 : 0.7))
                            .frame(width: 64, height: 64)
                        
                        // Inner circle - InputBackground, fades out when pressed
                        Circle()
                            .fill(AppColor.player2)
                            .frame(width: 52, height: 52)
                            .opacity(isHighlighted ? 0.0 : 1.0)
                        
                        Text(title)
                            .font(.system(size: 18, weight: .bold, design: .monospaced
                                         ))
                            .foregroundColor(isHighlighted ? AppColor.justBlack : AppColor.justBlack)
                    }
                } else if baseValue == 0 || baseValue == -1 {
                    // Miss and Bust buttons - same two-circle design as numbers
                    ZStack {
                        // Outer circle - AppColor.interactiveTertiaryBackground with dynamic opacity
                        Circle()
                            .fill(AppColor.interactiveTertiaryBackground.opacity(isHighlighted ? 1.0 : 0.5))
                            .frame(width: 64, height: 64)
                        
                        // Inner circle - InputBackground, fades out when pressed
                        Circle()
                            .fill(AppColor.inputBackground)
                            .frame(width: 52, height: 52)
                            .opacity(isHighlighted ? 1.0 : 1.0)
                        
                        Text(title)
                            .font(.system(size: 17, weight: .semibold, design: .default))
                            .foregroundColor(isHighlighted ? AppColor.justWhite : AppColor.justWhite)
                    }
                } else {
                    // Standard buttons (1-20)
                    // Two-circle design: outer fills in, inner fades out, text changes color
                    ZStack {
                        // Outer circle - AppColor.interactiveTertiaryBackground with dynamic opacity
                        // Default: 15% opacity for subtle ring, Pressed: 100% for solid button
                        Circle()
                            .fill(AppColor.interactiveTertiaryBackground.opacity(isHighlighted ? 1.0 : 0.9))
                            .frame(width: 64, height: 64)
                        
                        // Inner circle - InputBackground, fades out when pressed
                        Circle()
                            .fill(AppColor.inputBackground)
                            .frame(width: 58, height: 58)
                            .opacity(isHighlighted ? 0.0 : 0.0)
                        
                        Text(title)
                            .font(.system(size: 20, weight: .bold, design: .monospaced
                                         ))
                            .foregroundColor(AppColor.justBlack)
                    }
                }
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .blur(radius: shouldBlur ? 4 : 0)
            .opacity(shouldBlur ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: shouldBlur)
            .onAppear {
                // Capture button frame in global coordinates
                buttonFrame = geometry.frame(in: .global)
            }
            .onChange(of: geometry.frame(in: .global)) { newFrame in
                buttonFrame = newFrame
            }
        }
        .frame(width: 64, height: 64)
        .onTapGesture {
            // If any menu is open, just close it without scoring
            if menuCoordinator.activeMenuId != nil {
                menuCoordinator.hideMenu()
                return
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Hold for 1 second, then fade out (color change happens on press down)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isHighlighted = false
                }
            }
            
            // Default to single
            onScoreSelected(baseValue, .single)
        }
        .onLongPressGesture(minimumDuration: 0.25) {
            if canShowContextMenu {
                // Haptic feedback for long press
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    menuCoordinator.showMenu(for: buttonId)
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = true
                            isHighlighted = true // Color change on press down
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
        .overlay(
            // Custom dark-themed popup menu
            Group {
                if isMenuActive {
                    VStack(spacing: 1) {
                        // Triple option (top)
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                            impactFeedback.impactOccurred()
                            isHighlighted = false
                            onScoreSelected(baseValue, .triple)
                            withAnimation(.easeOut(duration: 0.2)) {
                                menuCoordinator.hideMenu()
                            }
                        }) {
                            Text("Triple")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppColor.interactivePrimaryBackground)
                        }
                        
                        // Double option (middle)
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            isHighlighted = false
                            onScoreSelected(baseValue, .double)
                            withAnimation(.easeOut(duration: 0.2)) {
                                menuCoordinator.hideMenu()
                            }
                        }) {
                            Text("Double")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppColor.interactivePrimaryBackground)
                        }
                        
                        // Single option (bottom)
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            isHighlighted = false
                            onScoreSelected(baseValue, .single)
                            withAnimation(.easeOut(duration: 0.2)) {
                                menuCoordinator.hideMenu()
                            }
                        }) {
                            Text("Single")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppColor.interactivePrimaryBackground)
                        }
                    }
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                    .frame(width: 120)
                    .offset(menuOffset)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                    .zIndex(1000)
                }
            }
        )
    }
}

#Preview("Scoring Grid") {
    ScoringButtonGrid(onScoreSelected: { value, type in
        print("Selected score: \(value), type: \(type)")
    }, showBustButton: true)
    .padding()
    .background(AppColor.backgroundPrimary)
}
