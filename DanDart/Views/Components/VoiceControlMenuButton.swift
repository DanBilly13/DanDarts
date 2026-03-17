//
//  VoiceControlMenuButton.swift
//  DanDart
//
//  Voice control menu button for remote gameplay
//  Phase 13: Voice Controls - Phase 1 Menu Shell
//

import SwiftUI

struct VoiceControlMenuButton: View {
    @EnvironmentObject private var voiceChatService: VoiceChatService
    
    var body: some View {
        Menu {
            if voiceChatService.connectionState == .connected {
                // Connected state: Show routes and mute toggle
                ForEach(VoiceOutputRoute.allCases, id: \.self) { route in
                    routeButton(for: route)
                }
                
                Divider()
                
                muteToggleButton
            } else {
                // Unavailable state: Show unavailable message
                unavailableMessage
            }
        } label: {
            voiceButtonIcon
        }
        // Menu can ALWAYS open (even when unavailable) for UX clarity
    }
    
    // MARK: - Unavailable Message
    
    private var unavailableMessage: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "microphone.slash")
                    .font(.system(size: 16))
                    .foregroundColor(AppColor.textSecondary)
                Text("Voice unavailable")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColor.textPrimary)
            }
            
            Text("Sorry - we were unable to\nconnect voice for this match.")
                .font(.system(size: 14))
                .foregroundColor(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Route Buttons
    
    private func routeButton(for route: VoiceOutputRoute) -> some View {
        Button {
            voiceChatService.selectOutputRoute(route)
        } label: {
            Label {
                Text(route.rawValue)
            } icon: {
                // Show checkmark if selected, otherwise show route icon
                if voiceChatService.selectedOutputRoute == route {
                    Image(systemName: "checkmark")
                } else {
                    Image(systemName: route.icon)
                }
            }
        }
        .disabled(voiceChatService.connectionState != .connected)
    }
    
    // MARK: - Mute Toggle
    
    private var muteToggleButton: some View {
        Button {
            Task {
                await voiceChatService.toggleMute()
            }
        } label: {
            Label {
                Text("Mute")
            } icon: {
                // Show checkmark.circle if muted, circle if unmuted
                if voiceChatService.muteState == .muted {
                    Image(systemName: "checkmark.circle")
                } else {
                    Image(systemName: "circle")
                }
            }
        }
        .disabled(voiceChatService.connectionState != .connected)
    }
    
    // MARK: - Voice Button Icon
    
    private var voiceButtonIcon: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                switch voiceChatService.connectionState {
                case .idle, .connecting:
                    Image(systemName: voiceChatService.selectedOutputRoute.icon)
                        .foregroundColor(AppColor.textSecondary)
                        .opacity(0.5)
                    
                case .connected:
                    // Show selected route icon
                    Image(systemName: voiceChatService.selectedOutputRoute.icon)
                        .foregroundColor(AppColor.interactiveSecondaryBackground)
                    
                case .failed, .disconnected, .ended:
                    Image(systemName: "microphone.slash")
                        .foregroundColor(AppColor.textSecondary)
                        .opacity(0.5)
                }
            }
            .font(.system(size: 20))
            .contentTransition(.symbolEffect(.replace))
            .animation(.easeInOut(duration: 0.2), value: voiceChatService.connectionState)
            .animation(.easeInOut(duration: 0.2), value: voiceChatService.selectedOutputRoute)
            
            // Green dot indicator when connected
            if voiceChatService.connectionState == .connected {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .offset(x: 2, y: -2)
            }
        }
    }
}

// MARK: - Preview

#Preview("Voice Connected - Speaker") {
    VStack(spacing: 20) {
        Text("Voice Connected - Speaker Selected")
            .font(.headline)
        
        VoiceControlMenuButton()
            .environmentObject({
                let service = VoiceChatService.shared
                // Simulate connected state
                Task { @MainActor in
                    // Note: In real preview, you'd need to mock the service state
                    // This is a placeholder showing the component structure
                }
                return service
            }())
    }
    .padding()
    .background(Color.black)
}

#Preview("Voice Connected - Phone") {
    VStack(spacing: 20) {
        Text("Voice Connected - Phone Selected")
            .font(.headline)
            .foregroundColor(.white)
        
        VoiceControlMenuButton()
            .environmentObject(VoiceChatService.shared)
    }
    .padding()
    .background(Color.black)
}

#Preview("Voice Unavailable") {
    VStack(spacing: 20) {
        Text("Voice Unavailable State")
            .font(.headline)
            .foregroundColor(.white)
        
        VoiceControlMenuButton()
            .environmentObject(VoiceChatService.shared)
    }
    .padding()
    .background(Color.black)
}
