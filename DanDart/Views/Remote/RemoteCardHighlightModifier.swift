import SwiftUI

struct RemoteCardHighlightModifier: ViewModifier {
    let isHighlighted: Bool

    @State private var pulseOn: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(AppColor.brandPrimary.opacity(pulseOn ? 1.0 : 0.35), lineWidth: pulseOn ? 4 : 2)
                        .shadow(color: AppColor.brandPrimary.opacity(pulseOn ? 0.35 : 0.0), radius: pulseOn ? 14 : 0)
                        .animation(.easeInOut(duration: 0.45), value: pulseOn)
                        .onAppear {
                            pulseOn = true
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 450_000_000)
                                pulseOn = false
                            }
                        }
                }
            }
    }
}

extension View {
    func remoteCardHighlight(isHighlighted: Bool) -> some View {
        modifier(RemoteCardHighlightModifier(isHighlighted: isHighlighted))
    }
}
