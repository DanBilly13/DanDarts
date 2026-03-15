//
//  VoiceChatService.swift
//  DanDart
//
//  Service for managing peer-to-peer voice chat in remote matches
//  Phase 12: Voice Chat for Remote Matches
//

import Foundation
import AVFoundation
import Supabase
import WebRTC

// MARK: - Signalling Message Types

/// Message envelope for all voice signalling messages
struct VoiceSignallingMessage: Codable {
    let type: VoiceSignallingMessageType
    let from: UUID
    let to: UUID
    let matchId: UUID
    let timestamp: Date
    let payload: [String: AnyCodable]
}

/// Broadcast message envelope for sending over Realtime
struct VoiceBroadcastMessage<T: Codable>: Codable {
    let type: String
    let from: String
    let to: String
    let matchId: String
    let timestamp: String
    let payload: T
}

enum VoiceSignallingMessageType: String, Codable {
    case voice_offer
    case voice_answer
    case voice_ice_candidate
    case voice_disconnect
}

struct VoiceOfferPayload: Codable {
    let sdp: String
    let sessionId: UUID
}

struct VoiceAnswerPayload: Codable {
    let sdp: String
    let sessionId: UUID
}

struct VoiceICECandidatePayload: Codable {
    let candidate: String
    let sdpMid: String
    let sdpMLineIndex: Int
    let sessionId: UUID
}

struct VoiceDisconnectPayload: Codable {
    let reason: VoiceDisconnectReason
    let sessionId: UUID
}

enum VoiceDisconnectReason: String, Codable {
    case user_exit
    case session_ended
    case error
}

/// Helper for encoding arbitrary Codable values
struct AnyCodable: Codable {
    let value: Any
    
    init<T: Codable>(_ value: T) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let dict as [String: AnyCodable]:
            try container.encode(dict)
        case let array as [AnyCodable]:
            try container.encode(array)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Unsupported type"))
        }
    }
}

// MARK: - State Models

/// Represents the overall connection state of the voice session
enum VoiceSessionState: String, Codable {
    case idle           // No session exists yet for the current flow
    case connecting     // Handshake in progress
    case connected      // Peer connection established, audio active
    case disconnected   // Connection failed or dropped (covers both initial failure and post-connect drop)
    case failed         // Connection failed to establish
    case ended          // Session existed and has been intentionally terminated
}

/// Represents the local microphone mute state
enum VoiceMuteState: String, Codable {
    case unmuted        // Microphone is active, audio is being sent
    case muted          // Microphone is muted, no audio is being sent
}

/// Represents whether voice is available for the current match context
enum VoiceAvailability: String, Codable {
    case notApplicable      // Voice is not applicable in this context (e.g., local match)
    case available          // Voice is applicable and can be used
    case systemUnavailable  // Voice is applicable but system/device constraints prevent use
    case permissionDenied   // Microphone permission explicitly denied by user
}

/// Represents errors that can occur during voice session lifecycle
enum VoiceSessionError: Error {
    // Permission errors
    case microphonePermissionDenied
    case microphonePermissionRestricted
    
    // Connection errors
    case connectionTimeout
    case connectionFailed(reason: String)
    case iceConnectionFailed
    case peerConnectionFailed
    
    // Signalling errors
    case signallingTimeout
    case signallingFailed(reason: String)
    case invalidSignallingMessage
    
    // Audio session errors
    case audioSessionConfigurationFailed
    case audioSessionInterrupted
    case audioSessionRouteChangeFailed
    
    // Session errors
    case sessionInvalid
    case sessionAlreadyActive
    case sessionNotActive
    
    // Unknown
    case unknown(Error)
}

/// Complete state model for a voice session
struct VoiceSession {
    // Identity
    let id: UUID
    let matchId: UUID
    
    // State
    var connectionState: VoiceSessionState
    var muteState: VoiceMuteState
    var availability: VoiceAvailability
    
    // Metadata
    let createdAt: Date
    var connectedAt: Date?
    var disconnectedAt: Date?
    var endedAt: Date?
    
    // Error tracking
    var lastError: VoiceSessionError?
}

// MARK: - UI State Models

/// Derived states for UI display in lobby status line
enum VoiceUIState {
    case hidden             // Voice not applicable (local match) - UI completely hidden
    case connecting         // "Connecting voice..." - shown in remote match lobby
    case ready              // "Voice ready" (connected, unmuted)
    case readyMuted         // "Voice ready" (connected, muted)
    case unavailable        // "Voice not available" - shown when connection failed in remote match
    case permissionNeeded   // "Microphone permission needed" - shown when permission denied
}

/// Derived states for voice control icon
enum VoiceIconState {
    case hidden                     // No icon shown
    case connecting                 // microphone with pulse
    case active                     // microphone
    case muted                      // microphone.slash
    case unavailable                // microphone with warning treatment
    case permissionNeeded           // microphone with alert treatment
}

// MARK: - Voice Chat Service

