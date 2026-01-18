//
//  PrivacyPolicy.swift
//  DanDart
//
//  Created by Billingham Daniel on 2026-01-18.
//

import SwiftUI

struct PrivacyPolicy: View {
    var body: some View {
        MarkDownBlockRenderer(title: "Privacy Policy", markdownFileName: "PrivacyPolicy")
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicy()
    }
}
