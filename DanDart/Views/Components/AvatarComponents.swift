//
//  AvatarComponents.swift
//  DanDart
//
//  Shared avatar selection components used across the app
//

import SwiftUI

// MARK: - Avatar Type

enum AvatarType {
    case asset
    case symbol
}

// MARK: - Avatar Option

struct AvatarOption {
    let id: String
    let type: AvatarType
}

// MARK: - Avatar Option View

struct AvatarOptionView: View {
    let option: AvatarOption
    let isSelected: Bool
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color("InputBackground"))
                .frame(width: size, height: size)
            
            Group {
                switch option.type {
                case .asset:
                    Image(option.id)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size - 4, height: size - 4)
                        .clipShape(Circle())
                case .symbol:
                    Image(systemName: option.id)
                        .font(.system(size: size * 0.4, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                }
            }
        }
        .overlay(
            Circle()
                .stroke(
                    isSelected ? Color("AccentPrimary") : Color("TextSecondary").opacity(0.2),
                    lineWidth: isSelected ? 3 : 1
                )
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
