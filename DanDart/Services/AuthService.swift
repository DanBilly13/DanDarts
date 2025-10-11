//
//  AuthService.swift
//  DanDart
//
//  Authentication service for user management
//

import Foundation
import SwiftUI
import Supabase

@MainActor
class AuthService: ObservableObject {
    // MARK: - Published Properties
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    
    // MARK: - Private Properties
    private let supabaseService = SupabaseService.shared
    
    // MARK: - Initialization
    init() {
        // Initialize auth state
        updateAuthenticationState()
    }
    
    // MARK: - Authentication Methods
    
    /// Sign up a new user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - displayName: User's full display name
    ///   - nickname: User's unique nickname
    func signUp(email: String, password: String, displayName: String, nickname: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Validate input
            try validateSignUpInput(email: email, password: password, displayName: displayName, nickname: nickname)
            
            // 1. Create auth user with Supabase
            let authResponse = try await supabaseService.client.auth.signUp(
                email: email,
                password: password
            )
            
            // Get the user from the auth response
            let user = authResponse.user
            
            // 2. Create user profile in the users table
            let newUser = User(
                id: user.id,
                displayName: displayName,
                nickname: nickname,
                handle: nil, // Can be set later in profile setup
                avatarURL: nil,
                createdAt: Date(),
                lastSeenAt: Date(),
                totalWins: 0,
                totalLosses: 0
            )
            
            try await supabaseService.client
                .from("users")
                .insert(newUser)
                .execute()
            
            // 3. Store session token in Keychain (handled by Supabase SDK automatically)
            
            // 4. Set current user and authentication state
            currentUser = newUser
            updateAuthenticationState()
            
        } catch let error as PostgrestError {
            // Handle database-specific errors
            if error.message.contains("duplicate key") && error.message.contains("nickname") {
                throw AuthError.nicknameAlreadyExists
            }
            throw AuthError.networkError
        } catch let error as AuthError {
            // Re-throw our custom auth errors
            throw error
        } catch {
            // Handle other Supabase auth errors
            if let authError = error as? AuthError {
                throw authError
            }
            
            // Check for common Supabase auth error patterns
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("email") && errorMessage.contains("already") {
                throw AuthError.emailAlreadyExists
            } else if errorMessage.contains("password") {
                throw AuthError.weakPassword
            } else if errorMessage.contains("network") || errorMessage.contains("connection") {
                throw AuthError.networkError
            } else {
                throw AuthError.networkError
            }
        }
    }
    
    /// Sign in an existing user
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Validate input
            try validateSignInInput(email: email, password: password)
            
            // 1. Authenticate with Supabase
            let authResponse = try await supabaseService.client.auth.signIn(
                email: email,
                password: password
            )
            
            // Get the authenticated user
            let user = authResponse.user
            
            // 2. Fetch user profile from users table
            let userProfile: User = try await supabaseService.client
                .from("users")
                .select()
                .eq("id", value: user.id)
                .single()
                .execute()
                .value
            
            // 3. Store session in Keychain (handled by Supabase SDK automatically)
            
            // 4. Set current user and authentication state
            currentUser = userProfile
            updateAuthenticationState()
            
        } catch let error as PostgrestError {
            // Handle database-specific errors
            if error.message.contains("No rows") || error.message.contains("not found") {
                throw AuthError.userNotFound
            }
            throw AuthError.networkError
        } catch let error as AuthError {
            // Re-throw our custom auth errors
            throw error
        } catch {
            // Handle Supabase auth errors
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("invalid") && (errorMessage.contains("email") || errorMessage.contains("password") || errorMessage.contains("credentials")) {
                throw AuthError.invalidCredentials
            } else if errorMessage.contains("network") || errorMessage.contains("connection") {
                throw AuthError.networkError
            } else {
                throw AuthError.invalidCredentials
            }
        }
    }
    
    /// Sign in with Google OAuth
    func signInWithGoogle() async throws {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: Implement Google OAuth sign in
        // 1. Call Supabase Google OAuth flow
        // 2. Handle OAuth callback
        // 3. Fetch/create user profile
        // 4. Set authentication state
        
        throw AuthError.notImplemented
    }
    
    /// Check for existing session on app launch
    func checkSession() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 1. Check for existing session (Supabase SDK handles Keychain automatically)
            // 2. Validate session with Supabase
            let session = try await supabaseService.client.auth.session
            
            // Check if we have a valid session
            guard let currentSession = session else {
                // No session found, user is not authenticated
                await clearAuthenticationState()
                return
            }
            
            // Check if session is expired
            if currentSession.expiresAt < Date() {
                // Session expired, sign out
                await clearAuthenticationState()
                return
            }
            
            // 3. Fetch user profile if session is valid
            let userProfile: User = try await supabaseService.client
                .from("users")
                .select()
                .eq("id", value: currentSession.user.id)
                .single()
                .execute()
                .value
            
            // 4. Set authentication state
            currentUser = userProfile
            updateAuthenticationState()
            
        } catch {
            // 5. Handle expired/invalid sessions gracefully
            // If any error occurs (network, expired session, user not found), clear auth state
            await clearAuthenticationState()
        }
    }
    
    /// Sign out the current user
    func signOut() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 1. Call Supabase sign out
            try await supabaseService.client.auth.signOut()
            
            // 2. Clear Keychain session (handled by Supabase SDK automatically)
            
            // 3. Reset currentUser to nil and set isAuthenticated to false
            await clearAuthenticationState()
            
        } catch {
            // 4. Handle sign out errors gracefully
            // Even if sign out fails on server, clear local state for security
            await clearAuthenticationState()
            
            // Log the error for debugging but don't throw it
            // User should always be able to sign out locally
            print("Sign out error (cleared local state anyway): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Validate sign up input parameters
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - displayName: User's display name
    ///   - nickname: User's nickname
    private func validateSignUpInput(email: String, password: String, displayName: String, nickname: String) throws {
        // Validate email format
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        guard emailPredicate.evaluate(with: email) else {
            throw AuthError.invalidEmail
        }
        
        // Validate password strength
        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }
        
        // Validate display name
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthError.invalidDisplayName
        }
        
        // Validate nickname format (alphanumeric, 3-20 characters)
        let nicknameRegex = "^[a-zA-Z0-9_]{3,20}$"
        let nicknamePredicate = NSPredicate(format: "SELF MATCHES %@", nicknameRegex)
        guard nicknamePredicate.evaluate(with: nickname) else {
            throw AuthError.invalidNickname
        }
    }
    
    /// Validate sign in input parameters
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    private func validateSignInInput(email: String, password: String) throws {
        // Validate email format
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        guard emailPredicate.evaluate(with: email) else {
            throw AuthError.invalidEmail
        }
        
        // Validate password is not empty
        guard !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthError.invalidCredentials
        }
    }
    
    /// Update authentication state based on current user
    private func updateAuthenticationState() {
        isAuthenticated = currentUser != nil
    }
    
    /// Clear all authentication state
    private func clearAuthenticationState() {
        currentUser = nil
        isAuthenticated = false
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case notImplemented
    case invalidCredentials
    case networkError
    case userNotFound
    case emailAlreadyExists
    case nicknameAlreadyExists
    case weakPassword
    case invalidEmail
    case invalidDisplayName
    case invalidNickname
    case sessionExpired
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "This feature is not yet implemented"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network connection error"
        case .userNotFound:
            return "User not found"
        case .emailAlreadyExists:
            return "An account with this email already exists"
        case .nicknameAlreadyExists:
            return "This nickname is already taken"
        case .weakPassword:
            return "Password must be at least 8 characters"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .invalidDisplayName:
            return "Please enter a valid display name"
        case .invalidNickname:
            return "Nickname must be 3-20 characters and contain only letters, numbers, and underscores"
        case .sessionExpired:
            return "Your session has expired. Please sign in again"
        }
    }
}

// MARK: - Mock Data for Previews
extension AuthService {
    /// Create a mock authenticated auth service for previews
    static var mockAuthenticated: AuthService {
        let service = AuthService()
        service.currentUser = User.mockUser1
        service.isAuthenticated = true
        service.isLoading = false
        return service
    }
    
    /// Create a mock unauthenticated auth service for previews
    static var mockUnauthenticated: AuthService {
        let service = AuthService()
        service.currentUser = nil
        service.isAuthenticated = false
        service.isLoading = false
        return service
    }
    
    /// Create a mock loading auth service for previews
    static var mockLoading: AuthService {
        let service = AuthService()
        service.currentUser = nil
        service.isAuthenticated = false
        service.isLoading = true
        return service
    }
}
