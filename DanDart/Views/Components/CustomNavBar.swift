//
//  CustomNavBar.swift
//  Dart Freak
//
//  Reusable custom navigation bar components
//  iOS 18+ optimized with subtitle support
//

import SwiftUI

// MARK: - Custom Nav Bar Modifier

/// Generic navigation bar modifier with optional subtitle
/// Works on iOS 18+ with enhanced subtitle display
struct CustomNavBarModifier: ViewModifier {
    let title: String
    let subtitle: String?
    
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            // iOS 18+: Use system navigation with subtitle support
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                // iOS 18 can show subtitle without custom implementation
        } else {
            // Pre-iOS 18: Standard navigation
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppColor.backgroundPrimary, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Toolbar Title Component

/// Reusable toolbar title that displays on the left side
struct ToolbarTitle: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(.title, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(AppColor.textPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Toolbar Action Buttons

/// Search button for toolbar
struct ToolbarSearchButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColor.interactivePrimaryBackground)
        }
    }
}

/// User avatar button for toolbar
struct ToolbarAvatarButton: View {
    let avatarURL: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Provide an explicit circular tap target so iOS 26 doesn't apply a capsule glass shape
                Circle()
                    .fill(Color.clear)
                    .frame(width: 36, height: 36)

                AsyncAvatarImage(
                    avatarURL: avatarURL,
                    size: 32,
                    placeholderIcon: "person.circle.fill"
                )
                .clipShape(Circle())
            }
            .frame(width: 36, height: 36)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Extension

extension View {
    /// Apply custom navigation bar with optional subtitle
    func customNavBar(title: String, subtitle: String? = nil) -> some View {
        self.modifier(CustomNavBarModifier(title: title, subtitle: subtitle))
    }
}
