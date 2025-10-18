import SwiftUI

struct PopAnimationModifier: ViewModifier {
    let active: Bool
    var duration: Double = 0.28
    var bounce: Double = 0.22

    func body(content: Content) -> some View {
        content
            .scaleEffect(active ? 1.0 : 0.92)
            .opacity(active ? 1.0 : 0.0)
            .animation(.snappy(duration: duration, extraBounce: bounce), value: active)
    }
}

extension View {
    /// Adds a subtle pop animation that scales and fades a view in/out.
    func popAnimation(active: Bool,
                      duration: Double = 0.28,
                      bounce: Double = 0.22) -> some View {
        self.modifier(PopAnimationModifier(active: active,
                                           duration: duration,
                                           bounce: bounce))
    }
}
