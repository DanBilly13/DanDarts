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
        
        // Store hosting controller in coordinator so we can access it later
        context.coordinator.hostingController = hosting

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
        // Update the hosting controller's rootView to reflect parent state changes
        // This is necessary for @ObservedObject changes in the parent to propagate
        context.coordinator.hostingController?.rootView = content
        
        // Force the hosting view to recalculate its size when content changes
        context.coordinator.hostingController?.view.invalidateIntrinsicContentSize()
        
        // Force the scroll view to update layout immediately
        uiView.setNeedsLayout()
        uiView.layoutIfNeeded()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: TrackingScrollView
        var hostingController: UIHostingController<Content>?

        init(_ parent: TrackingScrollView) {
            self.parent = parent
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            parent.offset = scrollView.contentOffset.y
        }
    }
}
