import SwiftUI
/// Visual roles for App buttons
/// - primary: solid red background, white text & icon
/// - secondary: solid green background, white text & icon
/// - tertiary: pale/white background, red text & icon
/// - primaryOutline: red outline, white text, red icon
/// - secondaryOutline: red outline, black text, red icon, white background
/// - tertiaryOutline: red outline variant, white text, red icon
enum AppButtonRole {
    case primary
    case secondary
    case tertiary
    case primaryOutline
    case secondaryOutline
    case tertiaryOutline
}
// MARK: - AppButton
struct AppButton<Label: View>: View {
    @Environment(\.sizeCategory) private var sizeCategory
    let role: AppButtonRole
    let action: () -> Void
    let controlSize: ControlSize
    let isDisabled: Bool
    let compact: Bool
    @ViewBuilder let label: () -> Label

    init(role: AppButtonRole,
         controlSize: ControlSize = .regular,
         isDisabled: Bool = false,
         compact: Bool = false,
         action: @escaping () -> Void,
         @ViewBuilder label: @escaping () -> Label) {
        self.role = role
        self.action = action
        self.controlSize = controlSize
        self.isDisabled = isDisabled
        self.compact = compact
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
                .font(font(for: controlSize))
                .frame(maxWidth: .infinity)
                .contentShape(Capsule())
        }
        .controlSize(controlSize)
        .buttonStyle(AppButtonStyle(role: role, controlSize: controlSize, compact: compact))
        .disabled(isDisabled)
    }

    private func font(for size: ControlSize) -> Font {
        // Map control sizes to a consistent, legible font
        // Keep at least the standard size for accessibility categories
        let base: Font
        switch size {
        case .mini: base = .system(size: 13, weight: .semibold)
        case .small: base = .system(size: 14, weight: .semibold)
        case .regular: base = .system(size: 16, weight: .semibold)
        case .large: base = .system(size: 16, weight: .semibold)
        case .extraLarge: base = .system(size: 16, weight: .semibold)
        @unknown default: base = .system(size: 16, weight: .semibold)
        }
        if sizeCategory.isAccessibilityCategory {
            return .system(size: 17, weight: .semibold)
        }
        return base
    }
}

// MARK: - Style
private struct AppButtonStyle: ButtonStyle {
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.isEnabled) private var isEnabled
    let role: AppButtonRole
    let controlSize: ControlSize
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .frame(minHeight: contentMinHeight)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundShape(pressed: pressed))
            .overlay(strokeOverlay(pressed: pressed))
            .applyButtonForeground(role: role, isEnabled: isEnabled)
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }

    @ViewBuilder
    private func backgroundShape(pressed: Bool) -> some View {
        let base: Color = {
            switch role {
            case .primary, .primaryOutline:
                return AppColor.interactivePrimaryBackground
            case .secondary, .secondaryOutline:
                return AppColor.interactiveSecondaryBackground
            case .tertiary, .tertiaryOutline:
                return AppColor.interactiveTertiaryBackground
            }
        }()

        switch role {
        case .primary, .secondary, .tertiary:
            let bg: Color = {
                // disabled filled background button opacity
                if !isEnabled { return base.opacity(0.2) }
                return pressed ? base.opacity(role == .tertiary ? 0.85 : 0.90) : base
            }()
            Capsule().fill(bg)

        case .primaryOutline, .tertiaryOutline:
            // Use app background to clearly differentiate from disabled filled buttons
            let bg = AppColor.backgroundPrimary
            Capsule().fill(bg)
            
        case .secondaryOutline:
            // White background for secondary outline (deny button style)
            Capsule().fill(AppColor.justWhite)
        }
    }

    @ViewBuilder
    private func strokeOverlay(pressed: Bool) -> some View {
        switch role {
        case .primaryOutline:
            Capsule()
                .strokeBorder(
                    AppColor.interactivePrimaryBackground.opacity(isEnabled ? 1 : 0.5),
                    lineWidth: 1
                )
        case .secondaryOutline:
            Capsule()
                .strokeBorder(
                    AppColor.interactivePrimaryBackground.opacity(isEnabled ? 1 : 0.5),
                    lineWidth: 1
                )
        case .tertiaryOutline:
            Capsule()
                .strokeBorder(
                    AppColor.justWhite.opacity(isEnabled ? 1 : 0.5),
                    lineWidth: 1
                )
        default:
            EmptyView()
        }
    }

    private var horizontalPadding: CGFloat {
        if compact {
            switch controlSize {
            case .mini: return 8
            case .small: return 10
            default: break
            }
        }
        switch controlSize {
        case .mini: return 10
        case .small: return 12
        case .regular: return 16
        case .large: return 20
        case .extraLarge: return 24
        @unknown default: return 16
        }
    }

    private var verticalPadding: CGFloat {
        if compact {
            switch controlSize {
            case .mini, .small: return 0
            default: break
            }
        }
        switch controlSize {
        case .mini: return 6
        case .small: return 8
        case .regular: return 10
        case .large: return 12
        case .extraLarge: return 14
        @unknown default: return 10
        }
    }

    private func targetHeight(for size: ControlSize) -> CGFloat {
        // Final button heights per control size (including padding)
        // These align with common iOS touch targets while offering compact variants
        if sizeCategory.isAccessibilityCategory { return 44 }
        switch size {
        case .mini: return 32
        case .small: return 36
        case .regular: return 44
        case .large: return 48
        case .extraLarge: return 52
        @unknown default: return 44
        }
    }

    private var contentMinHeight: CGFloat {
        // Ensure final height == targetHeight by subtracting vertical padding applied above
        let total = targetHeight(for: controlSize)
        let inner = total - (verticalPadding * 2)
        return max(inner, 0)
    }
}

