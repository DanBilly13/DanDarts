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

// MARK: - Voice Output Route (Phase 1 - UI only)

/// Audio output route options for voice chat
/// Phase 1: UI state only, no actual routing implementation
enum VoiceOutputRoute: String, CaseIterable {
    case speaker = "Speaker"
    case bluetooth = "Bluetooth"
    case phone = "Phone"
    
    var icon: String {
        switch self {
        case .speaker: return "speaker.wave.2"
        case .bluetooth: return "headphones"
        case .phone: return "iphone"
        }
    }
}

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
    case voice_ready
    case voice_request_offer
    case voice_offer
    case voice_answer
    case voice_ice_candidate
    case voice_disconnect
}

struct VoiceReadyPayload: Codable {
    let sessionId: UUID
    let role: String // "challenger" or "receiver"
}

struct VoiceRequestOfferPayload: Codable {
    let sessionId: UUID
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
    var matchId: UUID  // Changed from let to var for replay rebinding
    let challengerId: UUID  // Track participants for replay detection
    let receiverId: UUID    // Track participants for replay detection
    let generation: Int     // Track session generation to detect stale callbacks
    
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
    
    // MARK: - Phase 15-A Investigation
    
    /// Instance ID for tracking ownership and lifecycle
    private let instanceId = UUID()
    
