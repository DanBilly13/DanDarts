//
//  TopBar.swift
//  DanDart
//
//  Reusable top bar component for main app screens
//

import SwiftUI

struct TopBar: View {
    @EnvironmentObject private var authService: AuthService
    @Binding var showProfile: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Status bar spacer
            Rectangle()
                .fill(Color("BackgroundPrimary"))
                .frame(height: 0)
                .ignoresSafeArea(.container, edges: .top)
            
            // Actual top bar content
            HStack {
                // DanDarts Title (Left)
                Text("DanDarts")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color("TextPrimary"))
                
                Spacer()
                
                // Avatar Button (Right)
                Button(action: {
                    showProfile = true
                }) {
                    AvatarView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color("BackgroundPrimary"))
        }
    }
}

// MARK: - Avatar View Component

struct AvatarView: View {
    @EnvironmentObject private var authService: AuthService
    
    var body: some View {
        ZStack {
            // Avatar Background Circle
            Circle()
                .fill(Color("InputBackground"))
                .frame(width: 32, height: 32)
            
            // Avatar Content
            if let user = authService.currentUser,
               let avatarURL = user.avatarURL {
                // User has custom avatar (SF Symbol for now)
                Image(systemName: avatarURL)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("AccentPrimary"))
            } else {
                // Default placeholder avatar
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("TextSecondary"))
            }
        }
        .overlay(
            Circle()
                .stroke(Color("TextSecondary").opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var showProfile = false
    
    VStack(spacing: 0) {
        TopBar(showProfile: $showProfile)
        
        Spacer()
        
        Text("Content Area")
            .font(.title2)
            .foregroundColor(Color("TextSecondary"))
        
        Spacer()
    }
    .background(Color("BackgroundPrimary"))
    .environmentObject(AuthService())
}

#Preview("TopBar with User") {
    @Previewable @State var showProfile = false
    
    VStack(spacing: 0) {
        TopBar(showProfile: $showProfile)
        
        Spacer()
        
        Text("Content Area")
            .font(.title2)
            .foregroundColor(Color("TextSecondary"))
        
        Spacer()
    }
    .background(Color("BackgroundPrimary"))
    .environmentObject({
        let authService = AuthService()
        // Mock user with avatar
        authService.currentUser = User(
            id: UUID(),
            displayName: "John Doe",
            nickname: "johndoe",
            handle: "john_doe",
            avatarURL: "target",
            createdAt: Date(),
            lastSeenAt: Date()
        )
        return authService
    }())
}

#Preview("TopBar - Dark") {
    @Previewable @State var showProfile = false
    
    VStack(spacing: 0) {
        TopBar(showProfile: $showProfile)
        
        Spacer()
        
        Text("Content Area")
            .font(.title2)
            .foregroundColor(Color("TextSecondary"))
        
        Spacer()
    }
    .background(Color("BackgroundPrimary"))
    .environmentObject(AuthService())
    .preferredColorScheme(.dark)
}
