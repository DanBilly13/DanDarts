//
//  VoiceSessionService.swift
//  DanDart
//
//  Phase 12 - Peer-to-Peer Voice Chat for Remote Matches
//  Task 3: Service shell with safety rails
//
//  This service owns voice session lifecycle for remote matches.
//  Voice is flow-owned, not view-owned.
//

import Foundation
import SwiftUI

// MARK: - Voice Session State

/// Voice session state machine
enum VoiceSessionState: String, Equatable {
    case idle
    case preparing
    case connecting
    case connected
    case muted
    case unavailable
    case ended
}

// MARK: - Voice Session Identity

/// Unique identity for a voice session instance
/// Prevents stale callbacks and cross-session contamination
struct VoiceSessionIdentity: Equatable {
    let matchId: UUID
    let sessionToken: UUID
    let createdAt: Date
}

// MARK: - Voice Session Error

/// Voice session errors (non-blocking)
enum VoiceSessionError: Error {
    case audioSessionFailed
    case signallingFailed
    case peerConnectionFailed
    case iceNegotiationFailed
    case notInRemoteFlow
    case matchIdMismatch
    case sessionAlreadyActive
    case noActiveSession
}

// MARK: - Voice Session Service

/// Flow-owned voice session service for remote matches
/// 
/// Ownership: Belongs to remote match flow layer, not individual views
/// Lifecycle: Controlled by remote flow hooks, not view lifecycle
/// Safety: Idempotent operations, stale callback protection, session versioning
@MainActor
class VoiceSessionService: ObservableObject {
    
    // MARK: - Published State
    
    /// Current voice session state
    @Published private(set) var state: VoiceSessionState = .idle
    
    /// Local mute state (local-only, no remote sync in Phase 12)
    @Published private(set) var isMuted: Bool = false
    
    /// Active session identity (nil when no session)
    @Published private(set) var activeSession: VoiceSessionIdentity?
    
    // MARK: - Dependencies
    
    /// Reference to RemoteMatchService for flow state observation
    private weak var remoteMatchService: RemoteMatchService?
    
    // MARK: - Feature Flag
    
    /// UserDefaults key for voice feature flag
    private static let voiceEnabledKey = "com.dandart.voice.enabled"
    
    /// Global voice feature flag (persisted in UserDefaults)
    /// When false, all voice operations are no-ops
    @Published private(set) var isVoiceEnabled: Bool {
        didSet {
            // Persist to UserDefaults
            UserDefaults.standard.set(isVoiceEnabled, forKey: Self.voiceEnabledKey)
            print("🎤 [VoiceService] Feature flag persisted: \(isVoiceEnabled)")
        }
    }
    
    // MARK: - Initialization
    
    init(remoteMatchService: RemoteMatchService? = nil) {
        self.remoteMatchService = remoteMatchService
        
        // Load feature flag from UserDefaults (default: true)
        self.isVoiceEnabled = UserDefaults.standard.object(forKey: Self.voiceEnabledKey) as? Bool ?? true
        
        print("🎤 [VoiceService] Initialized - voice enabled: \(isVoiceEnabled)")
    }
    
    deinit {
        print("🎤 [VoiceService] Deinit")
    }
    
    // MARK: - Dependency Injection
    
    /// Inject RemoteMatchService dependency
    func setRemoteMatchService(_ service: RemoteMatchService) {
        self.remoteMatchService = service
        print("🎤 [VoiceService] RemoteMatchService injected")
    }
    
    // MARK: - Public Interface
    
    /// Start a voice session for the given match
    /// 
    /// Idempotent: Calling with same matchId when session already active is a no-op
    /// 
    /// - Parameter matchId: The remote match ID
    func startSession(matchId: UUID) {
        // Guard: Feature flag
        guard isVoiceEnabled else {
            print("🎤 [VoiceService] Voice disabled by feature flag")
            return
        }
        
        // Guard: Idempotency - already active for this match
        if let active = activeSession, active.matchId == matchId {
            print("⚠️ [VoiceService] Session already active for match \(matchId.uuidString.prefix(8))...")
            return // NO-OP
        }
        
        // Guard: Validate remote flow is active
        guard let service = remoteMatchService,
              service.isInRemoteFlow,
              service.flowMatchId == matchId else {
            print("❌ [VoiceService] Cannot start - not in remote flow or matchId mismatch")
            state = .unavailable
            return
        }
        
        print("🎤 [VoiceService] Starting session for match \(matchId.uuidString.prefix(8))...")
        
        // Create new session identity
        let newSession = VoiceSessionIdentity(
            matchId: matchId,
            sessionToken: UUID(),
            createdAt: Date()
        )
        
        activeSession = newSession
        state = .preparing
        
        print("✅ [VoiceService] Session created - token: \(newSession.sessionToken.uuidString.prefix(8))...")
        
        // Task 5+ will implement actual signalling/audio/peer connection
        // For now, this is just the shell
    }
    
