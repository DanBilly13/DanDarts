import SwiftUI

enum AppButtonRole {
    case primary     // filled red, white text
    case secondary   // filled green, white text
    case tertiary    // light fill, red text
    }

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
                .frame(maxWidth: .infinity, minHeight: minHeight(for: controlSize))
                .contentShape(Capsule())
        }
        .controlSize(controlSize)
        // ✅ Pass controlSize into the style:
        .buttonStyle(AppButtonStyle(role: role, controlSize: controlSize, compact: compact))
        .disabled(isDisabled)
    }

    private func minHeight(for size: ControlSize) -> CGFloat {
        // Respect accessibility categories by keeping a comfortable hit target
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
    let controlSize: ControlSize   // ✅ Add this stored property
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundShape(pressed: pressed))
            .overlay(strokeOverlay(pressed: pressed))
            .foregroundStyle(foregroundStyle)
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }

    // MARK: - Tokens

    private var foregroundStyle: some ShapeStyle {
        switch role {
        case .primary, .secondary:
            return Color.white.opacity(isEnabled ? 1 : 0.7)
        case .tertiary:
            // Brand text color, soften when disabled
            return Color("AccentPrimary").opacity(isEnabled ? 1 : 0.6)
        }
    }

    @ViewBuilder
    private func backgroundShape(pressed: Bool) -> some View {
        let base: Color = {
            switch role {
            case .primary:   return Color("AccentPrimary")
            case .secondary: return Color("AccentSecondary")
            case .tertiary:  return Color("AccentTertiary")
            }
        }()

        // Derive states from enabled/pressed for consistent contrast
        let bg: Color = {
            if !isEnabled {
                return base.opacity(role == .tertiary ? 0.35 : 0.55)
            }
            return pressed ? base.opacity(role == .tertiary ? 0.85 : 0.90) : base
        }()

        Capsule().fill(bg)
            .shadow(radius: (role == .tertiary || !isEnabled) ? 0 : 2)
    }

    @ViewBuilder
    private func strokeOverlay(pressed: Bool) -> some View {
        if role == .tertiary {
            Capsule()
                .strokeBorder(
                    Color("AccentPrimary").opacity(isEnabled ? (pressed ? 0.45 : 0.25) : 0.2),
                    lineWidth: 1
                )
        } else {
            EmptyView()
        }
    }

    // Padding tuned per control size
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
            case .mini, .small: return 0 // ensure overall height ≈ minHeight
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
            AppButton(role: .primary, controlSize: .mini, compact: true) { print("Start game") } label: {
                Text("Start Game").bold()
            }
            AppButton(role: .primary, controlSize: .small, isDisabled: true, compact: true) { } label: {
                Text("Start Game (disabled)").bold()
            }
            AppButton(role: .secondary, controlSize: .regular) { } label: { Text("Continue as Guest") }
            AppButton(role: .tertiary, controlSize: .large) { } label: { Text("Save Score") }
            AppButton(role: .tertiary, controlSize: .extraLarge, isDisabled: true) { } label: { Text("Save Score (disabled)") }
        }
        .padding()
        .background(Color("BackgroundPrimary"))
        .previewLayout(.sizeThatFits)
    }
}
#endif
