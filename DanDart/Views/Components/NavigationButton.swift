//
//  NavigationButton.swift
//  DanDart
//
//  Router-based navigation button component
//

import SwiftUI

/// A button that navigates to a destination using the Router
struct NavigationButton<Content: View>: View {
    @EnvironmentObject private var router: Router
    
    let to: Destination
    let label: () -> Content
    
    init(to: Destination, @ViewBuilder label: @escaping () -> Content) {
        self.to = to
        self.label = label
    }
    
    var body: some View {
        Button(action: { router.push(to) }, label: label)
    }
}

// MARK: - Convenience Initializers

extension NavigationButton where Content == Text {
    /// Create a NavigationButton with a text label
    init(_ title: String, to: Destination) {
        self.to = to
        self.label = { Text(title) }
    }
}

extension NavigationButton where Content == SwiftUI.Label<Text, Image> {
    /// Create a NavigationButton with a label (text + icon)
    init(_ title: String, systemImage: String, to: Destination) {
        self.to = to
        self.label = { SwiftUI.Label(title, systemImage: systemImage) }
    }
}
