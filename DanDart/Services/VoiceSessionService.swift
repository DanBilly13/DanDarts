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
import Supabase
import AVFoundation

// MARK: - Signalling Message Types

/// Signalling message type for WebRTC negotiation
enum SignallingMessageType: String, Codable {
    case offer = "offer"
    case answer = "answer"
    case iceCandidate = "ice-candidate"
    case error = "error"
}

/// Signalling message for WebRTC peer connection establishment
struct SignallingMessage: Codable {
    let type: SignallingMessageType
    let from: UUID
    let to: UUID
    let matchId: UUID
    let sessionToken: UUID
    let timestamp: Date
    
    // Type-specific fields
    let sdp: String?              // For offer/answer
    let candidate: String?        // For ice-candidate
    let sdpMid: String?          // For ice-candidate
    let sdpMLineIndex: Int?      // For ice-candidate
    let error: String?           // For error
    let message: String?         // For error
    
    enum CodingKeys: String, CodingKey {
        case type, from, to, matchId, sessionToken, timestamp
        case sdp, candidate, sdpMid, sdpMLineIndex, error, message
    }
}

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
    
    /// Supabase service for Realtime signalling
    private let supabaseService = SupabaseService.shared
    
    /// Auth service for current user ID
    private let authService = AuthService.shared
    
    // MARK: - Realtime Channel
    
    /// Active Realtime channel for signalling
    private var signallingChannel: RealtimeChannelV2?
    
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
        
        // Configure audio session (Task 8)
        configureAudioSession()
        registerAudioNotifications()
        
        // Subscribe to signalling channel
        Task {
            await subscribeToSignallingChannel(matchId: matchId)
        }
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
        
        // Unsubscribe from signalling channel
        Task {
            await unsubscribeFromSignallingChannel()
        }
        
        // Cleanup audio session (Task 8)
        unregisterAudioNotifications()
        deactivateAudioSession()
        
        // Task 9+ will implement:
        // - Close peer connection
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
    
    // MARK: - Audio Session Management (Task 8)
    
    /// Configure AVAudioSession for voice chat
    /// 
    /// Sets up the audio session with:
    /// - playAndRecord mode (for bidirectional audio)
    /// - voiceChat category (optimized for voice)
    /// - allowBluetooth option (for headsets)
    /// - defaultToSpeaker option (speaker output by default)
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Configure for voice chat
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .defaultToSpeaker]
            )
            
            // Activate the audio session
            try audioSession.setActive(true)
            
            print("✅ [AudioSession] Configured for voice chat")
            print("📊 [AudioSession] Category: playAndRecord, Mode: voiceChat")
            print("📊 [AudioSession] Options: allowBluetooth, defaultToSpeaker")
            
        } catch {
            print("❌ [AudioSession] Configuration failed: \(error)")
            transitionToUnavailable(error: .audioSessionFailed)
        }
    }
    
    /// Deactivate AVAudioSession
    /// 
    /// Called when ending voice session to release audio resources
    private func deactivateAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ [AudioSession] Deactivated")
        } catch {
            print("⚠️ [AudioSession] Deactivation failed: \(error)")
            // Non-fatal - continue cleanup
        }
    }
    
    /// Handle audio session interruption
    /// 
    /// Called when phone call, alarm, or other audio interruption occurs
    /// Phase 12: Transitions to unavailable (no automatic recovery)
    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("⚠️ [AudioSession] Interruption began")
            // Phase 12: No automatic pause/resume
            // Voice becomes unavailable for remainder of match
            transitionToUnavailable()
            
        case .ended:
            print("ℹ️ [AudioSession] Interruption ended")
            // Phase 12: No automatic recovery
            // User must restart match for voice
            
        @unknown default:
            print("⚠️ [AudioSession] Unknown interruption type")
        }
    }
    
    /// Handle audio route change
    /// 
    /// Called when audio route changes (e.g., headphones plugged/unplugged)
    /// Phase 12: Logs but doesn't interrupt voice session
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable:
            print("🔊 [AudioSession] New audio device available")
            
        case .oldDeviceUnavailable:
            print("🔇 [AudioSession] Audio device disconnected")
            
        case .categoryChange:
            print("📊 [AudioSession] Category changed")
            
        case .override:
            print("🔀 [AudioSession] Route override")
            
        case .wakeFromSleep:
            print("⏰ [AudioSession] Wake from sleep")
            
        case .noSuitableRouteForCategory:
            print("⚠️ [AudioSession] No suitable route for category")
            
        case .routeConfigurationChange:
            print("🔧 [AudioSession] Route configuration changed")
            
        @unknown default:
            print("⚠️ [AudioSession] Unknown route change reason")
        }
        
        // Phase 12: Continue voice session regardless of route change
        // Audio will automatically route to new device
    }
    
    /// Register for audio session notifications
    /// 
    /// Called when starting voice session
    private func registerAudioNotifications() {
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        print("✅ [AudioSession] Registered for notifications")
    }
    
    /// Unregister from audio session notifications
    /// 
    /// Called when ending voice session
    private func unregisterAudioNotifications() {
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.removeObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        notificationCenter.removeObserver(
            self,
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        print("✅ [AudioSession] Unregistered from notifications")
    }
    
    // MARK: - Signalling Channel Management (Task 6)
    
    /// Subscribe to Supabase Realtime channel for signalling
    private func subscribeToSignallingChannel(matchId: UUID) async {
        // Capture session for validation
        guard let session = activeSession else {
            print("⚠️ [Signalling] No active session, cannot subscribe")
            return
        }
        
        let capturedSession = session
        
        // Channel name: voice:match:{matchId}
        let channelName = "voice:match:\(matchId.uuidString)"
        print("🔊 [Signalling] Subscribing to channel: \(channelName)")
        
        // Create channel
        let channel = supabaseService.client.realtimeV2.channel(channelName) {
            $0.broadcast.receiveOwnBroadcasts = false
        }
        
        // Store channel reference
        signallingChannel = channel
        
        // Subscribe to broadcast messages using onBroadcast callback
        channel.onBroadcast(event: "voice-signal") { [weak self] message in
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                // Validate session still active
                guard self.isSessionValid(capturedSession) else {
                    print("⚠️ [Signalling] Stale message - session changed, ignoring")
                    return
                }
                
                // Handle signalling message
                await self.handleSignallingMessage(message)
            }
        }
        
        // Subscribe to channel
        await channel.subscribe()
        
        print("✅ [Signalling] Subscribed to channel: \(channelName)")
        
        // Transition to connecting state
        await MainActor.run {
            transitionToConnecting()
        }
    }
    
    /// Unsubscribe from Supabase Realtime channel
    private func unsubscribeFromSignallingChannel() async {
        guard let channel = signallingChannel else {
            print("⚠️ [Signalling] No active channel to unsubscribe")
            return
        }
        
        print("🔊 [Signalling] Unsubscribing from channel")
        
        // Unsubscribe from channel (callbacks are automatically cleaned up)
        await channel.unsubscribe()
        
        // Clear channel reference
        signallingChannel = nil
        
        print("✅ [Signalling] Unsubscribed from channel")
    }
    
    // MARK: - Signalling Message Handling (Task 6)
    
    /// Handle incoming signalling message
    private func handleSignallingMessage(_ payload: [String: AnyJSON]) async {
        print("🔊 [Signalling] Received message")
        
        // Convert AnyJSON to Any for JSON serialization
        let convertedPayload = payload.mapValues { $0.value }
        
        // Decode message
        guard let message = try? decodeSignallingMessage(convertedPayload) else {
            print("❌ [Signalling] Failed to decode message")
            return
        }
        
        // Validate message
        guard validateSignallingMessage(message) else {
            print("⚠️ [Signalling] Message validation failed, ignoring")
            return
        }
        
        // Handle by type
        switch message.type {
        case .offer:
            await handleOffer(message)
        case .answer:
            await handleAnswer(message)
        case .iceCandidate:
            await handleIceCandidate(message)
        case .error:
            await handleError(message)
        }
    }
    
    /// Decode signalling message from JSON payload
    private func decodeSignallingMessage(_ payload: [String: Any]) throws -> SignallingMessage {
        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SignallingMessage.self, from: data)
    }
    
    /// Validate incoming signalling message
    private func validateSignallingMessage(_ message: SignallingMessage) -> Bool {
        // Validate session token
        guard message.sessionToken == activeSession?.sessionToken else {
            print("⚠️ [Signalling] Invalid session token")
            return false
        }
        
        // Validate match ID
        guard message.matchId == activeSession?.matchId else {
            print("⚠️ [Signalling] Invalid match ID")
            return false
        }
        
        // Validate recipient (message is for us)
        guard let currentUserId = authService.currentUser?.id,
              message.to == currentUserId else {
            print("⚠️ [Signalling] Message not for current user")
            return false
        }
        
        // Validate sender (message is from expected peer)
        guard let match = remoteMatchService?.flowMatch,
              message.from == match.challengerId || message.from == match.receiverId else {
            print("⚠️ [Signalling] Message from unknown sender")
            return false
        }
        
        return true
    }
    
    // MARK: - Signalling Message Handlers (Task 6)
    
    /// Handle incoming offer message
    private func handleOffer(_ message: SignallingMessage) async {
        print("🔊 [Signalling] Received OFFER from \(message.from.uuidString.prefix(8))...")
        
        guard let sdp = message.sdp else {
            print("❌ [Signalling] Offer missing SDP")
            return
        }
        
        print("📝 [Signalling] SDP: \(sdp.prefix(100))...")
        
        // Task 9+ will handle offer with WebRTC peer connection
        // For now, just log
    }
    
    /// Handle incoming answer message
    private func handleAnswer(_ message: SignallingMessage) async {
        print("🔊 [Signalling] Received ANSWER from \(message.from.uuidString.prefix(8))...")
        
        guard let sdp = message.sdp else {
            print("❌ [Signalling] Answer missing SDP")
            return
        }
        
        print("📝 [Signalling] SDP: \(sdp.prefix(100))...")
        
        // Task 9+ will handle answer with WebRTC peer connection
        // For now, just log
    }
    
    /// Handle incoming ICE candidate message
    private func handleIceCandidate(_ message: SignallingMessage) async {
        print("🔊 [Signalling] Received ICE-CANDIDATE from \(message.from.uuidString.prefix(8))...")
        
        guard let candidate = message.candidate else {
            print("❌ [Signalling] ICE candidate missing candidate string")
            return
        }
        
        print("📝 [Signalling] Candidate: \(candidate.prefix(50))...")
        
        // Task 9+ will add ICE candidate to WebRTC peer connection
        // For now, just log
    }
    
    /// Handle incoming error message
    private func handleError(_ message: SignallingMessage) async {
        print("❌ [Signalling] Received ERROR from \(message.from.uuidString.prefix(8))...")
        
        if let error = message.error {
            print("❌ [Signalling] Error code: \(error)")
        }
        
        if let errorMessage = message.message {
            print("❌ [Signalling] Error message: \(errorMessage)")
        }
        
        // Transition to unavailable
        await MainActor.run {
            transitionToUnavailable()
        }
    }
    
    // MARK: - Signalling Message Sending (Task 6)
    
    /// Send offer to peer
    func sendOffer(sdp: String) async {
        guard let session = activeSession else {
            print("⚠️ [Signalling] No active session, cannot send offer")
            return
        }
        
        guard let currentUserId = authService.currentUser?.id else {
            print("❌ [Signalling] No current user")
            return
        }
        
        guard let match = remoteMatchService?.flowMatch else {
            print("❌ [Signalling] No active match")
            return
        }
        
        // Determine recipient (other player)
        let recipientId = match.challengerId == currentUserId ? match.receiverId : match.challengerId
        
        let message = SignallingMessage(
            type: .offer,
            from: currentUserId,
            to: recipientId,
            matchId: session.matchId,
            sessionToken: session.sessionToken,
            timestamp: Date(),
            sdp: sdp,
            candidate: nil,
            sdpMid: nil,
            sdpMLineIndex: nil,
            error: nil,
            message: nil
        )
        
        await sendSignallingMessage(message)
        print("🔊 [Signalling] Sent OFFER to \(recipientId.uuidString.prefix(8))...")
    }
    
    /// Send answer to peer
    func sendAnswer(sdp: String) async {
        guard let session = activeSession else {
            print("⚠️ [Signalling] No active session, cannot send answer")
            return
        }
        
        guard let currentUserId = authService.currentUser?.id else {
            print("❌ [Signalling] No current user")
            return
        }
        
        guard let match = remoteMatchService?.flowMatch else {
            print("❌ [Signalling] No active match")
            return
        }
        
        // Determine recipient (other player)
        let recipientId = match.challengerId == currentUserId ? match.receiverId : match.challengerId
        
        let message = SignallingMessage(
            type: .answer,
            from: currentUserId,
            to: recipientId,
            matchId: session.matchId,
            sessionToken: session.sessionToken,
            timestamp: Date(),
            sdp: sdp,
            candidate: nil,
            sdpMid: nil,
            sdpMLineIndex: nil,
            error: nil,
            message: nil
        )
        
        await sendSignallingMessage(message)
        print("🔊 [Signalling] Sent ANSWER to \(recipientId.uuidString.prefix(8))...")
    }
    
    /// Send ICE candidate to peer
    func sendIceCandidate(candidate: String, sdpMid: String?, sdpMLineIndex: Int?) async {
        guard let session = activeSession else {
            print("⚠️ [Signalling] No active session, cannot send ICE candidate")
            return
        }
        
        guard let currentUserId = authService.currentUser?.id else {
            print("❌ [Signalling] No current user")
            return
        }
        
        guard let match = remoteMatchService?.flowMatch else {
            print("❌ [Signalling] No active match")
            return
        }
        
        // Determine recipient (other player)
        let recipientId = match.challengerId == currentUserId ? match.receiverId : match.challengerId
        
        let message = SignallingMessage(
            type: .iceCandidate,
            from: currentUserId,
            to: recipientId,
            matchId: session.matchId,
            sessionToken: session.sessionToken,
            timestamp: Date(),
            sdp: nil,
            candidate: candidate,
            sdpMid: sdpMid,
            sdpMLineIndex: sdpMLineIndex,
            error: nil,
            message: nil
        )
        
        await sendSignallingMessage(message)
        print("🔊 [Signalling] Sent ICE-CANDIDATE to \(recipientId.uuidString.prefix(8))...")
    }
    
    /// Send signalling message via Realtime broadcast
    private func sendSignallingMessage(_ message: SignallingMessage) async {
        guard let channel = signallingChannel else {
            print("❌ [Signalling] No active channel, cannot send message")
            return
        }
        
        // Send via broadcast (Supabase handles Codable encoding)
        do {
            try await channel.broadcast(event: "voice-signal", message: message)
        } catch {
            print("❌ [Signalling] Failed to send message: \(error)")
        }
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
