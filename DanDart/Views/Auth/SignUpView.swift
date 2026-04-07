import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    var onSwitchToSignIn: (() -> Void)? = nil
    
    // MARK: - Form State
    @State private var displayName = ""
    @State private var nickname = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // MARK: - UI State
    @State private var showErrors = false
    @State private var errorMessage = ""
    @State private var useEmail = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var isLoadingEmail = false
    @State private var isLoadingGoogle = false
    @State private var isLoadingApple = false
    @State private var emailFormFocusedField: EmailSignUpForm.Field?
    
    // Computed property for any loading state
    private var isAnyLoading: Bool {
        isLoadingEmail || isLoadingGoogle || isLoadingApple
    }
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !displayName.isEmpty &&
        !nickname.isEmpty &&
        nickname.count >= 3 &&
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        confirmPassword == password
    }
    
    private var isPasswordValid: Bool {
        password.count >= 8
    }
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        // App Logo
                        Image("SplashScreen")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 100)
                            
                        Text("Create Account")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColor.textPrimary)
                    }
                    .padding(.top, 24)
                    
                    // Google Sign Up Button
                    AppButton(
                        role: .primary,
                        controlSize: .extraLarge,
                        isDisabled: isAnyLoading,
                        compact: true,
                        action: {
                            Task { await handleGoogleSignUp() }
                        }
                    ) {
                        HStack(spacing: 8) {
                            if isLoadingGoogle {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(AppColor.textOnPrimary)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image("Google")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .opacity(isAnyLoading && !isLoadingGoogle ? 0.2 : 1)
                            }
                            Text(isLoadingGoogle ? "Signing up..." : "Continue with Google")
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Apple Sign In Button
                    AppButton(
                        role: .primary,
                        controlSize: .extraLarge,
                        isDisabled: isAnyLoading,
                        compact: true,
                        action: {
                            Task {
                                await signUpWithApple()
                            }
                        }
                    ) {
                        HStack(spacing: 8) {
                            if isLoadingApple {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(AppColor.textOnPrimary)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 20, weight: .medium))
                                    .frame(width: 16, height: 16)
                            }
                            Text(isLoadingApple ? "Signing up..." : "Continue with Apple")
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // OR Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(AppColor.textSecondary.opacity(0.3))
                        
                        Text("OR")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                            .padding(.horizontal, 16)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(AppColor.textSecondary.opacity(0.3))
                    }
                    .padding(.horizontal, 32)
                    
                    // Collapsible two-step email sign-up
                    Group {
                        if !useEmail {
                            AppButton(
                                role: .primaryOutline,
                                controlSize: .extraLarge,
                                compact: true,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.2)) { useEmail = true }
                                }
                            ) {
                                HStack(spacing: 8) {
                                    Image(systemName: "envelope")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Sign up with email")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 32)
                        } else {
                            EmailSignUpForm(
                                displayName: $displayName,
                                nickname: $nickname,
                                email: $email,
                                password: $password,
                                confirmPassword: $confirmPassword,
                                isLoading: isLoadingEmail,
                                isFormValid: isFormValid,
                                errorMessage: $errorMessage,
                                onSubmit: {
                                    Task { await handleSignUp() }
                                },
                                focusedField: $emailFormFocusedField
                            )
                            .id("emailForm")
                            
                            Button(action: { withAnimation(.easeInOut(duration: 0.2)) {
                                useEmail = false
                                errorMessage = ""
                            }}) {
                                Text("Hide email sign-up")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppColor.interactivePrimaryBackground)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }
                    
                    TermsAndPrivacyText(showTerms: $showTerms, showPrivacy: $showPrivacy)
                        .padding(.top, 8)
                    
                    Button(action: {
                        onSwitchToSignIn?()
                    }) {
                        HStack {
                            Text("Already have an account?")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppColor.textSecondary)
                            
                            Text("Sign In")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColor.interactivePrimaryBackground)
                        }
                    }
                    .padding(.bottom, 32)
                }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: emailFormFocusedField) { _, focusedField in
                    guard let field = focusedField else { return }
                    // Auto-scroll to specific field when keyboard appears
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            switch field {
                            case .displayName:
                                proxy.scrollTo("displayNameField", anchor: .bottom)
                            case .nickname:
                                proxy.scrollTo("nicknameField", anchor: .bottom)
                            case .email:
                                proxy.scrollTo("emailField", anchor: .bottom)
                            case .password:
                                proxy.scrollTo("passwordField", anchor: .bottom)
                            case .confirmPassword:
                                proxy.scrollTo("confirmPasswordField", anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.surfacePrimary)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showTerms) {
                NavigationStack {
                    TermsAndConditions()
                }
                .background(AppColor.surfacePrimary)
            }
            .sheet(isPresented: $showPrivacy) {
                NavigationStack {
                    PrivacyPolicy()
                }
                .background(AppColor.surfacePrimary)
            }
        }
    }
    
    // MARK: - Actions
    private func handleSignUp() async {
        showErrors = true
        errorMessage = ""
        
        guard isFormValid else {
            errorMessage = "Please fill in all fields correctly"
            return
        }
        
        isLoadingEmail = true
        
        do {
            try await authService.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch let error as AuthError {
            switch error {
            case .emailAlreadyExists:
                errorMessage = "An account with this email already exists"
            case .nicknameAlreadyExists:
                errorMessage = "This nickname is already taken"
            case .weakPassword:
                errorMessage = "Password is too weak. Please choose a stronger password"
            case .invalidEmail:
                errorMessage = "Please enter a valid email address"
            case .networkError:
                errorMessage = "Network error. Please check your connection and try again"
            default:
                errorMessage = "Failed to create account. Please try again"
            }
        } catch {
            if error.localizedDescription.contains("timed out") ||
               error.localizedDescription.contains("network") ||
               error.localizedDescription.contains("connection") {
                errorMessage = "Connection timeout. Please try signing in with Google instead."
            } else {
                errorMessage = "An unexpected error occurred. Please try again"
            }
        }
        
        isLoadingEmail = false
    }
    
    private func handleGoogleSignUp() async {
        errorMessage = ""
        isLoadingGoogle = true
        
        do {
            let isNewUser = try await authService.signInWithGoogle()
            dismiss()
        } catch let error as AuthError {
            switch error {
            case .oauthCancelled:
                break
            case .oauthFailed:
                errorMessage = "Google sign in failed. Please try again"
            case .networkError:
                errorMessage = "Network error. Please check your connection and try again"
            default:
                errorMessage = "Failed to sign in with Google. Please try again"
            }
        } catch {
            errorMessage = "An unexpected error occurred. Please try again"
        }
        
        isLoadingGoogle = false
    }
    
    private func signUpWithApple() async {
        errorMessage = ""
        isLoadingApple = true
        
        do {
            let isNewUser = try await authService.signInWithApple()
            dismiss()
        } catch let error as AuthError {
            switch error {
            case .oauthCancelled:
                break
            case .oauthFailed:
                errorMessage = "Apple sign in failed. Please try again"
            case .networkError:
                errorMessage = "Network error. Please check your connection and try again"
            default:
                errorMessage = "Failed to sign in with Apple. Please try again"
            }
        } catch {
            errorMessage = "An unexpected error occurred. Please try again"
        }
        
        isLoadingApple = false
    }
}

// MARK: - Preview
#Preview {
    SignUpView()
        .environmentObject(AuthService())
}

#Preview("Sign Up - Dark") {
    SignUpView()
        .environmentObject(AuthService())
        .preferredColorScheme(.dark)
}

#Preview("Sign Up - Light") {
    SignUpView()
        .environmentObject(AuthService())
        .preferredColorScheme(.light)
}
