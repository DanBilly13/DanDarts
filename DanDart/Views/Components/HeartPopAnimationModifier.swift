import SwiftUI

struct HeartPopAnimationModifier: ViewModifier {
    let active: Bool
    var duration: Double = 0.3
    var holdDuration: Double = 0.5
    
    @State private var isPopped = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPopped ? 2.0 : 1.0)
            .animation(.spring(response: duration, dampingFraction: 0.6), value: isPopped)
            .onChange(of: active) { _, newValue in
                if newValue {
                    // Pop out
                    isPopped = true
                    
                    // Hold, then shrink back
                    Task {
                        try? await Task.sleep(nanoseconds: UInt64(holdDuration * 1_000_000_000))
                        await MainActor.run {
                            isPopped = false
                        }
                    }
                }
            }
    }
}

extension View {
    /// Adds a heart pop animation that scales up to 2x, holds, then shrinks back.
    /// Used for life loss animations in games.
    func heartPopAnimation(active: Bool,
                          duration: Double = 0.3,
                          holdDuration: Double = 0.5) -> some View {
        self.modifier(HeartPopAnimationModifier(active: active,
                                                duration: duration,
                                                holdDuration: holdDuration))
    }
}