class VoiceChatService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = VoiceChatService()
    
    private override init() {
        super.init()
        print("🎤 VoiceChatService initialized")
    }
    
    // MARK: - Private Properties
    
    private let supabaseService = SupabaseService.shared
    private let authService = AuthService.shared
    
    // Signalling state
    private var signallingChannel: RealtimeChannelV2?
    private var otherPlayerId: UUID?
    
    // WebRTC components
    private var peerConnectionFactory: RTCPeerConnectionFactory?
    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    /// Primary source of truth for all session state
    @Published private(set) var currentSession: VoiceSession?
    
    /// Derived views extracted from currentSession for SwiftUI observation convenience
    @Published private(set) var connectionState: VoiceSessionState = .idle
    @Published private(set) var muteState: VoiceMuteState = .unmuted
    @Published private(set) var availability: VoiceAvailability = .notApplicable
    
    /// Derived UI states computed from session state
    @Published private(set) var uiState: VoiceUIState = .hidden
    @Published private(set) var iconState: VoiceIconState = .hidden
    
    // MARK: - Public Interface
    
    /// Start a voice session for the given remote match
    /// - Parameter matchId: The UUID of the remote match
    /// - Throws: VoiceSessionError if session cannot be started
    @MainActor
    func startSession(for matchId: UUID) async throws {
        print("🎤 [VoiceChatService] startSession called for match: \(matchId)")
        
        // Validate no existing session for different match
        if let existing = currentSession, existing.matchId != matchId {
            print("⚠️ [VoiceChatService] Terminating stale session for different match")
            await endSession()
        }
        
        // Check if session already exists for this match
        if let existing = currentSession, existing.matchId == matchId {
            print("ℹ️ [VoiceChatService] Session already exists for this match")
            return
        }
        
        // Check if voice is usable (permission + preference)
        // Do NOT request permission here - that's handled by VoicePermissionManager
        guard VoicePermissionManager.shared.isVoiceUsable else {
            print("ℹ️ [VoiceChatService] Voice not usable - creating unavailable session")
            print("   - Permission: \(VoicePermissionManager.shared.microphoneAuthorizationStatus)")
            print("   - App preference: \(VoicePermissionManager.shared.isVoiceEnabledInApp)")
            print("   - Match will continue without voice")
            
            let availability: VoiceAvailability = {
                switch VoicePermissionManager.shared.microphoneAuthorizationStatus {
                case .granted:
                    return .systemUnavailable // App disabled
                case .denied:
                    return .permissionDenied
                case .undetermined:
                    return .systemUnavailable
                @unknown default:
                    return .systemUnavailable
                }
            }()
            
            let session = VoiceSession(
                id: UUID(),
                matchId: matchId,
                connectionState: .idle,
                muteState: .unmuted,
                availability: availability,
                createdAt: Date()
            )
            updateSession(session)
            // Do NOT throw - let match flow continue without voice
            return
        }
        
        // Create session in connecting state
        var session = VoiceSession(
            id: UUID(),
            matchId: matchId,
            connectionState: .connecting,
            muteState: .unmuted,
            availability: .available,
            createdAt: Date()
        )
        
        updateSession(session)
        print("✅ [VoiceChatService] Session created for match: \(matchId)")
        
        // Initialize WebRTC components
        do {
            // Initialize factory if needed
            if peerConnectionFactory == nil {
                initializePeerConnectionFactory()
            }
            
            // Configure audio session
            try configureAudioSession()
            
            // Create peer connection
            try createPeerConnection()
            
            // Add local audio track
            try addLocalAudioTrack()
            
            print("✅ [VoiceChatService] WebRTC initialized successfully")
            
        } catch {
            print("❌ [VoiceChatService] Failed to initialize WebRTC: \(error)")
            session.connectionState = .failed
            session.lastError = error as? VoiceSessionError ?? .unknown(error)
            updateSession(session)
            throw error
        }
        
        // Setup signalling channel (get other player ID from RemoteMatchService)
        // For now, we'll set this up when we receive the first message
        // The actual offer will be created by the challenger role
        
        print("✅ [VoiceChatService] Voice session started, waiting for signalling setup")
    }
    
    /// End the current voice session
    @MainActor
    func endSession() async {
        guard let session = currentSession else {
            print("ℹ️ [VoiceChatService] No active session to end")
            return
        }
        
        print("🎤 [VoiceChatService] Ending session: \(session.id)")
        
        // Send disconnect signal to peer (best-effort)
        do {
            try await sendDisconnect(reason: .session_ended)
        } catch {
            print("⚠️ [VoiceChatService] Failed to send disconnect signal: \(error)")
            // Continue cleanup even if signal fails
        }
        
        // Teardown signalling channel
        await teardownSignallingChannel()
        
        // Close WebRTC peer connection
        cleanupWebRTC()
        
        // Deactivate audio session
        deactivateAudioSession()
        
        var updatedSession = session
        updatedSession.connectionState = .ended
        updatedSession.endedAt = Date()
        
        updateSession(updatedSession)
        
        // Clear session after brief delay to allow UI to show ended state
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            currentSession = nil
            updateDerivedStates()
            print("✅ [VoiceChatService] Session cleared")
        }
    }
    
    /// Toggle mute state
    @MainActor
    func toggleMute() async {
        guard var session = currentSession else {
            print("⚠️ [VoiceChatService] Cannot toggle mute: no active session")
            return
        }
        
        guard session.connectionState == .connected else {
            print("⚠️ [VoiceChatService] Cannot toggle mute: not connected")
            return
        }
        
        let newMuteState: VoiceMuteState = session.muteState == .muted ? .unmuted : .muted
        session.muteState = newMuteState
        
        // Actually mute/unmute local audio track
        if let audioTrack = localAudioTrack {
            audioTrack.isEnabled = (newMuteState == .unmuted)
            print("🔊 [VoiceChatService] Local audio track \(newMuteState == .unmuted ? "enabled" : "disabled")")
        } else {
            print("⚠️ [VoiceChatService] No local audio track to mute/unmute")
        }
        
        updateSession(session)
        print("🎤 [VoiceChatService] Mute toggled to: \(newMuteState)")
    }
    
    /// Set mute state explicitly
    /// - Parameter muted: Whether to mute the microphone
    @MainActor
    func setMute(_ muted: Bool) async {
        guard var session = currentSession else {
            print("⚠️ [VoiceChatService] Cannot set mute: no active session")
            return
        }
        
        guard session.connectionState == .connected else {
            print("⚠️ [VoiceChatService] Cannot set mute: not connected")
            return
        }
        
        let newMuteState: VoiceMuteState = muted ? .muted : .unmuted
        
        if session.muteState == newMuteState {
            return // Already in desired state
        }
        
        session.muteState = newMuteState
        
        // Actually mute/unmute local audio track
        if let audioTrack = localAudioTrack {
            audioTrack.isEnabled = !muted
            print("🔊 [VoiceChatService] Local audio track \(muted ? "disabled" : "enabled")")
        } else {
            print("⚠️ [VoiceChatService] No local audio track to mute/unmute")
        }
        
        updateSession(session)
        print("🎤 [VoiceChatService] Mute set to: \(newMuteState)")
    }
    
    /// Check if the current session is valid for the given match
    /// - Parameter matchId: The match ID to validate against
    /// - Returns: True if session is valid for this match
    func isSessionValid(for matchId: UUID?) -> Bool {
        guard let session = currentSession,
              let matchId = matchId else {
            return false
        }
        return session.matchId == matchId
    }
    
    // MARK: - Private State Management
    
    /// Update the current session and all derived states
    /// This is the single point of mutation for session state
    @MainActor
    private func updateSession(_ session: VoiceSession) {
        // Update source of truth
        currentSession = session
        
        // Extract individual state properties
        connectionState = session.connectionState
        muteState = session.muteState
        availability = session.availability
        
        // Recompute derived UI states
        updateDerivedStates()
    }
    
    /// Recompute derived UI states from current session
    @MainActor
    private func updateDerivedStates() {
        uiState = deriveUIState(
            availability: availability,
            connectionState: connectionState,
            muteState: muteState
        )
        
        iconState = deriveIconState(
            availability: availability,
            connectionState: connectionState,
            muteState: muteState
        )
    }
    
    // MARK: - UI State Derivation
    
    private func deriveUIState(
        availability: VoiceAvailability,
        connectionState: VoiceSessionState,
        muteState: VoiceMuteState
    ) -> VoiceUIState {
        
        // Check availability first
        if availability == .notApplicable {
            return .hidden  // Local match - hide completely
        }
        
        if availability == .permissionDenied {
            return .permissionNeeded  // Remote match - show permission needed
        }
        
        if availability == .systemUnavailable {
            return .unavailable  // Remote match - show unavailable
        }
        
        // availability == .available, check connection state
        switch connectionState {
        case .idle:
            return .hidden
            
        case .connecting:
            return .connecting  // Remote match - show connecting
            
        case .connected:
            return muteState == .muted ? .readyMuted : .ready
            
        case .disconnected, .failed:
            return .unavailable  // Remote match - show unavailable
            
        case .ended:
            return .hidden
        }
    }
    
    private func deriveIconState(
        availability: VoiceAvailability,
        connectionState: VoiceSessionState,
        muteState: VoiceMuteState
    ) -> VoiceIconState {
        
        // Check availability first
        if availability == .notApplicable {
            return .hidden
        }
        
        if availability == .permissionDenied {
            return .permissionNeeded
        }
        
        if availability == .systemUnavailable {
            return .unavailable
        }
        
        // availability == .available, check connection state
        switch connectionState {
        case .idle:
            return .hidden
            
        case .connecting:
            return .connecting
            
        case .connected:
            return muteState == .muted ? .muted : .active
            
        case .disconnected, .failed:
            return .unavailable
            
        case .ended:
            return .hidden
        }
    }
    
    // MARK: - Signalling Channel Management
    
    /// Setup Realtime channel for voice signalling
    private func setupSignallingChannel(matchId: UUID, otherPlayerId: UUID) async throws {
        print("🔊 [VoiceSignalling] Setting up channel for match: \(matchId.uuidString.prefix(8))")
        
        // Store other player ID for message routing
        self.otherPlayerId = otherPlayerId
        
        // Create channel name (align with existing remote match pattern if present)
        let channelName = "voice_match_\(matchId.uuidString)"
        print("🔊 [VoiceSignalling] Channel name: \(channelName)")
        
        // Create channel
        let channel = supabaseService.client.realtimeV2.channel(channelName) {
            $0.broadcast.receiveOwnBroadcasts = false
        }
        
        // Listen for voice signalling messages
        channel.onBroadcast(event: "voice_signal") { [weak self] (message: [String: AnyJSON]) in
            Task { @MainActor in
                await self?.handleIncomingMessage(message)
            }
        }
        
        // Store channel reference
        signallingChannel = channel
        
        // Subscribe to channel (fire and forget - errors handled by Realtime layer)
        await channel.subscribe()
        print("✅ [VoiceSignalling] Channel subscription initiated")
    }
    
    /// Teardown Realtime channel
    private func teardownSignallingChannel() async {
        guard let channel = signallingChannel else {
            print("ℹ️ [VoiceSignalling] No channel to teardown")
            return
        }
        
        print("🔊 [VoiceSignalling] Tearing down channel")
        await channel.unsubscribe()
        signallingChannel = nil
        otherPlayerId = nil
        print("✅ [VoiceSignalling] Channel unsubscribed")
    }
    
    // MARK: - Send Methods
    
    /// Send WebRTC offer to other player
    @MainActor
    private func sendOffer(_ sdp: String) async throws {
        guard let session = currentSession else {
            print("⚠️ [VoiceSignalling] Cannot send offer: no active session")
            throw VoiceSessionError.sessionNotActive
        }
        
        guard let otherPlayerId = otherPlayerId else {
            print("⚠️ [VoiceSignalling] Cannot send offer: no other player ID")
            throw VoiceSessionError.signallingFailed(reason: "No other player ID")
        }
        
        guard let currentUserId = authService.currentUser?.id else {
            print("⚠️ [VoiceSignalling] Cannot send offer: not authenticated")
            throw VoiceSessionError.signallingFailed(reason: "Not authenticated")
        }
        
        let payload = VoiceOfferPayload(sdp: sdp, sessionId: session.id)
        
        try await sendMessage(
            type: .voice_offer,
            from: currentUserId,
            to: otherPlayerId,
            matchId: session.matchId,
            payload: payload
        )
        
        print("🔊 [VoiceSignalling] SEND voice_offer to \(otherPlayerId.uuidString.prefix(8)) (session: \(session.id.uuidString.prefix(8)))")
    }
    
    /// Send WebRTC answer to other player
    @MainActor
    private func sendAnswer(_ sdp: String) async throws {
        guard let session = currentSession else {
            print("⚠️ [VoiceSignalling] Cannot send answer: no active session")
            throw VoiceSessionError.sessionNotActive
        }
        
        guard let otherPlayerId = otherPlayerId else {
            print("⚠️ [VoiceSignalling] Cannot send answer: no other player ID")
            throw VoiceSessionError.signallingFailed(reason: "No other player ID")
        }
        
        guard let currentUserId = authService.currentUser?.id else {
            print("⚠️ [VoiceSignalling] Cannot send answer: not authenticated")
            throw VoiceSessionError.signallingFailed(reason: "Not authenticated")
        }
        
        let payload = VoiceAnswerPayload(sdp: sdp, sessionId: session.id)
        
        try await sendMessage(
            type: .voice_answer,
            from: currentUserId,
            to: otherPlayerId,
            matchId: session.matchId,
            payload: payload
        )
        
        print("🔊 [VoiceSignalling] SEND voice_answer to \(otherPlayerId.uuidString.prefix(8)) (session: \(session.id.uuidString.prefix(8)))")
    }
    
    /// Send ICE candidate to other player
    @MainActor
    private func sendICECandidate(candidate: String, sdpMid: String, sdpMLineIndex: Int) async throws {
        guard let session = currentSession else {
            print("⚠️ [VoiceSignalling] Cannot send ICE candidate: no active session")
            throw VoiceSessionError.sessionNotActive
        }
        
        guard let otherPlayerId = otherPlayerId else {
            print("⚠️ [VoiceSignalling] Cannot send ICE candidate: no other player ID")
            throw VoiceSessionError.signallingFailed(reason: "No other player ID")
        }
        
        guard let currentUserId = authService.currentUser?.id else {
            print("⚠️ [VoiceSignalling] Cannot send ICE candidate: not authenticated")
            throw VoiceSessionError.signallingFailed(reason: "Not authenticated")
        }
        
        let payload = VoiceICECandidatePayload(
            candidate: candidate,
            sdpMid: sdpMid,
            sdpMLineIndex: sdpMLineIndex,
            sessionId: session.id
        )
        
        try await sendMessage(
            type: .voice_ice_candidate,
            from: currentUserId,
            to: otherPlayerId,
            matchId: session.matchId,
            payload: payload
        )
        
        print("🔊 [VoiceSignalling] SEND voice_ice_candidate to \(otherPlayerId.uuidString.prefix(8))")
    }
    
    /// Send disconnect signal to other player
    @MainActor
    private func sendDisconnect(reason: VoiceDisconnectReason) async throws {
        guard let session = currentSession else {
            print("⚠️ [VoiceSignalling] Cannot send disconnect: no active session")
            return // Don't throw, disconnect is best-effort
        }
        
        guard let otherPlayerId = otherPlayerId else {
            print("⚠️ [VoiceSignalling] Cannot send disconnect: no other player ID")
            return // Don't throw, disconnect is best-effort
        }
        
        guard let currentUserId = authService.currentUser?.id else {
            print("⚠️ [VoiceSignalling] Cannot send disconnect: not authenticated")
            return // Don't throw, disconnect is best-effort
        }
        
        let payload = VoiceDisconnectPayload(reason: reason, sessionId: session.id)
        
        do {
            try await sendMessage(
                type: .voice_disconnect,
                from: currentUserId,
                to: otherPlayerId,
                matchId: session.matchId,
                payload: payload
            )
            print("🔊 [VoiceSignalling] SEND voice_disconnect to \(otherPlayerId.uuidString.prefix(8)) (reason: \(reason.rawValue))")
        } catch {
            // Log but don't throw - disconnect is best-effort
            print("⚠️ [VoiceSignalling] Failed to send disconnect (best-effort): \(error)")
        }
    }
    
    /// Generic send method for all message types
    private func sendMessage<T: Codable>(
        type: VoiceSignallingMessageType,
        from: UUID,
        to: UUID,
        matchId: UUID,
        payload: T
    ) async throws {
        guard let channel = signallingChannel else {
            print("❌ [VoiceSignalling] Cannot send message: no channel")
            throw VoiceSessionError.signallingFailed(reason: "No channel")
        }
        
        // Create message envelope as Codable struct
        let message = VoiceBroadcastMessage(
            type: type.rawValue,
            from: from.uuidString,
            to: to.uuidString,
            matchId: matchId.uuidString,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            payload: payload
        )
        
        // Send via broadcast (Supabase accepts Codable directly)
        try await channel.broadcast(
            event: "voice_signal",
            message: message
        )
    }
    
    // MARK: - Receive Methods
    
    /// Handle incoming broadcast message
    @MainActor
    private func handleIncomingMessage(_ message: [String: AnyJSON]) async {
        print("📥 [VoiceSignalling] Received message: \(message)")
        
        // Extract and validate message envelope
        guard case let .string(typeString) = message["type"],
              let type = VoiceSignallingMessageType(rawValue: typeString),
              case let .string(fromString) = message["from"],
              let from = UUID(uuidString: fromString),
              case let .string(toString) = message["to"],
              let to = UUID(uuidString: toString),
              case let .string(matchIdString) = message["matchId"],
              let matchId = UUID(uuidString: matchIdString),
              case let .object(payloadObject) = message["payload"] else {
            print("⚠️ [VoiceSignalling] Invalid message envelope, ignoring")
            return
        }
        
        // Validate message fields
        guard validateMessage(type: type, from: from, to: to, matchId: matchId) else {
            return // Validation logs rejection reason
        }
        
        // Route to appropriate handler based on type
        switch type {
        case .voice_offer:
            await handleOffer(from: from, payload: payloadObject)
            
        case .voice_answer:
            await handleAnswer(from: from, payload: payloadObject)
            
        case .voice_ice_candidate:
            await handleICECandidate(from: from, payload: payloadObject)
            
        case .voice_disconnect:
            await handleDisconnect(from: from, payload: payloadObject)
        }
    }
    
    /// Validate message envelope fields
    @MainActor
    private func validateMessage(
        type: VoiceSignallingMessageType,
        from: UUID,
        to: UUID,
        matchId: UUID
    ) -> Bool {
        // Validate matchId matches current session
        guard let session = currentSession else {
            print("⚠️ [VoiceSignalling] Received \(type.rawValue) but no active session, ignoring")
            return false
        }
        
        guard matchId == session.matchId else {
            print("⚠️ [VoiceSignalling] Received \(type.rawValue) for different match (\(matchId.uuidString.prefix(8)) != \(session.matchId.uuidString.prefix(8))), ignoring")
            return false
        }
        
        // Validate from matches expected peer
        guard let otherPlayerId = otherPlayerId else {
            print("⚠️ [VoiceSignalling] Received \(type.rawValue) but no other player ID set, ignoring")
            return false
        }
        
        guard from == otherPlayerId else {
            print("⚠️ [VoiceSignalling] Received \(type.rawValue) from unexpected sender (\(from.uuidString.prefix(8)) != \(otherPlayerId.uuidString.prefix(8))), ignoring")
            return false
        }
        
        // Validate to matches current user
        guard let currentUserId = authService.currentUser?.id else {
            print("⚠️ [VoiceSignalling] Received \(type.rawValue) but not authenticated, ignoring")
            return false
        }
        
        guard to == currentUserId else {
            print("⚠️ [VoiceSignalling] Received \(type.rawValue) for different user (\(to.uuidString.prefix(8)) != \(currentUserId.uuidString.prefix(8))), ignoring")
            return false
        }
        
        return true
    }
    
    /// Handle incoming offer
    @MainActor
    private func handleOffer(from: UUID, payload: [String: AnyJSON]) async {
        print("📥 [VoiceSignalling] RECV voice_offer from \(from.uuidString.prefix(8))")
        
        // Extract and validate payload
        guard case let .string(sdp) = payload["sdp"],
              case let .string(sessionIdString) = payload["sessionId"],
              let sessionId = UUID(uuidString: sessionIdString) else {
            print("⚠️ [VoiceSignalling] Invalid offer payload, ignoring")
            return
        }
        
        // Validate sessionId matches current session
        guard let session = currentSession, sessionId == session.id else {
            print("⚠️ [VoiceSignalling] Offer sessionId mismatch, ignoring (stale/late message)")
            return
        }
        
        print("📥 [VoiceSignalling] Valid offer received (session: \(sessionId.uuidString.prefix(8)))")
        
        // Task 9: Pass to WebRTC engine to process offer and create answer
        do {
            try await handleRemoteOffer(sdp: sdp)
            let answerSdp = try await createAnswer()
            
            // Send answer back to peer
            guard let currentUserId = authService.currentUser?.id,
                  let session = currentSession else {
                print("⚠️ [VoiceSignalling] Cannot send answer: no session")
                return
            }
            
            try await sendAnswer(answerSdp)
            print("✅ [VoiceSignalling] Answer sent successfully")
            
        } catch {
            print("❌ [VoiceSignalling] Failed to handle offer: \(error)")
        }
    }
    
    /// Handle incoming answer
    private func handleAnswer(from: UUID, payload: [String: AnyJSON]) async {
        print("📥 [VoiceSignalling] RECV voice_answer from \(from.uuidString.prefix(8))")
        
        // Extract and validate payload
        guard case let .string(sdp) = payload["sdp"],
              case let .string(sessionIdString) = payload["sessionId"],
              let sessionId = UUID(uuidString: sessionIdString) else {
            print("⚠️ [VoiceSignalling] Invalid answer payload, ignoring")
            return
        }
        
        // Validate sessionId matches current session
        guard let session = currentSession, sessionId == session.id else {
            print("⚠️ [VoiceSignalling] Answer sessionId mismatch, ignoring (stale/late message)")
            return
        }
        
        print("📥 [VoiceSignalling] Valid answer received (session: \(sessionId.uuidString.prefix(8)))")
        
        // Task 9: Pass to WebRTC engine to process answer
        do {
            try await handleRemoteAnswer(sdp: sdp)
            print("✅ [VoiceSignalling] Answer processed successfully")
        } catch {
            print("❌ [VoiceSignalling] Failed to handle answer: \(error)")
        }
    }
    
    /// Handle incoming ICE candidate
    private func handleICECandidate(from: UUID, payload: [String: AnyJSON]) async {
        print("📥 [VoiceSignalling] RECV voice_ice_candidate from \(from.uuidString.prefix(8))")
        
        // Extract and validate payload
        guard case let .string(candidate) = payload["candidate"],
              case let .string(sdpMid) = payload["sdpMid"],
              case let .string(sessionIdString) = payload["sessionId"],
              let sessionId = UUID(uuidString: sessionIdString) else {
            print("⚠️ [VoiceSignalling] Invalid ICE candidate payload, ignoring")
            return
        }
        
        // Extract sdpMLineIndex - try different AnyJSON cases
        let sdpMLineIndex: Int
        if case let .integer(intValue) = payload["sdpMLineIndex"] {
            sdpMLineIndex = intValue
        } else if case let .double(doubleValue) = payload["sdpMLineIndex"] {
            sdpMLineIndex = Int(doubleValue)
        } else {
            print("⚠️ [VoiceSignalling] Invalid sdpMLineIndex type, ignoring")
            return
        }
        
        // Validate sessionId matches current session
        guard let session = currentSession, sessionId == session.id else {
            print("⚠️ [VoiceSignalling] ICE candidate sessionId mismatch, ignoring (stale/late message)")
            return
        }
        
        print("📥 [VoiceSignalling] Valid ICE candidate received")
        
        // Task 9: Pass to WebRTC engine to add ICE candidate
        await handleRemoteICECandidate(candidate: candidate, sdpMid: sdpMid, sdpMLineIndex: sdpMLineIndex)
    }
    
    /// Handle incoming disconnect
    private func handleDisconnect(from: UUID, payload: [String: AnyJSON]) async {
        print("📥 [VoiceSignalling] RECV voice_disconnect from \(from.uuidString.prefix(8))")
        
        // Extract payload (optional validation - disconnect is best-effort)
        guard case let .string(reasonString) = payload["reason"],
              let reason = VoiceDisconnectReason(rawValue: reasonString) else {
            print("⚠️ [VoiceSignalling] Invalid disconnect payload, but processing anyway (best-effort)")
            // Still process disconnect even if payload invalid
            await handlePeerDisconnect(reason: .error)
            return
        }
        
        // SessionId validation is optional for disconnect (best-effort)
        if case let .string(sessionIdString) = payload["sessionId"],
           let sessionId = UUID(uuidString: sessionIdString),
           let session = currentSession,
           sessionId != session.id {
            print("⚠️ [VoiceSignalling] Disconnect sessionId mismatch, but processing anyway (best-effort)")
        }
        
        print("📥 [VoiceSignalling] Processing disconnect (reason: \(reason.rawValue))")
        await handlePeerDisconnect(reason: reason)
    }
    
    /// Handle peer disconnect (best-effort)
    private func handlePeerDisconnect(reason: VoiceDisconnectReason) async {
        print("🔊 [VoiceSignalling] Peer disconnected (reason: \(reason.rawValue))")
        
        // TODO: Task 13-15 - Trigger session cleanup
        // This is a courtesy signal - actual cleanup should also handle abrupt disconnects
        // await endSession()
    }
    
    // MARK: - Audio Session Configuration (Task 7)
    
    /// Configure iOS audio session for voice chat
    private func configureAudioSession() throws {
        print("🔊 [VoiceEngine] Configuring audio session")
        
        do {
            // Set category for voice chat with background audio support
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .allowBluetoothA2DP]
            )
            
            // Activate the audio session
            try audioSession.setActive(true)
            
            print("✅ [VoiceEngine] Audio session configured successfully")
            print("   Category: \(audioSession.category.rawValue)")
            print("   Mode: \(audioSession.mode.rawValue)")
            
        } catch {
            print("❌ [VoiceEngine] Failed to configure audio session: \(error)")
            throw VoiceSessionError.audioSessionConfigurationFailed
        }
    }
    
    /// Deactivate audio session
    private func deactivateAudioSession() {
        print("🔊 [VoiceEngine] Deactivating audio session")
        
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ [VoiceEngine] Audio session deactivated")
        } catch {
            print("⚠️ [VoiceEngine] Failed to deactivate audio session: \(error)")
        }
    }
    
    // MARK: - WebRTC Peer Connection (Task 8)
    
    /// Initialize WebRTC peer connection factory
    private func initializePeerConnectionFactory() {
        print("🔊 [VoiceEngine] Initializing peer connection factory")
        
        // Initialize WebRTC
        RTCInitializeSSL()
        
        // Create factory with default encoder/decoder factories
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        
        peerConnectionFactory = RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
        
        print("✅ [VoiceEngine] Peer connection factory initialized")
    }
    
    /// Create WebRTC peer connection
    private func createPeerConnection() throws {
        print("🔊 [VoiceEngine] Creating peer connection")
        
        guard let factory = peerConnectionFactory else {
            print("❌ [VoiceEngine] Peer connection factory not initialized")
            throw VoiceSessionError.peerConnectionFailed
        }
        
        // Configure ICE servers (Google STUN)
        let config = RTCConfiguration()
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        ]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        
        // Create peer connection with constraints
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        
        guard let pc = factory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self  // Task 12: Set delegate for connection state monitoring
        ) else {
            print("❌ [VoiceEngine] Failed to create peer connection")
            throw VoiceSessionError.peerConnectionFailed
        }
        
        peerConnection = pc
        
        print("✅ [VoiceEngine] Peer connection created")
        print("   ICE servers: \(config.iceServers.map { $0.urlStrings })")
    }
    
    /// Add local audio track to peer connection
    private func addLocalAudioTrack() throws {
        print("🔊 [VoiceEngine] Adding local audio track")
        
        guard let factory = peerConnectionFactory,
              let pc = peerConnection else {
            print("❌ [VoiceEngine] Peer connection not ready")
            throw VoiceSessionError.peerConnectionFailed
        }
        
        // Create audio source
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = factory.audioSource(with: audioConstraints)
        
        // Create audio track
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        localAudioTrack = audioTrack
        
        // Add track to peer connection
        pc.add(audioTrack, streamIds: ["stream0"])
        
        print("✅ [VoiceEngine] Local audio track added")
    }
    
    /// Create WebRTC offer
    private func createOffer() async throws -> String {
        print("🔊 [VoiceEngine] Creating offer")
        
        guard let pc = peerConnection else {
            print("❌ [VoiceEngine] Peer connection not ready")
            throw VoiceSessionError.peerConnectionFailed
        }
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "false"
            ],
            optionalConstraints: nil
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            pc.offer(for: constraints) { sdp, error in
                if let error = error {
                    print("❌ [VoiceEngine] Failed to create offer: \(error)")
                    continuation.resume(throwing: VoiceSessionError.peerConnectionFailed)
                    return
                }
                
                guard let sdp = sdp else {
                    print("❌ [VoiceEngine] Offer SDP is nil")
                    continuation.resume(throwing: VoiceSessionError.peerConnectionFailed)
                    return
                }
                
                pc.setLocalDescription(sdp) { error in
                    if let error = error {
                        print("❌ [VoiceEngine] Failed to set local description: \(error)")
                        continuation.resume(throwing: VoiceSessionError.peerConnectionFailed)
                        return
                    }
                    
                    print("✅ [VoiceEngine] Offer created and set as local description")
                    continuation.resume(returning: sdp.sdp)
                }
            }
        }
    }
    
    /// Create WebRTC answer
    private func createAnswer() async throws -> String {
        print("🔊 [VoiceEngine] Creating answer")
        
        guard let pc = peerConnection else {
            print("❌ [VoiceEngine] Peer connection not ready")
            throw VoiceSessionError.peerConnectionFailed
        }
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": "false"
            ],
            optionalConstraints: nil
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            pc.answer(for: constraints) { sdp, error in
                if let error = error {
                    print("❌ [VoiceEngine] Failed to create answer: \(error)")
                    continuation.resume(throwing: VoiceSessionError.peerConnectionFailed)
                    return
                }
                
                guard let sdp = sdp else {
                    print("❌ [VoiceEngine] Answer SDP is nil")
                    continuation.resume(throwing: VoiceSessionError.peerConnectionFailed)
                    return
                }
                
                pc.setLocalDescription(sdp) { error in
                    if let error = error {
                        print("❌ [VoiceEngine] Failed to set local description: \(error)")
                        continuation.resume(throwing: VoiceSessionError.peerConnectionFailed)
                        return
                    }
                    
                    print("✅ [VoiceEngine] Answer created and set as local description")
                    continuation.resume(returning: sdp.sdp)
                }
            }
        }
    }
    
    /// Handle remote offer (Task 9 integration)
    private func handleRemoteOffer(sdp: String) async throws {
        print("🔊 [VoiceEngine] Handling remote offer")
        
        guard let pc = peerConnection else {
            print("❌ [VoiceEngine] Peer connection not ready")
            throw VoiceSessionError.peerConnectionFailed
        }
        
        let sessionDescription = RTCSessionDescription(type: .offer, sdp: sdp)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pc.setRemoteDescription(sessionDescription) { error in
                if let error = error {
                    print("❌ [VoiceEngine] Failed to set remote offer: \(error)")
                    continuation.resume(throwing: VoiceSessionError.peerConnectionFailed)
                    return
                }
                
                print("✅ [VoiceEngine] Remote offer set successfully")
                continuation.resume()
            }
        }
    }
    
    /// Handle remote answer (Task 9 integration)
    private func handleRemoteAnswer(sdp: String) async throws {
        print("🔊 [VoiceEngine] Handling remote answer")
        
        guard let pc = peerConnection else {
            print("❌ [VoiceEngine] Peer connection not ready")
            throw VoiceSessionError.peerConnectionFailed
        }
        
        let sessionDescription = RTCSessionDescription(type: .answer, sdp: sdp)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pc.setRemoteDescription(sessionDescription) { error in
                if let error = error {
                    print("❌ [VoiceEngine] Failed to set remote answer: \(error)")
                    continuation.resume(throwing: VoiceSessionError.peerConnectionFailed)
                    return
                }
                
                print("✅ [VoiceEngine] Remote answer set successfully")
                continuation.resume()
            }
        }
    }
    
    /// Handle remote ICE candidate (Task 9 integration)
    private func handleRemoteICECandidate(candidate: String, sdpMid: String, sdpMLineIndex: Int) async {
        print("🔊 [VoiceEngine] Handling remote ICE candidate")
        
        guard let pc = peerConnection else {
            print("❌ [VoiceEngine] Peer connection not ready")
            return
        }
        
        let iceCandidate = RTCIceCandidate(
            sdp: candidate,
            sdpMLineIndex: Int32(sdpMLineIndex),
            sdpMid: sdpMid
        )
        
        do {
            try await pc.add(iceCandidate)
            print("✅ [VoiceEngine] ICE candidate added")
        } catch {
            print("❌ [VoiceEngine] Failed to add ICE candidate: \(error)")
        }
    }
    
    /// Cleanup WebRTC resources
    private func cleanupWebRTC() {
        print("🔊 [VoiceEngine] Cleaning up WebRTC resources")
        
        localAudioTrack = nil
        peerConnection?.close()
        peerConnection = nil
        
        print("✅ [VoiceEngine] WebRTC resources cleaned up")
    }
    
    // TODO: Task 13-15 (Lifecycle)
    // - Integration with remote match flow lifecycle
    // - Cleanup on flow exit
    // - Session validation on navigation
}

