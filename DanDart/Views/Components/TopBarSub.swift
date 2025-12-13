//
//  TopBarSub.swift
//  DanDart
//
//  Reusable top bar with title, subtitle, and trailing action button
//  Used for navigation views like match details
//

import SwiftUI

// MARK: - Top Bar with Subtitle

/// Reusable top bar component with title, subtitle, and trailing action
/// Designed for navigation views (not sheets)
struct TopBarSub<TrailingButton: View>: ToolbarContent {
    let title: String
    let subtitle: String?
    let trailingButton: TrailingButton
    
    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailingButton: () -> TrailingButton
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailingButton = trailingButton()
    }
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(AppColor.textPrimary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            trailingButton
        }
    }
}

// MARK: - Convenience Init without Trailing Button

extension TopBarSub where TrailingButton == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailingButton = EmptyView()
    }
}

// MARK: - Common Trailing Buttons

/// X button for dismissing/going back
struct TopBarCloseButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColor.interactivePrimaryBackground)
        }
    }
}

/// Share button
struct TopBarShareButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColor.interactivePrimaryBackground)
        }
    }
}

/// Edit button
struct TopBarEditButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColor.interactivePrimaryBackground)
        }
    }
}
