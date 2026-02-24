//
//  GameCardRemote.swift
//  DanDart
//
//  Created by Billingham Daniel on 2026-02-18.
//

import SwiftUI

struct GameCardRemote: View {
    let game: Game
    let onTapped: () -> Void
    
    private var gameNumber: String {
        // Extract "301" from "Remote 301"
        game.title.replacingOccurrences(of: "Remote ", with: "")
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Image panel (fixed width, matches card height)
            Image(game.coverImageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 114)
                .frame(maxHeight: .infinity)
                .clipped()

            // Text panel (fills remaining width)
            VStack(alignment: .leading, spacing: 4) {
                Text("Remote")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColor.brandPrimary)

                Text(gameNumber)
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColor.textPrimary)

                Text(game.subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.inputBackground)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            onTapped()
        }
    }
}

#Preview {
    GameCardRemote(game: Game.remote501) {
        print("Remote 501 tapped")
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
