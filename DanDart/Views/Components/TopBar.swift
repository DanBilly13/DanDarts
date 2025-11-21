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
                .fill(AppColor.backgroundPrimary)
                .frame(height: 0)
                .ignoresSafeArea(.container, edges: .top)
            
            // Actual top bar content
            HStack {
                // DanDarts Title (Left)
                Text("DanDarts")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColor.textPrimary)
                
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
            .background(AppColor.backgroundPrimary)
        }
    }
}

// MARK: - Avatar View Component

struct AvatarView: View {
    @EnvironmentObject private var authService: AuthService
    
    var body: some View {
        AsyncAvatarImage(
            avatarURL: authService.currentUser?.avatarURL,
            size: 32,
            placeholderIcon: "person.circle.fill"
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
            .foregroundColor(AppColor.textSecondary)
        
        Spacer()
    }
    .background(AppColor.backgroundPrimary)
    .environmentObject(AuthService())
}

#Preview("TopBar with User") {
    @Previewable @State var showProfile = false
    
    VStack(spacing: 0) {
        TopBar(showProfile: $showProfile)
        
        Spacer()
        
        Text("Content Area")
            .font(.title2)
            .foregroundColor(AppColor.textSecondary)
        
        Spacer()
    }
    .background(AppColor.backgroundPrimary)
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
            .foregroundColor(AppColor.textSecondary)
        
        Spacer()
    }
    .background(AppColor.backgroundPrimary)
    .environmentObject(AuthService())
    .preferredColorScheme(.dark)
}
