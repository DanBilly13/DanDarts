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
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            LinearGradient(
                colors: [
                    AppColor.justBlack.opacity(0.4),
                    AppColor.justBlack.opacity(0.0)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }
}
