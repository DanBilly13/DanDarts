//
//  Support.swift
//  DanDart
//
//  Created by Billingham Daniel on 2026-01-29.
//

import SwiftUI
#if canImport(UIKit)
 import UIKit
#endif

struct Support: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Thanks for playing DartFreak")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                    
                    Text("We're thrilled to have you on board! If you encounter any issues or have ideas to improve the app, please don't hesitate to reach out.")
                        .font(.body)
                    .foregroundColor(AppColor.textSecondary)                }
                
                
                VStack(alignment: .leading, spacing: 16) {
                    
                    VStack (alignment: .leading, spacing: 8) {
                        Text("Found a bug?")
                            .font(.system(.title3, design: .rounded))
                            .font(.body)
                        Text("Help us squash it by reporting any bugs you discover.")
                            .font(.body)
                        .foregroundColor(AppColor.textSecondary)                    }
                    
                    Link("Report a bug", destination: URL(string: "https://dartfreak.canny.io/bugs")!)
                        .font(.body)
                        .foregroundStyle(AppColor.brandPrimary)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Have a feature idea?")
                            .font(.system(.title3, design: .rounded))
                            .font(.body)
                        Text("Suggest new features to make Dart Freak even better.")
                            .font(.body)
                            .foregroundColor(AppColor.textSecondary)
                    }
                    
                    Link("Suggest a feature", destination: URL(string: "https://dartfreak.canny.io/feature-requests")!)
                        .font(.body)
                        .foregroundStyle(AppColor.brandPrimary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Something else?")
                        .font(.system(.title3, design: .rounded))
                        .font(.body)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("If your message doesn’t fit a bug or feature request, you can reach us at")
                            .font(.body)
                            .foregroundColor(AppColor.textSecondary)
                        Link("support@dartfreak.com", destination: URL(string: "mailto:support@dartfreak.com")!)
                            .font(.body)
                            .tint(AppColor.brandPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .foregroundStyle(AppColor.justWhite)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.leading)
        }
    }
}

#Preview {
    Support()
}
