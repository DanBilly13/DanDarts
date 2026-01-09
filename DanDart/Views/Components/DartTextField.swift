//
//  DartTextField.swift
//  Dart Freak
//
//  Reusable text field component with consistent styling across the app
//

import SwiftUI

// MARK: - DartTextField Style

/// Custom TextField style matching the app's design system
/// Usage: TextField("Placeholder", text: $text).textFieldStyle(DartTextFieldStyle())
struct DartTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(AppColor.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppColor.inputBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColor.textSecondary.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - DartTextField Component

/// Reusable text field component with label and consistent styling
/// Includes label, text field, and optional error message
struct DartTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var errorMessage: String? = nil
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var autocorrectionDisabled: Bool = false
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColor.textSecondary)
            
            // Text Field
            TextField(placeholder, text: $text)
                .textFieldStyle(DartTextFieldStyle())
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
                .submitLabel(submitLabel)
                .onSubmit {
                    onSubmit?()
                }
            
            // Error Message
            if let error = errorMessage, !error.isEmpty {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - DartSecureField Component

/// Reusable secure field component with label and consistent styling
/// Includes label, secure field with toggle visibility, and optional error message
struct DartSecureField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var errorMessage: String? = nil
    var textContentType: UITextContentType? = .password
    @State private var isSecure: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColor.textSecondary)
            
            // Secure Field with Toggle
            HStack(spacing: 0) {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textPrimary)
                        .textContentType(textContentType)
                } else {
                    TextField(placeholder, text: $text)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textPrimary)
                        .textContentType(textContentType)
                }
                
                // Toggle Visibility Button
                Button(action: {
                    isSecure.toggle()
                }) {
                    Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(AppColor.inputBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColor.textSecondary.opacity(0.2), lineWidth: 1)
            )
            
            // Error Message
            if let error = errorMessage, !error.isEmpty {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Preview
#Preview("DartTextField") {
    VStack(spacing: 24) {
        DartTextField(
            label: "Display Name",
            placeholder: "Enter your name",
            text: .constant("Dan Billingham")
        )
        
        DartTextField(
            label: "Email",
            placeholder: "Enter your email",
            text: .constant(""),
            errorMessage: "Please enter a valid email",
            keyboardType: .emailAddress,
            textContentType: .emailAddress,
            autocapitalization: .never
        )
        
        DartSecureField(
            label: "Password",
            placeholder: "Enter your password",
            text: .constant("password123")
        )
        
        DartSecureField(
            label: "Confirm Password",
            placeholder: "Confirm your password",
            text: .constant(""),
            errorMessage: "Passwords do not match"
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
