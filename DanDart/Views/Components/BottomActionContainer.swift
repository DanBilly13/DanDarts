import SwiftUI

struct BottomActionContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 12) {
            content
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [
                    AppColor.surfaceSecondary.opacity(0.9),
                    AppColor.surfaceSecondary.opacity(0.0)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }
}
