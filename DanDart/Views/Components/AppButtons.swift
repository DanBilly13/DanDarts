import SwiftUI
/// Visual roles for App buttons
/// - primary: solid red background, white text & icon
/// - secondary: solid green background, white text & icon
/// - tertiary: pale/white background, red text & icon
/// - primaryOutline: red outline, white text, red icon
/// - secondaryOutline: green outline, white text, green icon
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
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, minHeight: minHeight(for: controlSize))
                .contentShape(Capsule())
        }
        .controlSize(controlSize)
        .buttonStyle(AppButtonStyle(role: role, controlSize: controlSize, compact: compact))
        .disabled(isDisabled)
    }

    private func minHeight(for size: ControlSize) -> CGFloat {
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
}

// MARK: - Style
private struct AppButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let role: AppButtonRole
    let controlSize: ControlSize
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
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
            case .primary, .primaryOutline:   return Color("AccentPrimary")
            case .secondary, .secondaryOutline: return Color("AccentSecondary")
            case .tertiary, .tertiaryOutline:  return Color("AccentTertiary")
            }
        }()

        switch role {
        case .primary, .secondary, .tertiary:
            let bg: Color = {
                if !isEnabled { return base.opacity(role == .tertiary ? 0.35 : 0.55) }
                return pressed ? base.opacity(role == .tertiary ? 0.85 : 0.90) : base
            }()
            Capsule().fill(bg)
                .shadow(radius: (role == .tertiary || !isEnabled) ? 0 : 2)

        case .primaryOutline, .secondaryOutline, .tertiaryOutline:
            let fillOpacity: Double = !isEnabled ? 0.06 : (pressed ? 0.18 : 0.12)
            Capsule().fill(base.opacity(fillOpacity))
        }
    }

    @ViewBuilder
    private func strokeOverlay(pressed: Bool) -> some View {
        switch role {
        case .tertiary:
            Capsule()
                .strokeBorder(
                    Color("AccentPrimary").opacity(isEnabled ? (pressed ? 0.45 : 0.25) : 0.2),
                    lineWidth: 1
                )
        case .primaryOutline:
            Capsule()
                .strokeBorder(
                    Color("AccentPrimary").opacity(isEnabled ? (pressed ? 0.9 : 0.8) : 0.4),
                    lineWidth: 1
                )
        case .secondaryOutline:
            Capsule()
                .strokeBorder(
                    Color("AccentSecondary").opacity(isEnabled ? (pressed ? 0.9 : 0.8) : 0.4),
                    lineWidth: 1
                )
        case .tertiaryOutline:
            Capsule()
                .strokeBorder(
                    Color("AccentPrimary").opacity(isEnabled ? (pressed ? 0.6 : 0.5) : 0.3),
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
        .background(Color("BackgroundPrimary"))
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
        let primaryBase = Color("AccentPrimary")
        let secondaryBase = Color("AccentSecondary")
        let white = Color.white.opacity(isEnabled ? 1 : 0.7)
        let dim: (Color) -> Color = { color in color.opacity(isEnabled ? 1 : 0.6) }

        let textColor: Color
        let iconTint: Color

        switch role {
        case .primary:
            textColor = white
            iconTint = white
        case .secondary:
            textColor = white
            iconTint = white
        case .tertiary: // pale/white button
            textColor = dim(primaryBase)
            iconTint = dim(primaryBase)
        case .primaryOutline, .tertiaryOutline: // red outline → white text, red icon
            textColor = white
            iconTint = primaryBase
        case .secondaryOutline: // green outline → white text, green icon
            textColor = white
            iconTint = secondaryBase
        }

        return self
            // Base text color for non-Label content
            .foregroundStyle(textColor)
            // For Label-based content, split text/icon colors
            .labelStyle(SplitTintLabelStyle(textColor: textColor, iconColor: iconTint))
    }
}