// MARK: - RTCPeerConnectionDelegate (Task 12)

extension VoiceChatService: RTCPeerConnectionDelegate {
    
    /// Called when the signaling state changes
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("🔊 [PeerConnection] Signaling state changed: \(stateChanged.rawValue)")
    }
    
    /// Called when media is received on a new stream
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("🔊 [PeerConnection] Stream added: \(stream.streamId)")
        
        // Handle remote audio track
        if let audioTrack = stream.audioTracks.first {
            print("✅ [PeerConnection] Remote audio track received")
            // Audio will play automatically through the audio session
        }
    }
    
    /// Called when a stream is removed
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("🔊 [PeerConnection] Stream removed: \(stream.streamId)")
    }
    
    /// Called when negotiation is needed
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("🔊 [PeerConnection] Negotiation needed")
    }
    
    /// Called when the ICE connection state changes
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("🔊 [PeerConnection] ICE connection state: \(newState.rawValue)")
        
        Task { @MainActor in
            switch newState {
            case .connected, .completed:
                print("✅ [PeerConnection] ICE connected")
                connectionState = .connected
                
            case .checking:
                print("🔄 [PeerConnection] ICE checking")
                connectionState = .connecting
                
            case .disconnected:
                print("⚠️ [PeerConnection] ICE disconnected")
                connectionState = .disconnected
                
            case .failed:
                print("❌ [PeerConnection] ICE failed")
                connectionState = .failed
                
            case .closed:
                print("🔒 [PeerConnection] ICE closed")
                connectionState = .disconnected
                
            case .new, .count:
                break
                
            @unknown default:
                break
            }
        }
    }
    
    /// Called when the ICE gathering state changes
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("🔊 [PeerConnection] ICE gathering state: \(newState.rawValue)")
    }
    
    /// Called when a new ICE candidate is generated (Task 12: Send to peer)
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("🔊 [PeerConnection] ICE candidate generated")
        
        // Task 12: Send ICE candidate to remote peer via signalling
        Task {
            do {
                try await sendICECandidate(
                    candidate: candidate.sdp,
                    sdpMid: candidate.sdpMid ?? "",
                    sdpMLineIndex: Int(candidate.sdpMLineIndex)
                )
                print("✅ [PeerConnection] ICE candidate sent to peer")
            } catch {
                print("❌ [PeerConnection] Failed to send ICE candidate: \(error)")
            }
        }
    }
    
    /// Called when ICE candidates are removed
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("🔊 [PeerConnection] ICE candidates removed: \(candidates.count)")
    }
    
    /// Called when the peer connection is opened
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("🔊 [PeerConnection] Data channel opened: \(dataChannel.label)")
    }
}
