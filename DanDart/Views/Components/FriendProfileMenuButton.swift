//
//  FriendProfileMenuButton.swift
//  Dart Freak
//
//  Menu button for friend profile screen
//  Provides actions like Remove Friend
//

import SwiftUI

struct FriendProfileMenuButton: View {
    let onRemoveFriend: () -> Void
    
    var body: some View {
        Menu {
            Button(role: .destructive) {
                onRemoveFriend()
            } label: {
                Label {
                    Text("Remove Friend")
                } icon: {
                    Image(systemName: "person.fill.xmark")
                        .foregroundColor(.red)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColor.textPrimary)
                .frame(width: 32, height: 32)
                .background(AppColor.inputBackground.opacity(0.5))
                .clipShape(Circle())
        }
    }
}

#Preview {
    FriendProfileMenuButton(
        onRemoveFriend: { print("Remove Friend") }
    )
    .preferredColorScheme(.dark)
}
