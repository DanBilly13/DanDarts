//
//  TermsAndConditions.swift
//  DanDart
//
//  Created by Billingham Daniel on 2026-01-18.
//

import SwiftUI

struct TermsAndConditions: View {
    var body: some View {
        MarkDownBlockRenderer(title: "Terms And Conditions", markdownFileName: "TermsAndConditions")
    }
}

#Preview {
    NavigationStack {
        TermsAndConditions()
    }
}
