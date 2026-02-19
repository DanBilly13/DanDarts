//
//  GameCardRemote.swift
//  DanDart
//
//  Created by Billingham Daniel on 2026-02-18.
//

import SwiftUI

enum RemoteGameType {
    case game301
    case game501
    
    var title: String {
        switch self {
        case .game301: return "301"
        case .game501: return "501"
        }
    }
    
    var cardImg: String {
        switch self {
        case .game301: return "SplashScreen"
        case .game501: return "SplashScreen"
        }
    }
    
    var cardImgBg: Color {
        switch self {
        case .game301: return AppColor.player3
        case .game501: return AppColor.player4
        }
    }
}

struct GameCardRemote: View {
    let gameType: RemoteGameType
    
    var body: some View {
        HStack(spacing: 0) {
            // Image panel (fixed width, matches card height)
            Image(gameType.cardImg)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 114)
                .frame(maxHeight: .infinity)
                .background(gameType.cardImgBg)
                .clipped()

            // Text panel (fills remaining width)
            VStack(alignment: .leading, spacing: 4) {
                Text("Remote")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)

                Text(gameType.title)
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.semibold)

                Text("Play together. Apart")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.inputBackground)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    
}

#Preview {
    GameCardRemote(gameType: .game501)
}