#if DEBUG
struct AppButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            AppButton(role: .primary, controlSize: .mini, compact: true) { } label: {
                Text("Start Game")
            }
            AppButton(role: .primary, controlSize: .small, isDisabled: true, compact: true) { } label: {
                Text("Start Game (disabled)")
            }
            AppButton(role: .secondary, controlSize: .regular) { } label: { Text("Continue as Guest") }
            AppButton(role: .tertiary, controlSize: .large) { } label: { Text("Save Score") }
            AppButton(role: .tertiary, controlSize: .extraLarge, isDisabled: true) { } label: { Text("Save Score (disabled)") }

            // Outline examples
            AppButton(role: .primaryOutline, controlSize: .regular, compact: true) { } label: {
                Label("Add Player", systemImage: "plus")
            }
            AppButton(role: .secondaryOutline, controlSize: .regular, compact: true) { } label: {
                Label("Invite", systemImage: "person.badge.plus")
            }
            AppButton(role: .tertiaryOutline, controlSize: .regular, compact: true) { } label: {
                Label("Delete Game", systemImage: "trash")
            }

            // Filled buttons
            AppButton(role: .primary, controlSize: .regular) { } label: {
                Label("Play", systemImage: "play.fill")
            }
            AppButton(role: .secondary, controlSize: .regular) { } label: {
                Label("Join", systemImage: "person.crop.circle.fill.badge.plus")
            }
        }
        .padding()
        .background(AppColor.backgroundPrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
private struct SplitTintLabelStyle: LabelStyle {
    let textColor: Color
    let iconColor: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(iconColor)
            configuration.title
                .foregroundStyle(textColor)
        }
    }
}
private extension View {
    func applyButtonForeground(role: AppButtonRole, isEnabled: Bool) -> some View {
        let primaryBase = AppColor.interactivePrimaryBackground
        let secondaryBase = AppColor.interactiveSecondaryForeground
        // disabled filled button text opacity
        let white = AppColor.interactivePrimaryForeground.opacity(isEnabled ? 1 : 0.2)
        // disabled border text opacity
        let dim: (Color) -> Color = { color in color.opacity(isEnabled ? 1 : 0.2) }

        let textColor: Color
        let iconTint: Color

        switch role {
        case .primary:
            textColor = white
            iconTint = white
        case .secondary:
            textColor = secondaryBase
            iconTint = secondaryBase
        case .tertiary: // pale/white button
            textColor = dim(primaryBase)
            iconTint = dim(primaryBase)
        case .primaryOutline, .tertiaryOutline: // red outline → white text, red icon
            textColor = white
            iconTint = primaryBase
        case .secondaryOutline: // red outline → black text, red icon, white background
            textColor = dim(AppColor.justBlack)
            iconTint = primaryBase
        }

        return self
            // Base text color for non-Label content
            .foregroundStyle(textColor)
            // For Label-based content, split text/icon colors
            .labelStyle(SplitTintLabelStyle(textColor: textColor, iconColor: iconTint))
    }
}
