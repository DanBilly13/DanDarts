//
//  CreateChallengeView.swift
//  DanDart
//
//  Challenge creation flow for remote matches
//

import SwiftUI

struct CreateChallengeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @StateObject private var friendsService = FriendsService()
    @StateObject private var remoteMatchService = RemoteMatchService()
    
    @State private var selectedFriend: User?
    @State private var selectedGameType: String = "301"
    @State private var selectedMatchFormat: Int = 1
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    let gameTypes = ["301", "501"]
    let matchFormats = [
        (value: 1, label: "Best of 1"),
        (value: 3, label: "Best of 3"),
        (value: 5, label: "Best of 5"),
        (value: 7, label: "Best of 7")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Friend Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Opponent")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColor.textPrimary)
                            
                            if let friend = selectedFriend {
                                selectedFriendCard(friend)
                            } else {
                                selectFriendButton
                            }
                        }
                        
                        // Game Type Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Game Type")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColor.textPrimary)
                            
                            HStack(spacing: 12) {
                                ForEach(gameTypes, id: \.self) { gameType in
                                    gameTypeButton(gameType)
                                }
                            }
                        }
                        
                        // Match Format Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Match Format")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColor.textPrimary)
                            
                            VStack(spacing: 8) {
                                ForEach(matchFormats, id: \.value) { format in
                                    matchFormatButton(format.value, format.label)
                                }
                            }
                        }
                        
                        // Create Challenge Button
                        AppButton(role: .primary, controlSize: .large) {
                            createChallenge()
                        } label: {
                            if isCreating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Send Challenge")
                            }
                        }
                        .disabled(selectedFriend == nil || isCreating)
                        .padding(.top, 16)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("New Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    showError = false
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(isPresented: .constant(false)) {
                // TODO: Friend selection sheet
            }
        }
    }
    
    // MARK: - Friend Selection
    
    private var selectFriendButton: some View {
        Button {
            // TODO: Show friend selection sheet
        } label: {
            HStack {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 20))
                Text("Choose Friend")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(AppColor.textPrimary)
            .padding(16)
            .background(AppColor.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func selectedFriendCard(_ friend: User) -> some View {
        HStack(spacing: 12) {
            PlayerAvatarView(avatarURL: friend.avatarURL, size: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColor.textPrimary)
                
                Text("@\(friend.nickname)")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppColor.textSecondary)
            }
            
            Spacer()
            
            Button {
                selectedFriend = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .padding(12)
        .background(AppColor.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Game Type Selection
    
    private func gameTypeButton(_ gameType: String) -> some View {
        Button {
            selectedGameType = gameType
        } label: {
            Text(gameType)
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(selectedGameType == gameType ? .white : AppColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedGameType == gameType ? AppColor.interactivePrimaryBackground : AppColor.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Match Format Selection
    
    private func matchFormatButton(_ value: Int, _ label: String) -> some View {
        Button {
            selectedMatchFormat = value
        } label: {
            HStack {
                Text(label)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(AppColor.textPrimary)
                
                Spacer()
                
                if selectedMatchFormat == value {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColor.interactivePrimaryBackground)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .padding(12)
            .background(AppColor.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Create Challenge
    
    private func createChallenge() {
        print("🚀 Send challenge tapped")
        print("   - selectedFriend: \(selectedFriend?.displayName ?? "nil")")
        print("   - selectedGameType: \(selectedGameType)")
        print("   - selectedMatchFormat: \(selectedMatchFormat)")
        print("   - currentUser: \(authService.currentUser?.id.uuidString ?? "nil")")
        
        guard let friend = selectedFriend else {
            print("❌ Guard failed: selectedFriend is nil")
            return
        }
        
        guard let currentUserId = authService.currentUser?.id else {
            print("❌ Guard failed: currentUser.id is nil")
            return
        }
        
        print("✅ All guards passed")
        print("   - receiverId: \(friend.id)")
        print("   - gameType: \(selectedGameType)")
        print("   - matchFormat: \(selectedMatchFormat)")
        print("   - currentUserId: \(currentUserId)")
        
        isCreating = true
        
        Task {
            do {
                print("📤 About to call remoteMatchService.createChallenge")
                let matchId = try await remoteMatchService.createChallenge(
                    receiverId: friend.id,
                    gameType: selectedGameType,
                    matchFormat: selectedMatchFormat,
                    currentUserId: currentUserId
                )
                
                print("✅ createChallenge returned successfully: \(matchId)")
                
                // Success haptic
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                
                await MainActor.run {
                    isCreating = false
                    dismiss()
                }
                
                print("✅ Challenge created: \(matchId)")
            } catch {
                print("❌ createChallenge threw error:")
                print("   - Error: \(error)")
                print("   - Type: \(type(of: error))")
                print("   - LocalizedDescription: \(error.localizedDescription)")
                
                if let remoteError = error as? RemoteMatchError {
                    print("   - RemoteMatchError: \(remoteError)")
                }
                
                await MainActor.run {
                    isCreating = false
                    errorMessage = "Failed to create challenge: \(error.localizedDescription)"
                    showError = true
                }
                
                // Error haptic
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                #endif
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CreateChallengeView()
        .environmentObject(AuthService.shared)
}
