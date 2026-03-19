//
//  RemoteGameSyncManager.swift
//  DanDart
//
//  Manages server state synchronization for remote matches
//  Centralizes all realtime update handling and computed state
//

import SwiftUI
import Foundation

@MainActor
class RemoteGameSyncManager: ObservableObject {
    // MARK: - Dependencies
    
    let matchId: UUID
    let challenger: User
    let receiver: User
    let currentUserId: UUID
    
    weak var remoteMatchService: RemoteMatchService?
    weak var gameViewModel: RemoteGameViewModel?
    
    // MARK: - Published State
    
    @Published var serverScores: [UUID: Int]?
    @Published var serverCurrentPlayerId: UUID?
    
    // MARK: - Computed Properties
    
    /// Live match from RemoteMatchService (flowMatch or activeMatch)
    var liveMatch: RemoteMatch? {
        guard let service = remoteMatchService else { return nil }
        
        // Prefer flowMatch if present and matches our ID
        if let fm = service.flowMatch, fm.id == matchId {
            return fm
        }
        // Fallback to activeMatch
        if let am = service.activeMatch?.match, am.id == matchId {
            return am
        }
        return nil
    }
    
    /// Adapter for converting RemoteMatch to game state
    var adapter: RemoteGameStateAdapter? {
        guard let m = liveMatch else { return nil }
        return RemoteGameStateAdapter(
            match: m,
            challenger: challenger,
            receiver: receiver,
            currentUserId: currentUserId
        )
    }
    
    /// Server match (flowMatch from RemoteMatchService)
    var serverMatch: RemoteMatch? {
        remoteMatchService?.flowMatch
    }
    
    /// Primary match data: prefer server, fallback to liveMatch
    var renderMatch: RemoteMatch? {
        serverMatch ?? liveMatch
    }
    
    /// Check if it's my turn (server-authoritative with fallback)
    var isMyTurn: Bool {
        (serverCurrentPlayerId ?? liveMatch?.currentPlayerId) == currentUserId
    }
    
    /// Round number: server-authoritative (increments after both players complete their turns)
    /// Formula: ROUND = (turn_index_in_leg / 2) + 1
    var renderVisitNumber: Int {
        let serverTurnIndex = renderMatch?.turnIndexInLeg
        let vmVisit = gameViewModel?.currentVisit ?? 1
        let roundNumber = serverTurnIndex != nil ? ((serverTurnIndex! / 2) + 1) : vmVisit
        print("🧮 [SyncManager] serverTurnIndex=\(serverTurnIndex?.description ?? "nil") renderRound=\(roundNumber)")
        return roundNumber
    }
    
    // MARK: - Initialization
    
    init(
        matchId: UUID,
        challenger: User,
        receiver: User,
        currentUserId: UUID,
        remoteMatchService: RemoteMatchService? = nil,
        gameViewModel: RemoteGameViewModel? = nil
    ) {
        self.matchId = matchId
        self.challenger = challenger
        self.receiver = receiver
        self.currentUserId = currentUserId
        self.remoteMatchService = remoteMatchService
        self.gameViewModel = gameViewModel
        
        // Initialize from current state
        self.serverScores = remoteMatchService?.flowMatch?.playerScores
        self.serverCurrentPlayerId = remoteMatchService?.flowMatch?.currentPlayerId
    }
    
    // MARK: - Lifecycle
    
    func startSync() {
        print("🔄 [SyncManager] Starting sync for match \(matchId.uuidString.prefix(8))...")
        
        // Update from current state
        updateFromRemoteMatch()
    }
    
    func stopSync() {
        print("🔄 [SyncManager] Stopping sync")
    }
    
    // MARK: - Update Methods
    
    func updateFromRemoteMatch() {
        guard let match = renderMatch else { return }
        
        serverScores = match.playerScores
        serverCurrentPlayerId = match.currentPlayerId
    }
    
    // MARK: - Server Sync Handlers
    
    func handleServerScoresChange(oldValue: [UUID: Int]?, newValue: [UUID: Int]?) {
        guard let vm = gameViewModel else { return }
        
        // Sync VM scores from server when they update
        if let newScores = newValue {
            print("🔄 [SyncManager] Server scores updated, syncing to VM: \(newScores)")
            vm.playerScores = newScores
        }
    }
    
    func handleCurrentPlayerChange(oldValue: UUID?, newValue: UUID?) {
        guard let vm = gameViewModel, let adapter = adapter else { return }
        
        // Sync VM current player index from server when it updates
        if let newPlayerId = newValue {
            if let newIndex = adapter.playerIndex(for: newPlayerId) {
                print("🔄 [SyncManager] Server currentPlayerId updated to \(newPlayerId.uuidString.prefix(8))..., syncing VM index to \(newIndex)")
                vm.currentPlayerIndex = newIndex
            }
        }
    }
    
    func handleLastVisitTimestampChange(oldValue: String?, newValue: String?) {
        print("🔄 [SyncManager] lastVisitPayload.timestamp changed: \(oldValue ?? "nil") → \(newValue ?? "nil")")
    }
    
    func handleMatchStatusChange(oldStatus: RemoteMatchStatus?, newStatus: RemoteMatchStatus?) {
        guard let vm = gameViewModel else { return }
        
        print("🔄 [SyncManager] Match status changed: \(oldStatus?.rawValue ?? "nil") → \(newStatus?.rawValue ?? "nil")")
        
        // Log terminal state detection (view layer will handle exit)
        if let status = newStatus, remoteMatchService?.isTerminalStatus(status) == true {
            print("🚨 [SyncManager] Terminal status detected: \(status.rawValue) - view layer will handle exit")
        }
        
        // Only sync winner for natural completion (not abort/expiry)
        if newStatus == .completed {
            if let winnerId = renderMatch?.winnerId {
                if let winnerPlayer = vm.players.first(where: { $0.id == winnerId }) {
                    if vm.winner == nil {
                        vm.winner = winnerPlayer
                        print("🏆 [SyncManager] Server reported winner: \(winnerPlayer.displayName)")
                        
                        if winnerId != currentUserId {
                            SoundManager.shared.playCountdownWinner()
                        }
                    }
                }
            }
        }
    }
}
