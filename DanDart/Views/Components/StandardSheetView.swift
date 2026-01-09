//
//  StandardSheetView.swift
//  Dart Freak
//
//  Created by Windsurf on 29/10/2025.
//  Standard sheet layout wrapper for consistent presentation across the app
//

import SwiftUI

/// Standard sheet layout wrapper providing consistent header, content, and optional action button
/// Based on Edit Profile layout style for app-wide consistency
struct StandardSheetView<Content: View>: View {
    // MARK: - Properties
    let title: String
    let showCancelButton: Bool
    let cancelButtonTitle: String
    let onCancel: () -> Void
    let content: Content
    let useScrollView: Bool // Whether to wrap content in ScrollView
    
    // Optional primary action button at bottom
    let primaryActionTitle: String?
    let primaryActionEnabled: Bool
    let onPrimaryAction: (() -> Void)?
    
    // MARK: - Initializers
    
    /// Standard sheet with dismiss button only (flexible button text: "Cancel", "Back", "Close", "Done", etc.)
    init(
        title: String,
        dismissButtonTitle: String = "Cancel",
        useScrollView: Bool = true,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showCancelButton = true
        self.cancelButtonTitle = dismissButtonTitle
        self.onCancel = onDismiss
        self.content = content()
        self.useScrollView = useScrollView
        self.primaryActionTitle = nil
        self.primaryActionEnabled = false
        self.onPrimaryAction = nil
    }
    
    /// Standard sheet with dismiss button and primary action button
    init(
        title: String,
        dismissButtonTitle: String = "Cancel",
        primaryActionTitle: String,
        primaryActionEnabled: Bool = true,
        useScrollView: Bool = true,
        onDismiss: @escaping () -> Void,
        onPrimaryAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showCancelButton = true
        self.cancelButtonTitle = dismissButtonTitle
        self.onCancel = onDismiss
        self.content = content()
        self.useScrollView = useScrollView
        self.primaryActionTitle = primaryActionTitle
        self.primaryActionEnabled = primaryActionEnabled
        self.onPrimaryAction = onPrimaryAction
    }
    
    /// Standard sheet without dismiss button (swipe-to-dismiss only)
    init(
        title: String,
        showDismissButton: Bool = false,
        useScrollView: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showCancelButton = showDismissButton
        self.cancelButtonTitle = "Cancel"
        self.onCancel = {}
        self.content = content()
        self.useScrollView = useScrollView
        self.primaryActionTitle = nil
        self.primaryActionEnabled = false
        self.onPrimaryAction = nil
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Custom header with title and dismiss button
            HStack {
                if showCancelButton {
                    Button(action: onCancel) {
                        Text(cancelButtonTitle)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColor.backgroundPrimary)
            
            // Title - Large and Bold
            HStack {
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(AppColor.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(AppColor.backgroundPrimary)
            
            // Content area
            if useScrollView {
                ScrollView {
                    VStack(spacing: 16) {
                        content
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    // When there is a primary action button, keep only a small
                    // bottom padding so content (e.g. long lists) can scroll
                    // visually right up to the button container instead of
                    // leaving a large empty gap above it.
                    .padding(.bottom, primaryActionTitle != nil ? 32 : 20)
                }
            } else {
                VStack(spacing: 16) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            
            // Primary action button (if provided)
            if let actionTitle = primaryActionTitle, let action = onPrimaryAction {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    AppButton(role: .primary,
                              controlSize: .regular,
                              isDisabled: !primaryActionEnabled,
                              action: action) {
                        Text(actionTitle)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(AppColor.backgroundPrimary)
                }
            }
        }
        .background(AppColor.backgroundPrimary)
    }
}

// MARK: - Preview Helpers
#Preview("Edit Profile Style") {
    StandardSheetView(
        title: "Edit Profile",
        dismissButtonTitle: "Cancel",
        primaryActionTitle: "Save Changes",
        primaryActionEnabled: true,
        onDismiss: {},
        onPrimaryAction: {}
    ) {
        VStack(spacing: 20) {
            // Profile Picture Section
            VStack(spacing: 12) {
                Text("Profile Picture")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 12) {
                    ForEach(0..<5) { _ in
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                    }
                }
            }
            
            // Name Field
            VStack(spacing: 8) {
                Text("Name")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("", text: .constant("Daniel Billingham"))
                    .padding(12)
                    .background(AppColor.inputBackground)
                    .cornerRadius(10)
            }
            
            // Nickname Field
            VStack(spacing: 8) {
                Text("Nickname")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("", text: .constant("@danbillman"))
                    .padding(12)
                    .background(AppColor.inputBackground)
                    .cornerRadius(10)
            }
            
            // Email Field
            VStack(spacing: 8) {
                Text("Email")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("", text: .constant("danbillingham@gmail.com"))
                    .padding(12)
                    .background(AppColor.inputBackground)
                    .cornerRadius(10)
            }
        }
    }
}

#Preview("Instructions Style") {
    StandardSheetView(
        title: "Instructions",
        showDismissButton: false
    ) {
        VStack(alignment: .leading, spacing: 16) {
            Text("301")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(AppColor.brandPrimary)
            
            Text("A Classic Countdown Game")
                .font(.system(size: 17))
                .foregroundColor(.white.opacity(0.7))
            
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.green)
                Text("2 or more")
                    .foregroundColor(.white)
            }
            
            Text("How to Play")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColor.brandPrimary)
                .padding(.top, 8)
            
            Text("Each player starts with a score of 301. Players take turns throwing three darts per round and subtract the total from their score.")
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Find Friends Style") {
    StandardSheetView(
        title: "Find Friends",
        dismissButtonTitle: "Back",
        onDismiss: {}
    ) {
        VStack(spacing: 16) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                TextField("Search by name or @handle", text: .constant(""))
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(AppColor.inputBackground)
            .cornerRadius(10)
            
            // Empty state
            VStack(spacing: 16) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.top, 60)
                
                Text("Find Friends")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Search by name or @handle to add friends")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
