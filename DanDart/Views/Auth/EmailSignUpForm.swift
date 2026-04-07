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
    
    // Optional focus binding for parent view observation
    var focusedField: Binding<Field?>?
    
    // Local computed
    private var isPasswordValid: Bool { password.count >= 8 }
    
    // Focus management
    enum Field: Hashable {
        case displayName, nickname, email, password, confirmPassword
    }
    @FocusState private var internalFocusedField: Field?
    
    var body: some View {
        VStack(spacing: 20) {
            // Display Name
            DartTextField(
                label: "Display Name",
                placeholder: "Your full name",
                text: $displayName,
                textContentType: .name,
                autocapitalization: .words,
                submitLabel: .done,
                onSubmit: { 
                    internalFocusedField = .nickname
                    focusedField?.wrappedValue = .nickname
                }
            )
            .focused($internalFocusedField, equals: .displayName)
            .id("displayNameField")
            
            // Nickname
            DartTextField(
                label: "Nickname",
                placeholder: "Your game nickname",
                text: $nickname,
                textContentType: .nickname,
                autocapitalization: .never,
                autocorrectionDisabled: true,
                submitLabel: .done,
                onSubmit: { 
                    internalFocusedField = .email
                    focusedField?.wrappedValue = .email
                }
            )
            .focused($internalFocusedField, equals: .nickname)
            .id("nicknameField")
            
            // Email
            DartTextField(
                label: "Email",
                placeholder: "Enter your email",
                text: $email,
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                autocapitalization: .never,
                autocorrectionDisabled: true,
                submitLabel: .done,
                onSubmit: { 
                    internalFocusedField = .password
                    focusedField?.wrappedValue = .password
                }
            )
            .focused($internalFocusedField, equals: .email)
            .id("emailField")
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
                textContentType: .newPassword,
                submitLabel: .done,
                onSubmit: { 
                    internalFocusedField = .confirmPassword
                    focusedField?.wrappedValue = .confirmPassword
                }
            )
            .focused($internalFocusedField, equals: .password)
            .id("passwordField")
            
            // Confirm Password
            DartSecureField(
                label: "Confirm Password",
                placeholder: "Confirm your password",
                text: $confirmPassword,
                textContentType: .newPassword,
                submitLabel: .done,
                onSubmit: {
                    internalFocusedField = nil
                    focusedField?.wrappedValue = nil
                    onSubmit()
                }
            )
            .focused($internalFocusedField, equals: .confirmPassword)
            .id("confirmPasswordField")
            
            // Password Requirements
            VStack(alignment: .leading, spacing: 4) {
                Text("Password must contain:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
                
                HStack(spacing: 8) {
                    Image(systemName: isPasswordValid ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12))
                        .foregroundColor(isPasswordValid ? .green : AppColor.textSecondary.opacity(0.6))
                    Text("At least 8 characters")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isPasswordValid ? .green : AppColor.textSecondary)
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
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColor.textOnPrimary))
                            .scaleEffect(0.8)
                    }
                    Text(isLoading ? "Creating Account..." : "Create Account")
                }
            }
            .disabled(!isFormValid || isLoading)
            .opacity((isFormValid && !isLoading) ? 1.0 : 0.6)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 120)
    }
}
