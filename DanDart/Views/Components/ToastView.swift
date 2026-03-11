//
//  ToastView.swift
//  DanDart
//
//  Reusable toast notification component
//  Displays centered toast with emoji and message
//

import SwiftUI
import UIKit

struct ToastView: View {
    let symbolName: String
    let message: String
    let isVisible: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbolName)
                .font(.system(size: 48))
                .foregroundStyle(AppColor.textPrimary)
            
            Text(message)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.regular)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(width: 240, height: 141)
        .background(AppColor.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .offset(y: isVisible ? 0 : 50)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
    }
}

#Preview("Decline Toast") {
    ZStack {
        AppColor.backgroundPrimary
            .ignoresSafeArea()
        
        ToastView(
            symbolName: "hand.raised.fill",
            message: "Neil declined the match",
            isVisible: true
        )
    }
}

#Preview("Cancel Toast") {
    ZStack {
        AppColor.backgroundPrimary
            .ignoresSafeArea()
        
        ToastView(
            symbolName: "xmark.circle.fill",
            message: "Match with Sarah cancelled",
            isVisible: true
        )
    }
}

#Preview("Success Toast") {
    ZStack {
        AppColor.backgroundPrimary
            .ignoresSafeArea()
        
        ToastView(
            symbolName: "checkmark.circle.fill",
            message: "Match completed!",
            isVisible: true
        )
    }
}

#Preview("Error Toast") {
    ZStack {
        AppColor.backgroundPrimary
            .ignoresSafeArea()
        
        ToastView(
            symbolName: "exclamationmark.triangle.fill",
            message: "Connection failed",
            isVisible: true
        )
    }
}

#Preview("Hidden State") {
    ZStack {
        AppColor.backgroundPrimary
            .ignoresSafeArea()
        
        ToastView(
            symbolName: "hand.raised.fill",
            message: "This toast is hidden",
            isVisible: false
        )
    }
}
