//
//  RemoteGameplayOverlay.swift
//  DanDart
//
//  Overlay component for remote gameplay states (inactive, saving, revealing)
//

import SwiftUI

struct RemoteGameplayOverlay: View {
    let overlayState: RemoteGameStateAdapter.OverlayState
    let opponentName: String
    let didOpponentBust: Bool
    
    var body: some View {
        if overlayState.isVisible {
            ZStack(alignment: .top) {
                Color.black.opacity(0.70)
                    .ignoresSafeArea(.container, edges: .bottom)
                
                VStack(spacing: 8) {
                    Text(overlayTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColor.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    if let subtitle = overlaySubtitle {
                        Text(subtitle)
                            .font(.body)
                            .foregroundColor(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 48)
            }
        }
    }
    
    private var overlayTitle: String {
        switch overlayState {
        case .none:
            return ""
        case .inactiveLockout:
            return "\(opponentName) is throwing"
        case .saving:
            return "Saving visit..."
        case .revealing:
            return "Visit saved"
        }
    }
    
    private var overlaySubtitle: String? {
        switch overlayState {
        case .none:
            return nil
        case .inactiveLockout:
            return didOpponentBust ? "Bust" : nil
        case .saving:
            return "Please wait"
        case .revealing:
            return nil
        }
    }
}

// MARK: - Previews

#if DEBUG

#Preview("Inactive - Opponent Throwing") {
    ZStack {
        AppColor.backgroundPrimary
            .ignoresSafeArea()
        
        // Mock dartboard buttons
        VStack(spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(1...20, id: \.self) { number in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay {
                            Text("\(number)")
                                .foregroundColor(.white)
                        }
                }
            }
            .padding(.horizontal, 16)
        }
        
        RemoteGameplayOverlay(
            overlayState: .inactiveLockout,
            opponentName: "Neil Armstrong",
            didOpponentBust: false
        )
    }
}

#Preview("Inactive - Opponent Bust") {
    ZStack {
        AppColor.backgroundPrimary
            .ignoresSafeArea()
        
        VStack(spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(1...20, id: \.self) { number in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay {
                            Text("\(number)")
                                .foregroundColor(.white)
                        }
                }
            }
            .padding(.horizontal, 16)
        }
        
        RemoteGameplayOverlay(
            overlayState: .inactiveLockout,
            opponentName: "Neil Armstrong",
            didOpponentBust: true
        )
    }
}

#Preview("Saving Visit") {
    ZStack {
        AppColor.backgroundPrimary
            .ignoresSafeArea()
        
        VStack(spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(1...20, id: \.self) { number in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay {
                            Text("\(number)")
                                .foregroundColor(.white)
                        }
                }
            }
            .padding(.horizontal, 16)
        }
        
        RemoteGameplayOverlay(
            overlayState: .saving,
            opponentName: "Neil Armstrong",
            didOpponentBust: false
        )
    }
}

#Preview("Revealing Score") {
    ZStack {
        AppColor.backgroundPrimary
            .ignoresSafeArea()
        
        VStack(spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(1...20, id: \.self) { number in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .overlay {
                            Text("\(number)")
                                .foregroundColor(.white)
                        }
                }
            }
            .padding(.horizontal, 16)
        }
        
        RemoteGameplayOverlay(
            overlayState: .revealing,
            opponentName: "Neil Armstrong",
            didOpponentBust: false
        )
    }
}

#endif