    private override init() {
        super.init()
        print("🔵 [Lifecycle] VoiceChatService.init() - instanceId: \(instanceId)")
        
        // Observe audio route changes (e.g., Bluetooth disconnect)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioRouteChange(notification)
        }
    }
    
    deinit {
        print("🔴 [Lifecycle] VoiceChatService.deinit - instanceId: \(instanceId)")
    }
    
    // MARK: - Private Properties
    
    private let supabaseService = SupabaseService.shared
    private let authService = AuthService.shared
    
    // Signalling state
    private var signallingChannel: RealtimeChannelV2?
    private var broadcastSubscription: RealtimeSubscription?
    private var otherPlayerId: UUID?
    private var localRole: String? // "challenger" or "receiver"
    private var isPeerReady: Bool = false
    private var isLocalReady: Bool = false
    private var offerRequestTimeout: Task<Void, Never>?
    
    /// Session generation counter to detect stale async callbacks
    private var sessionGeneration: Int = 0
    
    // WebRTC components
    private var peerConnectionFactory: RTCPeerConnectionFactory?
    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    // ICE candidate queue for candidates that arrive before remoteDescription
    private var pendingRemoteICECandidates: [(candidate: String, sdpMid: String, sdpMLineIndex: Int)] = []
    private var hasRemoteDescription: Bool = false
    
    /// Primary source of truth for all session state
    @Published private(set) var currentSession: VoiceSession?
    
    /// Derived views extracted from currentSession for SwiftUI observation convenience
    @Published private(set) var connectionState: VoiceSessionState = .idle
    @Published private(set) var muteState: VoiceMuteState = .unmuted
    @Published private(set) var availability: VoiceAvailability = .notApplicable
    
    /// Replay-ready event: matchId when readiness re-announced after replay rebind
    /// RemoteLobbyView observes this to trigger confirmVoiceReady for replay match
    @Published private(set) var replayReadyMatchId: UUID? = nil
    
    /// Derived UI states computed from session state
    @Published private(set) var uiState: VoiceUIState = .hidden
    @Published private(set) var iconState: VoiceIconState = .hidden
    
    /// Voice control menu state (Phase 3 - Apple-style auto-selection)
    @Published private(set) var selectedOutputRoute: VoiceOutputRoute = .speaker
    
    /// Bluetooth availability for UI (updated when route changes)
    @Published private(set) var isBluetoothAvailable: Bool = false
    
    // MARK: - Public Interface
    
    /// Start a voice session for the given remote match
    /// - Parameters:
    ///   - matchId: The UUID of the remote match
    ///   - localUserId: The current user's ID
    ///   - challengerId: The challenger's user ID
    ///   - receiverId: The receiver's user ID
    /// - Throws: VoiceSessionError if session cannot be started
    @MainActor
    func startSession(
        matchId: UUID,
        localUserId: UUID,
        challengerId: UUID,
        receiverId: UUID
    ) async throws {
        print("🟡 [Voice] startSession() START - matchId: \(matchId), instanceId: \(instanceId)")
        print("🟡 [Voice]   localUserId: \(localUserId), challenger: \(challengerId), receiver: \(receiverId)")
        
        // Check for existing session
        if let existing = currentSession {
            // Same match - already handled
            if existing.matchId == matchId {
                print("⚠️ [Voice] Session already exists for this match - sessionId: \(existing.id)")
                return
            }
            
            // Different match - check if replay scenario
            if canReuseSessionForReplay(
                existing: existing,
                challengerId: challengerId,
                receiverId: receiverId
            ) {
                // REPLAY PATH: Reuse session
                print("🔄 [Voice] REPLAY DETECTED - reusing session")
                print("   - Old matchId: \(existing.matchId)")
                print("   - New matchId: \(matchId)")
                
                do {
                    try await rebindSessionForReplay(
                        newMatchId: matchId,
                        challengerId: challengerId,
                        receiverId: receiverId
                    )
                    return
                } catch {
                    print("❌ [Rebind] Failed to rebind session: \(error)")
                    print("🔄 [Rebind] Falling back to full session restart")
                    await endSession()
                    // Continue with normal startSession flow below
                }
            } else {
                // STALE PATH: Cannot reuse - full teardown
                print("⚠️ [Voice] STALE SESSION DETECTED")
                print("   - Old matchId: \(existing.matchId)")
                print("   - New matchId: \(matchId)")
                print("🔴 [Cleanup] Terminating stale session before starting new one")
                await endSession()
            }
        }
        
        // Check if voice is usable (permission + preference)
        // Do NOT request permission here - that's handled by VoicePermissionManager
        guard VoicePermissionManager.shared.isVoiceUsable else {
            print("ℹ️ [VoiceChatService] Voice not usable - creating unavailable session")
            print("   - Permission: \(VoicePermissionManager.shared.microphoneAuthorizationStatus)")
            print("   - App preference: \(VoicePermissionManager.shared.isVoiceEnabledInApp)")
            print("   - Match will continue without voice")
            
            // Increment generation for unavailable session
            sessionGeneration += 1
            let currentGeneration = sessionGeneration
            print("🟡 [Voice] Creating unavailable session - generation: \(currentGeneration)")
            
            let availability: VoiceAvailability = {
                switch VoicePermissionManager.shared.microphoneAuthorizationStatus {
                case .denied:
                    return .permissionDenied
                case .undetermined:
                    return .systemUnavailable
                case .granted:
                    // Permission granted but voice disabled in app
                    return .systemUnavailable
                @unknown default:
                    return .systemUnavailable
                }
            }()
            
            let session = VoiceSession(
                id: UUID(),
                matchId: matchId,
                challengerId: challengerId,
                receiverId: receiverId,
                generation: currentGeneration,
                connectionState: .idle,
                muteState: .unmuted,
                availability: availability,
                createdAt: Date()
            )
            updateSession(session)
            // Do NOT throw - let match flow continue without voice
            return
        }
        
        // Increment session generation for new session
        sessionGeneration += 1
        let currentGeneration = sessionGeneration
        print("🟡 [Voice] Starting new session - generation: \(currentGeneration)")
        
        // Create session in connecting state
        let sessionId = UUID()
        var session = VoiceSession(
            id: sessionId,
            matchId: matchId,
            challengerId: challengerId,
            receiverId: receiverId,
            generation: currentGeneration,
            connectionState: .connecting,
            muteState: .unmuted,
            availability: .available,
            createdAt: Date()
        )
        
        let sessionStartTime = Date()
        print("🟡 [Voice] Creating new session - sessionId: \(sessionId), matchId: \(matchId)")
        print("⏱️ [VoiceDelay] SESSION_START timestamp=\(ISO8601DateFormatter().string(from: sessionStartTime)) matchId=\(matchId.uuidString.prefix(8))")
        updateSession(session)
        
        // Initialize WebRTC components
        do {
            // Initialize factory if needed
            if peerConnectionFactory == nil {
                initializePeerConnectionFactory()
            }
            
            // Configure audio session (but don't activate yet)
            try configureAudioSession()
            
            // Apple-style route selection: prefer Bluetooth if available, else Speaker
            let bluetoothAvailable = isRouteAvailable(.bluetooth)
            isBluetoothAvailable = bluetoothAvailable
            
            if bluetoothAvailable {
                selectedOutputRoute = .bluetooth
                print("🎤 [Route] Auto-selected Bluetooth (available at session start)")
            } else {
                selectedOutputRoute = .speaker
                print("🎤 [Route] Auto-selected Speaker (Bluetooth not available)")
            }
            
            // Activate audio session first
            try activateAudioSession()
            print("🔊 [VoiceEngine] Audio session activated, applying route...")
            
            // Apply route AFTER activation to ensure it sticks
            // Small delay allows iOS to complete activation process
            Thread.sleep(forTimeInterval: 0.15)
            print("🔊 [VoiceEngine] Re-applying route: \(selectedOutputRoute.rawValue)")
            setAudioRoute(selectedOutputRoute)
            
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
        
        // Derive other player ID and role
        let otherPlayerId = (localUserId == challengerId) ? receiverId : challengerId
        let isOfferer = (localUserId == challengerId)
        let role = isOfferer ? "challenger" : "receiver"
        
        // Store role for later use
        self.localRole = role
        self.isPeerReady = false
        self.isLocalReady = false
        
        print("🔊 [VoiceChatService] Role: \(role)")
        print("🔊 [VoiceChatService] Other player: \(otherPlayerId.uuidString.prefix(8))")
        
        // Setup signalling channel immediately
        do {
            let signallingStart = Date()
            try await setupSignallingChannel(matchId: matchId, otherPlayerId: otherPlayerId)
            let signallingDuration = Date().timeIntervalSince(signallingStart)
            print("⏱️ [VoiceTiming] CHECKPOINT 2: Signalling subscription active (took \(String(format: "%.3f", signallingDuration))s)")
            print("✅ [VoiceSignalling] Signalling channel subscription confirmed")
        } catch {
            print("❌ [VoiceChatService] Failed to setup signalling: \(error)")
            session.connectionState = .failed
            updateSession(session)
            throw error
        }
        
        // Send voice_ready to announce presence
        do {
            let readyStart = Date()
            try await sendReady(role: role)
            self.isLocalReady = true
            let readyDuration = Date().timeIntervalSince(readyStart)
            print("⏱️ [VoiceTiming] CHECKPOINT 3: Local voice_ready sent (took \(String(format: "%.3f", readyDuration))s)")
            let readyTimestamp = Date()
        print("✅ [VoiceSignalling] voice_ready sent (role: \(role))")
        print("⏱️ [VoiceDelay] READY_SENT timestamp=\(ISO8601DateFormatter().string(from: readyTimestamp)) role=\(role) matchId=\(matchId.uuidString.prefix(8))")
        } catch {
            print("❌ [VoiceChatService] Failed to send ready: \(error)")
            session.connectionState = .failed
            updateSession(session)
            throw error
        }
        
        // Challenger waits for receiver ready before creating offer
        // Receiver waits for offer (or sends request_offer after timeout)
        if isOfferer {
            print("🔊 [VoiceChatService] Challenger waiting for receiver voice_ready before creating offer")
            // Offer will be created when handleReady() receives receiver's ready message
        } else {
            print("🔊 [VoiceChatService] Receiver waiting for voice_offer from challenger")
            // Start fallback timeout to request offer if not received
            startOfferRequestTimeout()
        }
    }
    
    /// Start timeout to request offer if not received
    @MainActor
    private func startOfferRequestTimeout() {
        offerRequestTimeout?.cancel()
        offerRequestTimeout = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            guard !Task.isCancelled else { return }
            
            // If still no offer received, request one
            if let session = currentSession, session.connectionState == .connecting {
                let requestOfferTimestamp = Date()
            print("⏱️ [VoiceSignalling] No offer received after 5s, sending voice_request_offer")
            print("⏱️ [VoiceDelay] REQUEST_OFFER_TIMEOUT timestamp=\(ISO8601DateFormatter().string(from: requestOfferTimestamp)) matchId=\(session.matchId.uuidString.prefix(8))")
                try? await sendRequestOffer()
            }
        }
    }
    
    // MARK: - Replay Session Reuse
    
    /// Check if existing session can be safely reused for replay
    /// - Parameters:
    ///   - existing: The current voice session
    ///   - challengerId: New match challenger ID
    ///   - receiverId: New match receiver ID
    /// - Returns: True if session can be reused
    @MainActor
    private func canReuseSessionForReplay(
        existing: VoiceSession,
        challengerId: UUID,
        receiverId: UUID
    ) -> Bool {
        // Layer 1: Ordered participants (same roles)
        let sameOrderedParticipants = 
            existing.challengerId == challengerId &&
            existing.receiverId == receiverId
        
        // Layer 2: Unordered participants (same humans, possibly swapped roles)
        let sameUnorderedParticipants = 
            Set([existing.challengerId, existing.receiverId]) ==
            Set([challengerId, receiverId])
        
        // Case 1: Different humans
        if !sameUnorderedParticipants {
            print("❌ [Reuse] Different humans - cannot reuse")
            print("   - Old: challenger=\(existing.challengerId.uuidString.prefix(8)), receiver=\(existing.receiverId.uuidString.prefix(8))")
            print("   - New: challenger=\(challengerId.uuidString.prefix(8)), receiver=\(receiverId.uuidString.prefix(8))")
            return false
        }
        
        // Case 2: Same humans but swapped roles
        if !sameOrderedParticipants {
            print("⚠️ [Reuse] Same humans but SWAPPED ROLES - cannot reuse (policy)")
            print("   - Old: challenger=\(existing.challengerId.uuidString.prefix(8)), receiver=\(existing.receiverId.uuidString.prefix(8))")
            print("   - New: challenger=\(challengerId.uuidString.prefix(8)), receiver=\(receiverId.uuidString.prefix(8))")
            print("   - Reason: Role swap affects offer/answer responsibilities and ready flow")
            return false
        }
        
        // Case 3: Same humans + same roles
        print("✅ [Reuse] Same humans + same roles")
        print("   - challenger=\(challengerId.uuidString.prefix(8)), receiver=\(receiverId.uuidString.prefix(8))")
        
        // Peer connection must exist
        guard peerConnection != nil else {
            print("❌ [Reuse] No peer connection - cannot reuse")
            return false
        }
        
        // Session must not be ending or ended
        guard existing.connectionState != .ended,
              existing.connectionState != .disconnected,
              existing.connectionState != .failed else {
            print("❌ [Reuse] Session in terminal state: \(existing.connectionState) - cannot reuse")
            return false
        }
        
        // Must be connected or connecting
        guard existing.connectionState == .connected ||
              existing.connectionState == .connecting else {
            print("❌ [Reuse] Session not connected/connecting: \(existing.connectionState) - cannot reuse")
            return false
        }
        
        print("   - Peer connection exists: true")
        print("   - Connection state: \(existing.connectionState)")
        return true
    }
    
    /// Rebind existing voice session to new replay match
    /// Preserves peer connection and audio, rebinds match-scoped signaling
    /// - Parameters:
    ///   - newMatchId: The new replay match ID
    ///   - challengerId: Challenger ID (for validation)
    ///   - receiverId: Receiver ID (for validation)
    @MainActor
    private func rebindSessionForReplay(
        newMatchId: UUID,
        challengerId: UUID,
        receiverId: UUID
    ) async throws {
        guard var session = currentSession else {
            throw VoiceSessionError.sessionNotActive
        }
        
        print("🔄 [Rebind] ========== REPLAY SESSION REBIND START ==========")
        print("🔄 [Rebind] Old matchId: \(session.matchId)")
        print("🔄 [Rebind] New matchId: \(newMatchId)")
        print("🔄 [Rebind] Session state: \(session.connectionState)")
        print("🔄 [Rebind] Participants: challenger=\(challengerId), receiver=\(receiverId)")
        
        // Validate participants match session
        guard session.challengerId == challengerId,
              session.receiverId == receiverId else {
            throw VoiceSessionError.signallingFailed(reason: "Participant mismatch")
        }
        
        // CRITICAL: Preserve otherPlayerId before teardown
        // teardownSignallingChannel() clears this, but we need it for setup
        guard let preservedOtherPlayerId = otherPlayerId else {
            throw VoiceSessionError.signallingFailed(reason: "No other player ID")
        }
        
        // Step 1: Update session matchId
        let oldMatchId = session.matchId
        session.matchId = newMatchId
        updateSession(session)
        print("✅ [Rebind] Session matchId updated")
        
        // Step 2: Rebind signaling channel
        // Channel is match-scoped (voice_match_{matchId}), must rebind
        
        print("🔄 [Rebind] Tearing down old signaling channel (match: \(oldMatchId))")
        await teardownSignallingChannel()
        // Note: teardownSignallingChannel() clears otherPlayerId, isPeerReady, isLocalReady
        
        print("🔄 [Rebind] Setting up new signaling channel (match: \(newMatchId))")
        // Restore otherPlayerId that was cleared by teardown
        self.otherPlayerId = preservedOtherPlayerId
        
        try await setupSignallingChannel(matchId: newMatchId, otherPlayerId: preservedOtherPlayerId)
        
        // Step 3: Peer connection and audio preserved (no changes)
        // - peerConnection: still valid for same peer
        // - localAudioTrack: still valid
        // - audioSession: still active
        // - muteState: preserved in session
        
        // Step 4: Reset peer ready flags (new signaling channel)
        // These were cleared by teardownSignallingChannel()
        // Will be re-established through new signaling handshake
        isPeerReady = false
        isLocalReady = false
        
        // Step 5: Re-announce readiness on new channel
        // This triggers the ready handshake flow for the replay match
        print("🔄 [Rebind] Re-announcing readiness for replay match")
        do {
            try await reannounceReadyAfterRebind()
        } catch {
            print("❌ [Rebind] Failed to re-announce readiness: \(error)")
            throw error
        }
        
        print("✅ [Rebind] ========== REPLAY SESSION REBIND COMPLETE ==========")
        print("   - Peer connection: PRESERVED")
        print("   - Audio session: PRESERVED")
        print("   - Local audio track: PRESERVED")
        print("   - Mute state: PRESERVED")
        print("   - Signaling channel: REBOUND to new match")
        print("   - Session matchId: \(session.matchId)")
        print("   - Peer ready flags: RESET and RE-ANNOUNCED")
    }
    
    /// Re-announce voice readiness if session is still connecting
    /// Used when voice window starts to handle delayed peer entry
    @MainActor
    func reannounceReadyIfConnecting() async throws {
        guard let session = currentSession else {
            print("⚠️ [VoiceSignalling] Cannot reannounce: no active session")
            return
        }
        
        // Only re-announce if still trying to connect
        guard session.connectionState == .connecting else {
            print("ℹ️ [VoiceSignalling] Skipping reannounce: already \(session.connectionState)")
            return
        }
        
        guard let role = localRole else {
            print("⚠️ [VoiceSignalling] Cannot reannounce: no local role")
            return
        }
        
        print("🔊 [VoiceWindow] Re-announcing voice_ready as \(role) after window start")
        
        try await sendReady(role: role)
        print("✅ [VoiceWindow] Re-announcement sent")
    }
    
    /// Re-announce voice readiness after replay rebind
    /// Sends voice_ready signal on new channel and waits for peer response
    @MainActor
    private func reannounceReadyAfterRebind() async throws {
        guard let session = currentSession else {
            throw VoiceSessionError.sessionNotActive
        }
        
        guard let role = localRole else {
            throw VoiceSessionError.signallingFailed(reason: "No local role")
        }
        
        print("🔄 [ReplayVoice] ========== RE-ANNOUNCING READINESS ==========")
        print("🔄 [ReplayVoice] Match: \(session.matchId)")
        print("🔄 [ReplayVoice] Role: \(role)")
        print("🔄 [ReplayVoice] Connection state: \(session.connectionState)")
        
        // Send voice_ready on new channel
        do {
            try await sendReady(role: role)
            self.isLocalReady = true
            print("✅ [ReplayVoice] voice_ready sent on rebound channel")
        } catch {
            print("❌ [ReplayVoice] Failed to send ready: \(error)")
            throw error
        }
        
        // If challenger and peer becomes ready, trigger offer
        // (Peer will send their ready after receiving ours)
        if role == "challenger" {
            // Wait briefly for peer ready response
            // In practice, handleReady() will set isPeerReady when peer responds
            print("🔊 [ReplayVoice] Challenger waiting for peer ready response")
            
            // Check if both ready after brief delay
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            if isLocalReady && isPeerReady {
                print("🔊 [ReplayVoice] Both sides ready, creating offer")
                do {
                    let offerSDP = try await createOffer()
                    try await sendOffer(offerSDP)
                    print("✅ [ReplayVoice] Offer sent after replay ready")
                } catch {
                    print("⚠️ [ReplayVoice] Failed to create/send offer: \(error)")
                    // Non-fatal - connection may already be established
                }
            }
        }
        
        // Publish replay-ready event for this match
        // RemoteLobbyView will observe this and call confirmVoiceReady
        self.replayReadyMatchId = session.matchId
        print("✅ [ReplayVoice] replay-ready achieved for match \(session.matchId.uuidString.prefix(8))")
        print("✅ [ReplayVoice] ========== READINESS RE-ANNOUNCED ==========")
    }
    
    /// End the current voice session
    /// CRITICAL: Must fully clear all session state before returning
    @MainActor
    func endSession() async {
        guard let session = currentSession else {
            print("🔴 [Cleanup] endSession() called but no active session - instanceId: \(instanceId)")
            return
        }
        
        print("🔴 [Cleanup] endSession() START - sessionId: \(session.id), matchId: \(session.matchId), generation: \(session.generation), instanceId: \(instanceId)")
        
        // Send disconnect signal to peer (best-effort)
        do {
            print("🔴 [Cleanup] Sending disconnect signal to peer")
            try await sendDisconnect(reason: .session_ended)
        } catch {
            print("⚠️ [Cleanup] Failed to send disconnect signal: \(error)")
            // Continue cleanup even if signal fails
        }
        
        // Cancel any in-flight timeouts
        print("🔴 [Cleanup] Cancelling in-flight timeouts")
        offerRequestTimeout?.cancel()
        offerRequestTimeout = nil
        
        // Teardown signalling channel (sets signallingChannel = nil, broadcastSubscription = nil)
        print("🔴 [Cleanup] Tearing down signalling channel")
        await teardownSignallingChannel()
        
        // Close WebRTC peer connection (sets peerConnection = nil, localAudioTrack = nil)
        print("🔴 [Cleanup] Cleaning up WebRTC components")
        cleanupWebRTC()
        
        // Deactivate audio session
        print("🔴 [Cleanup] Deactivating audio session")
        deactivateAudioSession()
        
        // Clear replay-ready flags
        print("🔴 [Cleanup] Clearing replay-ready flags")
        replayReadyMatchId = nil
        
        // Update session state to ended
        var updatedSession = session
        updatedSession.connectionState = .ended
        updatedSession.endedAt = Date()
        updateSession(updatedSession)
        
        // CRITICAL: Clear session IMMEDIATELY (no delayed Task)
        // This must happen synchronously before endSession() returns
        currentSession = nil
        updateDerivedStates()
        
        print("🔴 [Cleanup] endSession() COMPLETE - session cleared, instanceId: \(instanceId)")
        print("🔴 [Cleanup] State verification:")
        print("   - currentSession: \(currentSession == nil ? "nil ✅" : "NOT NIL ⚠️")")
        print("   - signallingChannel: \(signallingChannel == nil ? "nil ✅" : "NOT NIL ⚠️")")
        print("   - broadcastSubscription: \(broadcastSubscription == nil ? "nil ✅" : "NOT NIL ⚠️")")
        print("   - peerConnection: \(peerConnection == nil ? "nil ✅" : "NOT NIL ⚠️")")
        print("   - localAudioTrack: \(localAudioTrack == nil ? "nil ✅" : "NOT NIL ⚠️")")
        print("   - isPeerReady: \(isPeerReady)")
        print("   - isLocalReady: \(isLocalReady)")
        print("   - replayReadyMatchId: \(replayReadyMatchId == nil ? "nil ✅" : "NOT NIL ⚠️")")
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
    
    /// Select output route and apply audio routing
    /// Manual route changes apply only to the current session (no persistence)
    /// - Parameter route: The route to select
    func selectOutputRoute(_ route: VoiceOutputRoute) {
        print("🎤 [Route] Manual route change: \(route.rawValue) (session-only)")
        selectedOutputRoute = route
        
        // Apply audio routing if session is active
        if currentSession != nil {
            setAudioRoute(route)
        }
    }
    
    /// Set audio output route
    /// - Parameter route: The route to apply
    private func setAudioRoute(_ route: VoiceOutputRoute) {
        print("🔊 [AudioRoute] ========== AUDIO ROUTE CHANGE REQUESTED ==========")
        print("🔊 [AudioRoute] Target route: \(route.rawValue)")
        
        // Log current audio session state BEFORE change
        print("🔊 [AudioRoute] BEFORE - Category: \(audioSession.category.rawValue)")
        print("🔊 [AudioRoute] BEFORE - Mode: \(audioSession.mode.rawValue)")
        print("🔊 [AudioRoute] BEFORE - Is active: \(audioSession.isOtherAudioPlaying)")
        print("🔊 [AudioRoute] BEFORE - Current route outputs:")
        for output in audioSession.currentRoute.outputs {
            print("🔊 [AudioRoute]   - \(output.portType.rawValue): \(output.portName)")
        }
        print("🔊 [AudioRoute] BEFORE - Current route inputs:")
        for input in audioSession.currentRoute.inputs {
            print("🔊 [AudioRoute]   - \(input.portType.rawValue): \(input.portName)")
        }
        
        do {
            switch route {
            case .speaker:
                print("🔊 [AudioRoute] Attempting to override to SPEAKER...")
                try audioSession.overrideOutputAudioPort(.speaker)
                print("✅ [AudioRoute] Override command succeeded")
                
            case .phone:
                print("🔊 [AudioRoute] Attempting to clear override (use default earpiece)...")
                try audioSession.overrideOutputAudioPort(.none)
                print("✅ [AudioRoute] Override cleared")
                
            case .bluetooth:
                print("🔊 [AudioRoute] Bluetooth selected (Phase 3 - clearing override)")
                try audioSession.overrideOutputAudioPort(.none)
                print("ℹ️ [AudioRoute] Override cleared for Bluetooth")
            }
            
            // Small delay to let route change take effect
            Thread.sleep(forTimeInterval: 0.1)
            
            // Log current audio session state AFTER change
            print("🔊 [AudioRoute] AFTER - Current route outputs:")
            for output in audioSession.currentRoute.outputs {
                print("🔊 [AudioRoute]   - \(output.portType.rawValue): \(output.portName)")
            }
            print("🔊 [AudioRoute] ========== AUDIO ROUTE CHANGE COMPLETE ==========")
            
        } catch {
            print("❌ [AudioRoute] Failed to set audio route: \(error)")
            print("❌ [AudioRoute] Error details: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ [AudioRoute] Error domain: \(nsError.domain)")
                print("❌ [AudioRoute] Error code: \(nsError.code)")
            }
        }
    }
    
    /// Check if a specific audio route is currently available
    /// - Parameter route: The route to check
    /// - Returns: True if the route is available, false otherwise
    private func isRouteAvailable(_ route: VoiceOutputRoute) -> Bool {
        switch route {
        case .speaker, .phone:
            // Speaker and phone are always available
            return true
            
        case .bluetooth:
            // Check if any Bluetooth audio devices are connected
            let availableInputs = audioSession.availableInputs ?? []
            let hasBluetoothInput = availableInputs.contains { input in
                input.portType == .bluetoothHFP || 
                input.portType == .bluetoothA2DP ||
                input.portType == .bluetoothLE
            }
            
            let currentOutputs = audioSession.currentRoute.outputs
            let hasBluetoothOutput = currentOutputs.contains { output in
                output.portType == .bluetoothHFP || 
                output.portType == .bluetoothA2DP ||
                output.portType == .bluetoothLE
            }
            
            let isAvailable = hasBluetoothInput || hasBluetoothOutput
            print("🔊 [Route] Bluetooth availability check: \(isAvailable)")
            return isAvailable
        }
    }
    
    /// Handle system audio route changes (e.g., Bluetooth disconnect)
    private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        print("🔊 [RouteChange] Audio route changed, reason: \(reason.rawValue)")
        
        // Update Bluetooth availability whenever routes change
        isBluetoothAvailable = isRouteAvailable(.bluetooth)
        
        // If the current route becomes unavailable (e.g., Bluetooth disconnected)
        if reason == .oldDeviceUnavailable {
            // Fall back to speaker gracefully (session-only, no persistence)
            if selectedOutputRoute == .bluetooth {
                print("🔊 [RouteChange] Bluetooth disconnected, falling back to speaker (session-only)")
                selectedOutputRoute = .speaker
                setAudioRoute(.speaker)
            }
        }
        
        // Re-enforce Speaker when iOS makes automatic routing decisions during audio startup.
        // This helps when WebRTC begins flowing audio and iOS flips output back to Receiver.
        if reason == .newDeviceAvailable || reason == .oldDeviceUnavailable || reason == .categoryChange {
            if selectedOutputRoute == .speaker {
                print("🔊 [RouteChange] Re-enforcing Speaker route after automatic iOS change")
                setAudioRoute(.speaker)
            }
        }
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
        let localUserId = await authService.currentUser?.id.uuidString ?? "NONE"
        print("\n� [Subscribe] ========== CHANNEL SETUP START ==========")
        print("� [Subscribe] instanceId: \(instanceId)")
        print("🟢 [Subscribe] Match ID: \(matchId.uuidString)")
        print("� [Subscribe] Other player ID: \(otherPlayerId.uuidString)")
        print("� [Subscribe] Local user ID: \(localUserId)")
        print("🟢 [Subscribe] Existing channel: \(signallingChannel == nil ? "nil" : "EXISTS ⚠️")")
        print("🟢 [Subscribe] Existing subscription: \(broadcastSubscription == nil ? "nil" : "EXISTS ⚠️")")
        
        // Store other player ID for message routing
        self.otherPlayerId = otherPlayerId
        
        // Create channel name (align with existing remote match pattern if present)
        let channelName = "voice_match_\(matchId.uuidString)"
        
        // Create channel
        let channel = supabaseService.client.realtimeV2.channel(channelName) {
            $0.broadcast.receiveOwnBroadcasts = false
        }
        
        // Store channel reference BEFORE subscribing (prevents deallocation during async subscribe)
        signallingChannel = channel
        
        // Subscribe to the channel
        do {
            // Register broadcast handler BEFORE subscribing, and retain the subscription token
            broadcastSubscription = channel.onBroadcast(event: "voice_signal") { [weak self] (message: [String: AnyJSON]) in
                Task { @MainActor in
                    await self?.handleIncomingMessage(message)
                }
            }
            
            // Use the newer subscribe API that throws errors
            try await channel.subscribeWithError()
            
            print("✅ [VoiceSignalling] Subscription active")
        } catch {
            print("❌ [VoiceSignalling] Subscribe failed: \(error)")
            throw error
        }
    }
    
    /// Teardown Realtime channel
    private func teardownSignallingChannel() async {
        guard let channel = signallingChannel else {
            return
        }
        
        await channel.unsubscribe()
        signallingChannel = nil
        broadcastSubscription = nil
        otherPlayerId = nil
        isPeerReady = false
        isLocalReady = false
        
        print("🔴 [Cleanup] Voice signalling channel closed")
    }
    
    // MARK: - Send Methods
    
    /// Send voice_ready to announce presence and role
    @MainActor
    private func sendReady(role: String) async throws {
        guard let session = currentSession else {
            print("⚠️ [VoiceSignalling] Cannot send ready: no active session")
            throw VoiceSessionError.sessionNotActive
        }
        
        guard let otherPlayerId = otherPlayerId else {
            print("⚠️ [VoiceSignalling] Cannot send ready: no other player ID")
            throw VoiceSessionError.signallingFailed(reason: "No other player ID")
        }
        
        guard let currentUserId = authService.currentUser?.id else {
            print("⚠️ [VoiceSignalling] Cannot send ready: not authenticated")
            throw VoiceSessionError.signallingFailed(reason: "Not authenticated")
        }
        
        let payload = VoiceReadyPayload(sessionId: session.id, role: role)
        
        try await sendMessage(
            type: .voice_ready,
            from: currentUserId,
            to: otherPlayerId,
            matchId: session.matchId,
            payload: payload
        )
    }
    
    /// Send voice_request_offer to ask challenger to resend offer
    @MainActor
    private func sendRequestOffer() async throws {
        guard let session = currentSession else {
            print("⚠️ [VoiceSignalling] Cannot send request_offer: no active session")
            throw VoiceSessionError.sessionNotActive
        }
        
        guard let otherPlayerId = otherPlayerId else {
            print("⚠️ [VoiceSignalling] Cannot send request_offer: no other player ID")
            throw VoiceSessionError.signallingFailed(reason: "No other player ID")
        }
        
        guard let currentUserId = authService.currentUser?.id else {
            print("⚠️ [VoiceSignalling] Cannot send request_offer: not authenticated")
            throw VoiceSessionError.signallingFailed(reason: "Not authenticated")
        }
        
        let payload = VoiceRequestOfferPayload(sessionId: session.id)
        
        try await sendMessage(
            type: .voice_request_offer,
            from: currentUserId,
            to: otherPlayerId,
            matchId: session.matchId,
            payload: payload
        )
    }
    
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
        
        print("\n🟢🟢🟢 [VoiceSignalling] ========== SENDING MESSAGE ==========")
        print("🟢 [VoiceSignalling] Type: \(type.rawValue)")
        print("🟢 [VoiceSignalling] From: \(from.uuidString)")
        print("🟢 [VoiceSignalling] To: \(to.uuidString)")
        print("🟢 [VoiceSignalling] Match ID: \(matchId.uuidString)")
        print("🟢 [VoiceSignalling] Event name: 'voice_signal'")
        
        // Create message envelope as Codable struct
        let message = VoiceBroadcastMessage(
            type: type.rawValue,
            from: from.uuidString,
            to: to.uuidString,
            matchId: matchId.uuidString,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            payload: payload
        )
        
        print("🟢 [VoiceSignalling] Broadcasting on channel...")
        // Send via broadcast (Supabase accepts Codable directly)
        try await channel.broadcast(
            event: "voice_signal",
            message: message
        )
        print("✅ [VoiceSignalling] Broadcast completed successfully")
        print("🟢 [VoiceSignalling] ============================================\n")
    }
    
    // MARK: - Receive Methods
    
    /// Handle incoming broadcast message
    @MainActor
    private func handleIncomingMessage(_ message: [String: AnyJSON]) async {
        // RAW INBOUND MESSAGE LOGGING - BEFORE ANY VALIDATION
        print("\n� [Signal] ========== INCOMING MESSAGE ==========")
        print("� [Signal] instanceId: \(instanceId)")
        print("🟣 [Signal] Full raw message: \(message)")
        
        // Log local context
        let localUserId = authService.currentUser?.id.uuidString ?? "NONE"
        let currentMatchId = currentSession?.matchId.uuidString ?? "NONE"
        let currentSessionId = currentSession?.id.uuidString ?? "NONE"
        print("� [Signal] Local context:")
        print("🟣 [Signal]   - localUserId: \(localUserId)")
        print("� [Signal]   - currentMatchId: \(currentMatchId)")
        print("� [Signal]   - currentSessionId: \(currentSessionId)")
        print("� [Signal]   - signallingChannel exists: \(signallingChannel != nil)")
        print("🟣 [Signal]   - isPeerReady: \(isPeerReady)")
        print("🟣 [Signal]   - isLocalReady: \(isLocalReady)")
        print("🟣 [Signal] ============================================\n")
        
        // Supabase wraps the actual message in a "payload" field
        // Extract the voice message from the broadcast wrapper
        guard case let .object(voiceMessage) = message["payload"] else {
            print("❌ [VoiceSignalling] REJECTED: Missing or invalid payload wrapper")
            return
        }
        print("✅ [VoiceSignalling] FILTER: Extracted voice message from broadcast payload")
        
        // Extract and validate message envelope from the voice message
        guard case let .string(typeString) = voiceMessage["type"],
              let type = VoiceSignallingMessageType(rawValue: typeString) else {
            print("❌ [VoiceSignalling] REJECTED: Invalid or missing type field")
            return
        }
        print("✅ [VoiceSignalling] FILTER: Type parsed: \(type.rawValue)")
        
        guard case let .string(fromString) = voiceMessage["from"],
              let from = UUID(uuidString: fromString) else {
            print("❌ [VoiceSignalling] REJECTED: Invalid or missing from field")
            return
        }
        print("✅ [VoiceSignalling] FILTER: From parsed: \(from.uuidString.prefix(8))")
        
        guard case let .string(toString) = voiceMessage["to"],
              let to = UUID(uuidString: toString) else {
            print("❌ [VoiceSignalling] REJECTED: Invalid or missing to field")
            return
        }
        print("✅ [VoiceSignalling] FILTER: To parsed: \(to.uuidString.prefix(8))")
        
        guard case let .string(matchIdString) = voiceMessage["matchId"],
              let matchId = UUID(uuidString: matchIdString) else {
            print("❌ [VoiceSignalling] REJECTED: Invalid or missing matchId field")
            return
        }
        print("✅ [VoiceSignalling] FILTER: MatchId parsed: \(matchId.uuidString.prefix(8))")
        
        guard case let .object(payloadObject) = voiceMessage["payload"] else {
            print("❌ [VoiceSignalling] REJECTED: Invalid or missing payload field")
            return
        }
        print("✅ [VoiceSignalling] FILTER: Payload parsed successfully")
        
        // Validate message fields
        guard validateMessage(type: type, from: from, to: to, matchId: matchId) else {
            return // Validation logs rejection reason
        }
        
        print("✅ [VoiceSignalling] ACCEPTED: Dispatching to handler for \(type.rawValue)")
        
        // Route to appropriate handler based on type
        switch type {
        case .voice_ready:
            await handleReady(from: from, payload: payloadObject)
            
        case .voice_request_offer:
            await handleRequestOffer(from: from, payload: payloadObject)
            
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
        print("\n🔍 [VoiceSignalling] ========== VALIDATION: \(type.rawValue) ==========")
        
        // Validate matchId matches current session
        guard let session = currentSession else {
            print("❌ [VoiceSignalling] REJECTED: No active session")
            print("🔍 [VoiceSignalling] ==========================================\n")
            return false
        }
        print("✅ [VoiceSignalling] VALIDATE: Active session exists")
        
        guard matchId == session.matchId else {
            print("❌ [VoiceSignalling] REJECTED: Match ID mismatch")
            print("   Message match: \(matchId.uuidString)")
            print("   Session match: \(session.matchId.uuidString)")
            print("🔍 [VoiceSignalling] ==========================================\n")
            return false
        }
        print("✅ [VoiceSignalling] VALIDATE: Match ID matches (\(matchId.uuidString.prefix(8)))")
        
        // Validate from matches expected peer
        guard let otherPlayerId = otherPlayerId else {
            print("❌ [VoiceSignalling] REJECTED: No other player ID set")
            print("🔍 [VoiceSignalling] ==========================================\n")
            return false
        }
        print("✅ [VoiceSignalling] VALIDATE: Other player ID is set (\(otherPlayerId.uuidString.prefix(8)))")
        
        guard from == otherPlayerId else {
            print("❌ [VoiceSignalling] REJECTED: Sender ID mismatch")
            print("   Message from: \(from.uuidString)")
            print("   Expected peer: \(otherPlayerId.uuidString)")
            print("🔍 [VoiceSignalling] ==========================================\n")
            return false
        }
        print("✅ [VoiceSignalling] VALIDATE: Sender matches expected peer (\(from.uuidString.prefix(8)))")
        
        // Validate to matches current user
        guard let currentUserId = authService.currentUser?.id else {
            print("❌ [VoiceSignalling] REJECTED: Not authenticated")
            print("🔍 [VoiceSignalling] ==========================================\n")
            return false
        }
        print("✅ [VoiceSignalling] VALIDATE: Current user authenticated (\(currentUserId.uuidString.prefix(8)))")
        
        guard to == currentUserId else {
            print("❌ [VoiceSignalling] REJECTED: Target user ID mismatch")
            print("   Message to: \(to.uuidString)")
            print("   Current user: \(currentUserId.uuidString)")
            print("🔍 [VoiceSignalling] ==========================================\n")
            return false
        }
        print("✅ [VoiceSignalling] VALIDATE: Target matches current user (\(to.uuidString.prefix(8)))")
        return true
    }
    
    /// Handle incoming voice_ready message
    @MainActor
    private func handleReady(from: UUID, payload: [String: AnyJSON]) async {
        print("⏱️ [VoiceTiming] CHECKPOINT 4: Peer voice_ready received from \(from.uuidString.prefix(8))")
        print("📥 [VoiceSignalling] RECV voice_ready from \(from.uuidString.prefix(8))")
        
        // Guard: Check session generation
        guard let session = currentSession else {
            print("⚠️ [Stale] Ignoring ready - no active session")
            return
        }
        
        guard session.generation == sessionGeneration else {
            print("⚠️ [Stale] Ignoring ready from old session generation (session: \(session.generation), current: \(sessionGeneration))")
            return
        }
        
        // Extract peer role from payload (sessionId is peer's local session, not validated)
        guard case let .string(peerRole) = payload["role"] else {
            print("⚠️ [VoiceSignalling] Invalid ready payload, ignoring")
            return
        }
        
        let readyReceivedTimestamp = Date()
        print("✅ [VoiceSignalling] voice_ready received (peer role: \(peerRole))")
        print("⏱️ [VoiceDelay] READY_RECEIVED timestamp=\(ISO8601DateFormatter().string(from: readyReceivedTimestamp)) peerRole=\(peerRole) matchId=\(session.matchId.uuidString.prefix(8))")
        
        // Mark peer as ready
        self.isPeerReady = true
        
        // Log if this is part of replay rebind
        if session.connectionState == .connected {
            print("✅ [ReplayVoice] peer ready received for replay match \(session.matchId.uuidString.prefix(8))")
        }
        
        // If we are challenger and both sides are ready, create and send offer
        if localRole == "challenger" && isLocalReady && isPeerReady {
            print("🔊 [VoiceSignalling] Both sides ready, challenger creating offer")
            do {
                let offerStart = Date()
                let offerSDP = try await createOffer()
                let offerDuration = Date().timeIntervalSince(offerStart)
                print("⏱️ [VoiceTiming] CHECKPOINT 5: Offer created (took \(String(format: "%.3f", offerDuration))s)")
                try await sendOffer(offerSDP)
                print("✅ [VoiceSignalling] Offer sent after readiness confirmed")
            } catch {
                print("❌ [VoiceSignalling] Failed to create/send offer: \(error)")
            }
        }
    }
    
    /// Handle incoming voice_request_offer message
    @MainActor
    private func handleRequestOffer(from: UUID, payload: [String: AnyJSON]) async {
        print("⏱️ [VoiceTiming] CHECKPOINT 4: Peer request_offer received from \(from.uuidString.prefix(8))")
        print("📥 [VoiceSignalling] RECV voice_request_offer from \(from.uuidString.prefix(8))")
        print("✅ [VoiceSignalling] voice_request_offer received")
        
        // Guard: Check session generation
        guard let session = currentSession,
              session.generation == sessionGeneration else {
            print("⚠️ [Stale] Ignoring request_offer from old session generation")
            return
        }
        
        // If we are challenger, create/resend offer
        if localRole == "challenger" {
            // Mark peer as ready (request proves they're waiting)
            if !isPeerReady {
                print("🔊 [VoiceSignalling] Marking peer ready based on request_offer")
                isPeerReady = true
            }
            
            print("🔊 [VoiceSignalling] Challenger creating offer on request")
            do {
                let offerStart = Date()
                let offerSDP = try await createOffer()
                let offerDuration = Date().timeIntervalSince(offerStart)
                print("⏱️ [VoiceTiming] CHECKPOINT 5: Offer created (took \(String(format: "%.3f", offerDuration))s)")
                try await sendOffer(offerSDP)
                print("✅ [VoiceSignalling] Offer sent successfully")
            } catch {
                print("❌ [VoiceSignalling] Failed to create/send offer: \(error)")
            }
        } else {
            print("⚠️ [VoiceSignalling] Received request_offer but not challenger, ignoring")
        }
    }
    
    /// Handle incoming offer
    @MainActor
    private func handleOffer(from: UUID, payload: [String: AnyJSON]) async {
        print("📥 [VoiceSignalling] RECV voice_offer from \(from.uuidString.prefix(8))")
        
        // Guard: Check session generation
        guard let session = currentSession,
              session.generation == sessionGeneration else {
            print("⚠️ [Stale] Ignoring offer from old session generation")
            return
        }
        
        // Cancel offer request timeout if running
        offerRequestTimeout?.cancel()
        offerRequestTimeout = nil
        
        // Extract SDP from payload (sessionId is peer's local session, not validated)
        guard case let .string(sdp) = payload["sdp"] else {
            print("⚠️ [VoiceSignalling] Invalid offer payload, ignoring")
            return
        }
        
        print("✅ [VoiceSignalling] voice_offer received on receiver")
        print("🔊 [VoiceSignalling] Setting remote offer description")
        
        // Pass to WebRTC engine to process offer and create answer
        do {
            try await handleRemoteOffer(sdp: sdp)
            print("✅ [VoiceSignalling] Remote offer set successfully")
            
            let answerSdp = try await createAnswer()
            print("✅ [VoiceSignalling] Answer created")
            
            // Send answer back to peer
            guard let currentUserId = authService.currentUser?.id,
                  let session = currentSession else {
                print("⚠️ [VoiceSignalling] Cannot send answer: no session")
                return
            }
            
            try await sendAnswer(answerSdp)
            print("✅ [VoiceSignalling] Answer sent to challenger")
            
        } catch {
            print("❌ [VoiceSignalling] Failed to handle offer: \(error)")
        }
    }
    
    /// Handle incoming answer
    private func handleAnswer(from: UUID, payload: [String: AnyJSON]) async {
        print("⏱️ [VoiceTiming] CHECKPOINT 6: Answer received from \(from.uuidString.prefix(8))")
        print("📥 [VoiceSignalling] RECV voice_answer from \(from.uuidString.prefix(8))")
        
        // Guard: Check session generation
        guard let session = currentSession,
              session.generation == sessionGeneration else {
            print("⚠️ [Stale] Ignoring answer from old session generation")
            return
        }
        
        // Extract SDP from payload (sessionId is peer's local session, not validated)
        guard case let .string(sdp) = payload["sdp"] else {
            print("⚠️ [VoiceSignalling] Invalid answer payload, ignoring")
            return
        }
        
        print("✅ [VoiceSignalling] Valid answer received")
        
        // Pass to WebRTC engine to process answer
        do {
            try await handleRemoteAnswer(sdp: sdp)
            print("✅ [VoiceSignalling] Answer processed successfully")
        } catch {
            print("❌ [VoiceSignalling] Failed to handle answer: \(error)")
        }
    }
    
    /// Handle incoming ICE candidate
    private func handleICECandidate(from: UUID, payload: [String: AnyJSON]) async {
        print("📥 [VoiceSignalling] RECV ice_candidate from \(from.uuidString.prefix(8))")
        
        // Guard: Check session generation
        guard let session = currentSession,
              session.generation == sessionGeneration else {
            print("⚠️ [Stale] Ignoring ICE candidate from old session generation")
            return
        }
        
        // Extract and validate payload (sessionId is peer's local session, not validated)
        guard case let .string(candidate) = payload["candidate"],
              case let .string(sdpMid) = payload["sdpMid"] else {
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
        
        // Pass to WebRTC engine to add ICE candidate
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
            
            print("✅ [VoiceEngine] Audio session configured successfully")
            print("   Category: \(audioSession.category.rawValue)")
            print("   Mode: \(audioSession.mode.rawValue)")
            
        } catch {
            print("❌ [VoiceEngine] Failed to configure audio session: \(error)")
            throw VoiceSessionError.audioSessionConfigurationFailed
        }
    }
    
    /// Activate audio session (called after route is selected)
    private func activateAudioSession() throws {
        print("🔊 [VoiceEngine] Activating audio session")
        
        do {
            try audioSession.setActive(true)
            print("✅ [VoiceEngine] Audio session activated")
        } catch {
            print("❌ [VoiceEngine] Failed to activate audio session: \(error)")
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
        
        // Mark that remoteDescription is now set and flush queued ICE candidates
        hasRemoteDescription = true
        await flushPendingICECandidates()
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
        
        // Mark that remoteDescription is now set and flush queued ICE candidates
        hasRemoteDescription = true
        await flushPendingICECandidates()
    }
    
    /// Handle remote ICE candidate (Task 9 integration)
    private func handleRemoteICECandidate(candidate: String, sdpMid: String, sdpMLineIndex: Int) async {
        guard let pc = peerConnection else {
            print("❌ [VoiceEngine] Peer connection not ready")
            return
        }
        
        // Check if remoteDescription has been set
        guard hasRemoteDescription else {
            // Queue the candidate until remoteDescription is set
            pendingRemoteICECandidates.append((candidate: candidate, sdpMid: sdpMid, sdpMLineIndex: sdpMLineIndex))
            return
        }
        
        // remoteDescription is set, add candidate immediately
        let iceCandidate = RTCIceCandidate(
            sdp: candidate,
            sdpMLineIndex: Int32(sdpMLineIndex),
            sdpMid: sdpMid
        )
        
        do {
            try await pc.add(iceCandidate)
        } catch {
            print("❌ [VoiceEngine] Failed to add ICE candidate: \(error)")
        }
    }
    
    /// Flush pending ICE candidates after remoteDescription is set
    private func flushPendingICECandidates() async {
        guard !pendingRemoteICECandidates.isEmpty else {
            return
        }
        
        let queueSize = pendingRemoteICECandidates.count
        
        guard let pc = peerConnection else {
            print("❌ [VoiceEngine] Cannot flush \(queueSize) ICE candidates - peer connection not ready")
            pendingRemoteICECandidates.removeAll()
            return
        }
        
        var successCount = 0
        var failureCount = 0
        
        // Process all queued candidates in arrival order
        for (candidate, sdpMid, sdpMLineIndex) in pendingRemoteICECandidates {
            let iceCandidate = RTCIceCandidate(
                sdp: candidate,
                sdpMLineIndex: Int32(sdpMLineIndex),
                sdpMid: sdpMid
            )
            
            do {
                try await pc.add(iceCandidate)
                successCount += 1
            } catch {
                print("❌ [VoiceEngine] Failed to add queued ICE candidate: \(error)")
                failureCount += 1
            }
        }
        
        // Clear the queue after processing
        pendingRemoteICECandidates.removeAll()
        
        if failureCount > 0 {
            print("⚠️ [VoiceEngine] ICE flush: \(successCount) ok, \(failureCount) failed")
        }
    }
    
    /// Cleanup WebRTC resources
    private func cleanupWebRTC() {
        print("🔊 [VoiceEngine] Cleaning up WebRTC resources")
        
        localAudioTrack = nil
        peerConnection?.close()
        peerConnection = nil
        
        // Reset ICE candidate queue and remoteDescription flag
        pendingRemoteICECandidates.removeAll()
        hasRemoteDescription = false
        
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
                print("⏱️ [VoiceTiming] CHECKPOINT 7: ICE connected")
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
        // Task 12: Send ICE candidate to remote peer via signalling
        Task {
            do {
                try await sendICECandidate(
                    candidate: candidate.sdp,
                    sdpMid: candidate.sdpMid ?? "",
                    sdpMLineIndex: Int(candidate.sdpMLineIndex)
                )
            } catch {
                print("❌ [PeerConnection] Failed to send ICE candidate: \(error)")
            }
        }
    }
    
    /// Called when ICE candidates are removed
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        // ICE candidates removed (normal operation)
    }
    
    /// Called when the peer connection is opened
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("🔊 [PeerConnection] Data channel opened: \(dataChannel.label)")
    }
}
