
import SwiftUI

struct EmailSignUpForm: View {
    // Bindings for form fields
    @Binding var displayName: String
    @Binding var nickname: String
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    
    // External state
    var isLoading: Bool
    var isFormValid: Bool
    @Binding var errorMessage: String
    
    // Actions
    var onSubmit: () -> Void
    
    // Local computed
    private var isPasswordValid: Bool { password.count >= 8 }
    
    var body: some View {
        VStack(spacing: 20) {
            // Display Name
            DartTextField(
                label: "Display Name",
                placeholder: "Your full name",
                text: $displayName,
                textContentType: .name,
                autocapitalization: .words
            )
            
            // Nickname
            VStack(alignment: .leading, spacing: 8) {
                Text("Nickname")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color("TextSecondary"))
                
                HStack(spacing: 0) {
                    Text("@")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                        .padding(.leading, 16)
                        .padding(.trailing, 4)
                    
                    TextField("username", text: $nickname)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextPrimary"))
                        .textContentType(.nickname)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .padding(.trailing, 16)
                        .padding(.vertical, 14)
                }
                .background(Color("InputBackground"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color("TextSecondary").opacity(0.2), lineWidth: 1)
                )
            }
            
            // Email
            DartTextField(
                label: "Email",
                placeholder: "Enter your email",
                text: $email,
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalization: .never,
                autocorrectionDisabled: true
            )
            .onChange(of: email) { oldValue, newValue in
                // Fix Swedish keyboard @ symbol issue
                let correctedEmail = newValue.replacingOccurrences(of: "™", with: "@")
                if correctedEmail != newValue {
                    email = correctedEmail
                }
            }
            
            // Password
            DartSecureField(
                label: "Password",
                placeholder: "Create a password",
                text: $password,
                textContentType: .newPassword
            )
            
            // Confirm Password
            DartSecureField(
                label: "Confirm Password",
                placeholder: "Confirm your password",
                text: $confirmPassword,
                textContentType: .newPassword
            )
            
            // Password Requirements
            VStack(alignment: .leading, spacing: 4) {
                Text("Password must contain:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color("TextSecondary"))
                
                HStack(spacing: 8) {
                    Image(systemName: isPasswordValid ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                        .foregroundColor(isPasswordValid ? .green : Color("TextSecondary").opacity(0.6))
                    Text("At least 8 characters")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isPasswordValid ? .green : Color("TextSecondary"))
                    Spacer()
                }
            }
            .padding(.horizontal, 4)
            
            // Error Message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            // Create Account Button
            AppButton(role: .primary, controlSize: .extraLarge, action: onSubmit) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(isLoading ? "Creating Account..." : "Create Account")
                }
            }
            .disabled(!isFormValid || isLoading)
            .opacity((isFormValid && !isLoading) ? 1.0 : 0.6)
        }
        .padding(.horizontal, 32)
    }
}