    /// End the current voice session
    /// 
    /// Idempotent: Calling when no session is active is a no-op
    func endSession() {
        // Guard: Idempotency - no active session
        guard let session = activeSession else {
            print("⚠️ [VoiceService] No active session to end")
            return // NO-OP
        }
        
        print("🎤 [VoiceService] Ending session - token: \(session.sessionToken.uuidString.prefix(8))...")
        
        // Transition to ended state
        state = .ended
        
        // Clear session identity
        activeSession = nil
        
        // Reset mute state
        isMuted = false
        
        print("✅ [VoiceService] Session ended")
        
        // Task 8+ will implement actual cleanup:
        // - Close peer connection
        // - Unsubscribe from signalling
        // - Deactivate audio session
    }
    
    /// Toggle local mute state
    /// 
    /// Only works when connected or already muted
    func toggleMute() {
        // Guard: Can only mute when connected or muted
        guard state == .connected || state == .muted else {
            print("⚠️ [VoiceService] Cannot toggle mute - not connected (state: \(state.rawValue))")
            return
        }
        
        isMuted.toggle()
        
        if isMuted {
            state = .muted
            print("🔇 [VoiceService] Muted")
        } else {
            state = .connected
            print("🔊 [VoiceService] Unmuted")
        }
        
        // Task 9+ will implement actual audio track enable/disable
    }
    
    // MARK: - Session Validation
    
    /// Check if a session identity is still valid
    /// 
    /// Used by async callbacks to reject stale work
    /// 
    /// - Parameter identity: The session identity to validate
    /// - Returns: true if session is still active and matches
    func isSessionValid(_ identity: VoiceSessionIdentity) -> Bool {
        guard let active = activeSession else {
            return false
        }
        
        return active.sessionToken == identity.sessionToken &&
               active.matchId == identity.matchId
    }
    
    // MARK: - State Queries
    
    /// Check if voice is currently available (connected or muted)
    var isVoiceAvailable: Bool {
        state == .connected || state == .muted
    }
    
    /// Check if voice is currently connecting
    var isConnecting: Bool {
        state == .preparing || state == .connecting
    }
    
    /// Check if voice has failed or is unavailable
    var isUnavailable: Bool {
        state == .unavailable
    }
    
    // MARK: - Internal State Transitions (for future tasks)
    
    /// Transition to connecting state
    /// 
    /// Called when signalling begins (Task 5+)
    internal func transitionToConnecting() {
        guard state == .preparing else {
            print("⚠️ [VoiceService] Invalid transition to connecting from \(state.rawValue)")
            return
        }
        
        state = .connecting
        print("🎤 [VoiceService] State: connecting")
    }
    
    /// Transition to connected state
    /// 
    /// Called when peer connection establishes (Task 10+)
    internal func transitionToConnected() {
        guard state == .connecting else {
            print("⚠️ [VoiceService] Invalid transition to connected from \(state.rawValue)")
            return
        }
        
        state = .connected
        isMuted = false
        print("✅ [VoiceService] State: connected")
    }
    
    /// Transition to unavailable state
    /// 
    /// Called when connection fails or drops (Task 10+)
    internal func transitionToUnavailable(error: VoiceSessionError? = nil) {
        if let error = error {
            print("❌ [VoiceService] Error: \(error)")
        }
        
        state = .unavailable
        print("⚠️ [VoiceService] State: unavailable")
        
        // Phase 12: No automatic reconnect
        // State persists as unavailable for remainder of flow
    }
    
    // MARK: - Feature Flag Control (Task 4)
    
    /// Enable or disable voice feature globally
    /// 
    /// When disabled, all voice operations become no-ops
    /// Remote matches continue working exactly as before Phase 12
    /// Persists to UserDefaults automatically via @Published didSet
    /// 
    /// - Parameter enabled: true to enable voice, false to disable
    func setVoiceEnabled(_ enabled: Bool) {
        // Guard: No-op if already set to this value
        guard isVoiceEnabled != enabled else {
            print("🎤 [VoiceService] Voice already \(enabled ? "enabled" : "disabled")")
            return
        }
        
        // Update flag (triggers didSet -> UserDefaults persistence)
        isVoiceEnabled = enabled
        
        if !enabled {
            print("🎤 [VoiceService] Voice disabled globally")
            
            // End any active session
            if activeSession != nil {
                endSession()
            }
        } else {
            print("🎤 [VoiceService] Voice enabled globally")
        }
    }
    
    /// Check if voice is enabled globally
    var isEnabled: Bool {
        isVoiceEnabled
    }
    
    /// Reset voice feature flag to default (enabled)
    /// 
    /// Useful for testing or troubleshooting
    func resetVoiceFlag() {
        setVoiceEnabled(true)
        print("🎤 [VoiceService] Feature flag reset to default (enabled)")
    }
}

// MARK: - Stale Callback Protection Example

extension VoiceSessionService {
    
    /// Example of how async operations should validate session
    /// 
    /// This pattern will be used in Tasks 5+ for signalling, peer connection, etc.
    private func exampleAsyncOperation() {
        // Capture current session identity
        guard let session = activeSession else { return }
        
        Task {
            // Capture session for validation
            let capturedSession = session
            
            // Perform async work
            // await someAsyncWork()
            
            // Validate session still active before mutating state
            guard isSessionValid(capturedSession) else {
                print("⚠️ [VoiceService] Stale callback - session changed, ignoring")
                return // IGNORE stale callback
            }
            
            // Safe to mutate state
            // self.state = .someNewState
        }
    }
}
