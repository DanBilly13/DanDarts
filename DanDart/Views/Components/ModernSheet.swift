//
//  ModernSheet.swift
//  DanDart
//
//  Reusable modern sheet presentation with iOS 18+ optimizations
//

import SwiftUI

// MARK: - Modern Sheet Container

/// Container view that wraps content with a navigation stack and title
struct ModernSheetContainer<Content: View, TrailingButtons: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String?
    let subtitle: String?
    let showCloseButton: Bool
    let trailingButtons: TrailingButtons?
    let content: Content
    
    init(
        title: String?,
        subtitle: String? = nil,
        showCloseButton: Bool = true,
        @ViewBuilder trailingButtons: () -> TrailingButtons,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showCloseButton = showCloseButton
        self.trailingButtons = trailingButtons()
        self.content = content()
    }
    
    // Convenience init without trailing buttons
    init(
        title: String?,
        subtitle: String? = nil,
        showCloseButton: Bool = true,
        @ViewBuilder content: () -> Content
    ) where TrailingButtons == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.showCloseButton = showCloseButton
        self.trailingButtons = nil
        self.content = content()
    }
    
    var body: some View {
        if let title = title {
            NavigationStack {
                content
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(true)
                    .toolbarRole(.editor)
                    .toolbar {
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
                        
                        ToolbarItemGroup(placement: .navigationBarTrailing) {
                            // Custom trailing buttons (each one becomes its own trailing item)
                            if let trailingButtons = trailingButtons {
                                trailingButtons
                            }

                            // Close button (its own trailing item)
                            if showCloseButton {
                                Button(action: { dismiss() }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppColor.interactivePrimaryBackground)
                                }
                                .accessibilityLabel("Close")
                            }
                        }
                    }
                    .toolbarBackground(.automatic, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .background(Color.clear)
        } else {
            // No title - just show content
            content
        }
    }
}

// MARK: - Modern Sheet Modifier

/// Applies modern sheet styling with iOS 18+ optimizations
struct ModernSheetModifier: ViewModifier {
    let title: String?
    let subtitle: String?
    let showCloseButton: Bool
    let detents: Set<PresentationDetent>
    let dragIndicator: Visibility
    let background: Color?
    let contentInteraction: PresentationContentInteraction
    
    init(
        title: String? = nil,
        subtitle: String? = nil,
        showCloseButton: Bool = true,
        detents: Set<PresentationDetent> = [.medium, .large],
        dragIndicator: Visibility = .visible,
        background: Color? = AppColor.backgroundPrimary,
        contentInteraction: PresentationContentInteraction = .scrolls
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showCloseButton = showCloseButton
        self.detents = detents
        self.dragIndicator = dragIndicator
        self.background = background
        self.contentInteraction = contentInteraction
    }
    
    func body(content: Content) -> some View {
        ModernSheetContainer(title: title, subtitle: subtitle, showCloseButton: showCloseButton) {
            content
        }
        .modifier(PresentationStyleModifier(
            detents: detents,
            dragIndicator: dragIndicator,
            background: background,
            contentInteraction: contentInteraction
        ))
    }
}

// MARK: - Presentation Style Modifier

/// Applies presentation styling separately
private struct PresentationStyleModifier: ViewModifier {
    let detents: Set<PresentationDetent>
    let dragIndicator: Visibility
    let background: Color?
    let contentInteraction: PresentationContentInteraction
    
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .presentationDetents(detents)
                .presentationBackground(background ?? AppColor.backgroundPrimary)
                .presentationDragIndicator(dragIndicator)
                .presentationContentInteraction(contentInteraction)
        } else {
            // iOS 16-17: Basic sheet presentation
            content
                .presentationDetents(detents)
                .presentationDragIndicator(dragIndicator)
        }
    }
}

// MARK: - View Extension

extension View {
    /// Apply modern sheet styling with iOS 18+ optimizations
    ///
    /// - Parameters:
    ///   - title: Optional title to display in navigation bar
    ///   - subtitle: Optional subtitle to display below title
    ///   - showCloseButton: Show close button in navigation bar (default: true)
    ///   - detents: Sheet size options (default: [.medium, .large])
    ///   - dragIndicator: Show drag indicator (default: .visible)
    ///   - background: Sheet background color (default: AppColor.backgroundPrimary)
    ///   - contentInteraction: How content interacts with gestures (default: .scrolls)
    func modernSheet(
        title: String? = nil,
        subtitle: String? = nil,
        showCloseButton: Bool = true,
        detents: Set<PresentationDetent> = [.medium, .large],
        dragIndicator: Visibility = .visible,
        background: Color? = AppColor.backgroundPrimary,
        contentInteraction: PresentationContentInteraction = .scrolls
    ) -> some View {
        self.modifier(ModernSheetModifier(
            title: title,
            subtitle: subtitle,
            showCloseButton: showCloseButton,
            detents: detents,
            dragIndicator: dragIndicator,
            background: background,
            contentInteraction: contentInteraction
        ))
    }
    
    /// Apply modern sheet styling with custom trailing buttons
    ///
    /// - Parameters:
    ///   - title: Optional title to display in navigation bar
    ///   - subtitle: Optional subtitle to display below title
    ///   - showCloseButton: Show close button in navigation bar (default: true)
    ///   - detents: Sheet size options (default: [.medium, .large])
    ///   - dragIndicator: Show drag indicator (default: .visible)
    ///   - background: Sheet background color (default: AppColor.backgroundPrimary)
    ///   - contentInteraction: How content interacts with gestures (default: .scrolls)
    ///   - trailingButtons: Custom buttons to show before close button
    func modernSheet<TrailingButtons: View>(
        title: String? = nil,
        subtitle: String? = nil,
        showCloseButton: Bool = true,
        detents: Set<PresentationDetent> = [.medium, .large],
        dragIndicator: Visibility = .visible,
        background: Color? = AppColor.backgroundPrimary,
        contentInteraction: PresentationContentInteraction = .scrolls,
        @ViewBuilder trailingButtons: @escaping () -> TrailingButtons
    ) -> some View {
        ModernSheetContainer(
            title: title,
            subtitle: subtitle,
            showCloseButton: showCloseButton,
            trailingButtons: trailingButtons,
            content: { self }
        )
        .modifier(PresentationStyleModifier(
            detents: detents,
            dragIndicator: dragIndicator,
            background: background,
            contentInteraction: contentInteraction
        ))
    }
}

// MARK: - Preview

#Preview("Modern Sheet - Medium") {
    @Previewable @State var showSheet = true
    
    Color.clear
        .sheet(isPresented: $showSheet) {
            VStack(spacing: 20) {
                Text("Modern Sheet")
                    .font(.title2.bold())
                    .foregroundColor(AppColor.textPrimary)
                
                Text("Drag to resize or dismiss")
                    .font(.body)
                    .foregroundColor(AppColor.textSecondary)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.backgroundPrimary)
            .modernSheet(detents: [.medium, .large])
        }
}

#Preview("Modern Sheet - Large Only") {
    @Previewable @State var showSheet = true
    
    Color.clear
        .sheet(isPresented: $showSheet) {
            VStack(spacing: 20) {
                Text("Full Height Sheet")
                    .font(.title2.bold())
                    .foregroundColor(AppColor.textPrimary)
                
                ScrollView {
                    ForEach(0..<20) { i in
                        Text("Item \(i)")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppColor.inputBackground)
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.backgroundPrimary)
            .modernSheet(detents: [.large])
        }
}
