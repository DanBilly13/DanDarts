import SwiftUI
import UIKit

/// A UIKit-backed scroll view that exposes its vertical content offset to SwiftUI.
struct TrackingScrollView<Content: View>: UIViewRepresentable {
    typealias UIViewType = UIScrollView

    @Binding var offset: CGFloat
    let showsIndicators: Bool
    let content: Content

    init(offset: Binding<CGFloat>, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self._offset = offset
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = showsIndicators
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        // Embed SwiftUI content via a hosting controller
        let hosting = UIHostingController(rootView: content)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .clear

        scrollView.addSubview(hosting.view)

        // Constrain hosting view to the scroll view's content layout
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hosting.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Update the hosted SwiftUI content when SwiftUI state changes
        if let hosting = uiView.subviews.compactMap({ $0.next as? UIHostingController<Content> }).first {
            hosting.rootView = content
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: TrackingScrollView

        init(_ parent: TrackingScrollView) {
            self.parent = parent
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            parent.offset = scrollView.contentOffset.y
        }
    }
}
