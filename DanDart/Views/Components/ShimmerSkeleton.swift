import SwiftUI

struct ShimmerModifier: ViewModifier {
    let isActive: Bool

    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    GeometryReader { proxy in
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: proxy.size.width * 0.55)
                        .rotationEffect(.degrees(20))
                        .offset(x: phase * proxy.size.width * 2)
                        .blendMode(.screen)
                        .onAppear {
                            phase = -1
                            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                                phase = 1
                            }
                        }
                    }
                    .mask(content)
                }
            }
    }
}

extension View {
    func shimmer(isActive: Bool) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

struct SkeletonBlock: View {
    let cornerRadius: CGFloat
    let height: CGFloat
    let isShimmering: Bool

    init(height: CGFloat, cornerRadius: CGFloat = 8, isShimmering: Bool) {
        self.cornerRadius = cornerRadius
        self.height = height
        self.isShimmering = isShimmering
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(AppColor.inputBackground)
            .frame(height: height)
            .shimmer(isActive: isShimmering)
    }
}
