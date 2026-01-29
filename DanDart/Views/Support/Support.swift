//
//  Support.swift
//  DanDart
//
//  Created by Billingham Daniel on 2026-01-29.
//

import SwiftUI
import UIKit

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
                        .foregroundColor(.secondary)
                }
                
                
                VStack(alignment: .leading, spacing: 16) {
                    
                    VStack (alignment: .leading, spacing: 8) {
                        Text("Found a bug?")
                            .font(.system(.title3, design: .rounded))
                            .font(.body)
                        Text("Help us squash it by reporting any bugs you discover.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    AppButton(role: .secondary, action: {
                        if let url = URL(string: "https://dartfreak.canny.io/bugs") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Report a bug")
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Have a feature idea?")
                            .font(.system(.title3, design: .rounded))
                            .font(.body)
                        Text("Suggest new features to make Dart Freak even better.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    AppButton(role: .secondary, action: {
                        if let url = URL(string: "https://dartfreak.canny.io/feature-requests") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Suggest a feature")
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Something else?")
                        .font(.system(.title3, design: .rounded))
                        .font(.body)
                    Text("If your message doesn’t fit a bug or feature request, you can reach us at support@dartfreak.com")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.leading)
        }
    }
}

#Preview {
    Support()
}
