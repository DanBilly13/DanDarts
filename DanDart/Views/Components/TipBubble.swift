import SwiftUI

struct TipBubble: View {
    let systemImageName: String
    let title: String
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImageName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColor.brandPrimary)
                    .padding(8)
                    .background(AppColor.brandPrimary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(AppColor.textPrimary)

                    Text(message)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColor.textSecondary)
                        .padding(6)
                        .background(AppColor.inputBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColor.surfacePrimary)
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 8)
        )
    }
}

/// Helper wrapper that positions a tip view at percentage-based coordinates
/// over arbitrary background content.
///
/// xPercent / yPercent are in the range 0...1 (0 = leading/top, 1 = trailing/bottom).
struct PositionedTip<TipContent: View, Background: View>: View {
    let xPercent: CGFloat
    let yPercent: CGFloat
    let tip: TipContent
    let background: Background

    init(
        xPercent: CGFloat,
        yPercent: CGFloat,
        @ViewBuilder tip: () -> TipContent,
        @ViewBuilder background: () -> Background
    ) {
        self.xPercent = xPercent
        self.yPercent = yPercent
        self.tip = tip()
        self.background = background()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background

                tip
                    .position(
                        x: clamped(xPercent) * proxy.size.width,
                        y: clamped(yPercent) * proxy.size.height
                    )
            }
        }
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(1, max(0, value))
    }
}

#Preview("Default Tip") {
    ZStack {
        AppColor.backgroundPrimary.ignoresSafeArea()

        VStack(spacing: 24) {
            Spacer()

            TipBubble(
                systemImageName: "cursorarrow.click",
                title: "Doubles & Trebles",
                message: "Long‑press any number button to choose single, double, or treble before you release.",
                onDismiss: {}
            )
            .padding(.horizontal, 24)

            Spacer()

            // Simulated scoring grid background for context
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppColor.inputBackground)
                .frame(height: 260)
                .overlay(
                    Text("Scoring grid preview")
                        .foregroundColor(AppColor.textSecondary)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
        }
    }
}
