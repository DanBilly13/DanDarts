//
//  LockedTextField.swift
//  DanDart
//
//  Read-only text field component for displaying locked/non-editable information
//

import SwiftUI

/// Read-only text field with lock icon for non-editable fields (e.g., Google-managed data)
struct LockedTextField: View {
    let label: String
    let value: String
    var subtitle: String? = nil
    
    @State private var showInfoAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color("TextSecondary"))
            
            // Locked Field (Tappable)
            Button(action: {
                showInfoAlert = true
            }) {
                HStack(spacing: 12) {
                    Text(value)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                    
                    Spacer()
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color("TextSecondary").opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color("InputBackground").opacity(0.5))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("TextSecondary").opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .alert("Why can't I edit this?", isPresented: $showInfoAlert) {
                Button("Got it", role: .cancel) { }
            } message: {
                Text("This information is managed by your Google account. To update it, please visit your Google Account settings.")
            }
            
            // Subtitle (e.g., "Managed by Google")
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color("TextSecondary").opacity(0.7))
                    .padding(.leading, 2)
            }
        }
    }
}

// MARK: - Preview
#Preview("Locked TextField") {
    VStack(spacing: 24) {
        LockedTextField(
            label: "Name",
            value: "Daniel Billingham",
            subtitle: "Managed by Google"
        )
        
        LockedTextField(
            label: "Email",
            value: "dan@example.com",
            subtitle: "Managed by Google"
        )
        
        LockedTextField(
            label: "Name",
            value: "John Smith"
        )
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}
