//
//  ProfileHeaderView.swift
//  DanDart
//
//  Reusable profile header component for user and friend profiles
//

import SwiftUI
import PhotosUI

struct ProfileHeaderView: View {
    let player: Player
    let showEditButton: Bool
    let onEditTapped: (() -> Void)?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    var selectedAvatarImage: UIImage?
    
    init(player: Player, 
         showEditButton: Bool = false, 
         onEditTapped: (() -> Void)? = nil,
         selectedPhotoItem: Binding<PhotosPickerItem?> = .constant(nil),
         selectedAvatarImage: UIImage? = nil) {
        self.player = player
        self.showEditButton = showEditButton
        self.onEditTapped = onEditTapped
        self._selectedPhotoItem = selectedPhotoItem
        self.selectedAvatarImage = selectedAvatarImage
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar with optional PhotosPicker
            if showEditButton {
                // Editable avatar with PhotosPicker
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    avatarView
                }
            } else {
                // Non-editable avatar
                avatarView
            }
            
            // Name and Handle
            VStack(spacing: 4) {
                Text(player.displayName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color("TextPrimary"))
                
                if !player.isGuest {
                    Text("@\(player.nickname)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("AccentPrimary"))
                } else {
                    Text("Guest Player")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                }
            }
            
            // Stats Cards
            HStack(spacing: 12) {
                // Games Played
                StatCard(
                    title: "Games",
                    value: "\(player.totalGames)",
                    icon: "target"
                )
                
                // Wins
                StatCard(
                    title: "Wins",
                    value: "\(player.totalWins)",
                    icon: "trophy.fill"
                )
                
                // Win Rate
                StatCard(
                    title: "Win Rate",
                    value: player.winRatePercentage,
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
        }
    }
    
    // MARK: - Avatar View
    
    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(Color("InputBackground"))
                .frame(width: 120, height: 120)
            
            // Show selected image first, then avatar URL, then default
            if let selectedImage = selectedAvatarImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } else if let avatarURL = player.avatarURL {
                Image(avatarURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(Color("AccentPrimary"))
            }
            
            // Camera icon overlay for editable avatars
            if showEditButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color("AccentPrimary"))
                            .clipShape(Circle())
                            .offset(x: -5, y: -5)
                    }
                }
                .frame(width: 120, height: 120)
            }
        }
        .overlay(
            Circle()
                .stroke(Color("AccentPrimary"), lineWidth: 3)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack {
        ProfileHeaderView(player: Player.mockConnected1)
        
        Spacer()
        
        ProfileHeaderView(player: Player.mockConnected1, showEditButton: true) {
            print("Edit tapped")
        }
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}
