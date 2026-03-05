//
//  RemoteTurnRevealState.swift
//  DanDart
//
//  Manages turn reveal animation and turn transition gating for remote matches
//  Handles sequential dart reveal, score animations, and UI locking
//

import SwiftUI
import Foundation

@MainActor
class RemoteTurnRevealState: ObservableObject {
    // MARK: - Published State
    
    @Published var preTurnRevealThrow: [ScoredThrow] = []
    @Published var fullOpponentDarts: [ScoredThrow] = []
    @Published var revealedDartCount: Int = 0
    @Published var showRevealTotal: Bool = false
    @Published var preTurnRevealIsActive: Bool = false
    @Published var lastSeenVisitTimestamp: String?
    @Published var showOpponentScoreAnimation: Bool = false
    
    @Published var turnTransitionLocked: Bool = false
    @Published var displayCurrentPlayerId: UUID?
    @Published var turnUIGateActive: Bool = false
    @Published var showCheckout: Bool = true
    
    // MARK: - Private State
    
    private var revealTask: Task<Void, Never>?
    
    // Timing constants for turn transition phases
    private let revealHoldNs: UInt64 = 1_700_000_000         // 1.7s reveal duration
    private let rotateAnimNs: UInt64 = 350_000_000           // 0.35s card rotation
    private let postRotatePaddingNs: UInt64 = 150_000_000    // 0.15s padding
    
    // MARK: - Lifecycle
    
    func cancelReveal() {
        revealTask?.cancel()
        revealedDartCount = 0
        showRevealTotal = false
        showOpponentScoreAnimation = false
    }
    
    // MARK: - Turn Gate Logic
    
    /// Centralized turn gate evaluation - triggers on either serverCurrentPlayerId or lastVisitPayload.timestamp changes
    func evaluateTurnGate(
        serverCurrentPlayerId: UUID?,
        lastVisitPayload: LastVisitPayload?,
        currentUserId: UUID,
        renderMatch: RemoteMatch?,
        onScoreOverride: @escaping (UUID, Int) -> Void,
        onClearScoreOverride: @escaping () -> Void,
        onUpdateCheckout: @escaping () -> Void,
        reason: String
    ) {
        let serverCP = serverCurrentPlayerId
        let lvp = lastVisitPayload

        // If locked, do NOT auto-sync display id here
        if turnTransitionLocked {
            print("🎯 [TurnGate] evaluate(\(reason)) skipped: locked")
            return
        }

        // If we don't have a payload yet, normal sync
        guard let lvp else {
            displayCurrentPlayerId = serverCP
            print("🎯 [TurnGate] evaluate(\(reason)) no LVP → sync displayCP=\(serverCP?.uuidString.prefix(8) ?? "nil")")
            return
        }

        // Ignore own visit
        guard lvp.playerId != currentUserId else {
            displayCurrentPlayerId = serverCP
            print("🎯 [TurnGate] evaluate(\(reason)) own LVP → sync displayCP")
            return
        }

        // Only gate when it becomes MY turn
        guard serverCP == currentUserId else {
            displayCurrentPlayerId = serverCP
            print("🎯 [TurnGate] evaluate(\(reason)) not my turn → sync displayCP")
            return
        }

        // Avoid re-triggering for same timestamp
        if lastSeenVisitTimestamp == lvp.timestamp {
            displayCurrentPlayerId = serverCP
            print("🎯 [TurnGate] evaluate(\(reason)) same ts → sync displayCP")
            return
        }

        // 🔥 GATED TRANSITION
        print("🎯 [TURN_GATE] TRIGGER(\(reason)): serverCP=\(serverCP?.uuidString.prefix(8) ?? "nil") lvp.pid=\(lvp.playerId.uuidString.prefix(8)) ts=\(lvp.timestamp)")
        lastSeenVisitTimestamp = lvp.timestamp

        // Cancel existing task and reset all gates for safety
        revealTask?.cancel()
        preTurnRevealIsActive = false
        turnTransitionLocked = false
        turnUIGateActive = false
        revealedDartCount = 0
        showRevealTotal = false
        showOpponentScoreAnimation = false
        
        // Set gates ON
        turnTransitionLocked = true
        turnUIGateActive = true
        print("🎯 [TURN_GATE] LOCK ON")
        print("🎯 [TurnGate] UI GATE ON (lock overlay held)")

        // Store full opponent darts for sequential reveal
        fullOpponentDarts = lvp.darts.map { ScoredThrow(baseValue: $0, scoreType: .single) }
        preTurnRevealIsActive = true
        print("🎯 [PreTurnReveal] START sequential reveal darts=\(lvp.darts) ts=\(lvp.timestamp)")

        // CRITICAL: Hold back opponent's score by setting override with OLD score
        let opponentId = lvp.playerId
        let oldScore = lvp.scoreBefore
        onScoreOverride(opponentId, oldScore)
        print("🎯 [PreTurnReveal] Holding opponent score at OLD value: \(oldScore)")

        // Capture variables for Task closure
        let capturedLvp = lvp
        let capturedRenderMatch = renderMatch
        
        // Sequential reveal with score animation
        revealTask = Task { @MainActor in
            do {
                // Dart 1 appears immediately with Throw sound
                SoundManager.shared.playCountdownThud()
                revealedDartCount = 1
                print("🎯 [PreTurnReveal] Dart 1")
                
                // Dart 2 (0.25s later)
                try await Task.sleep(nanoseconds: 250_000_000)
                SoundManager.shared.playCountdownThud()
                revealedDartCount = 2
                print("🎯 [PreTurnReveal] Dart 2")
                
                // Dart 3 (0.25s later)
                try await Task.sleep(nanoseconds: 250_000_000)
                SoundManager.shared.playCountdownThud()
                revealedDartCount = 3
                print("🎯 [PreTurnReveal] Dart 3")
                
                // Total appears (0.25s later, no sound)
                try await Task.sleep(nanoseconds: 250_000_000)
                showRevealTotal = true
                print("🎯 [PreTurnReveal] Total shown")
                
                // Opponent score animation (0.5s later, like hitting save button)
                try await Task.sleep(nanoseconds: 500_000_000)
                SoundManager.shared.playCountdownSaveScore()
                showOpponentScoreAnimation = true
                print("🎯 [PreTurnReveal] Opponent score animation START")
                
                // Wait for animation to reach peak (0.125s)
                try await Task.sleep(nanoseconds: 125_000_000)
                
                // Update opponent's score at animation peak (dramatic reveal!)
                let opponentId = capturedLvp.playerId
                if let match = capturedRenderMatch,
                   let playerScores = match.playerScores,
                   let newScore = playerScores[opponentId] {
                    onScoreOverride(opponentId, newScore)
                    print("🎯 [PreTurnReveal] Opponent score updated at peak: \(newScore)")
                }
                
                // Clear opponent score animation (0.125s later - completes 0.25s total)
                try await Task.sleep(nanoseconds: 125_000_000)
                showOpponentScoreAnimation = false
                print("🎯 [PreTurnReveal] Opponent score animation END")
                
                // Pause to let score settle (0.5s)
                try await Task.sleep(nanoseconds: 500_000_000)
                print("🎯 [PreTurnReveal] Pause complete, ready for rotation")
                
                // Fade out checkout before rotation
                withAnimation(.easeInOut(duration: 0.3)) {
                    showCheckout = false
                }
                print("🎯 [Checkout] Fading out before rotation")
                
                // Wait for fade to complete
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                
                // Rotate card after pause
                print("🎯 [TurnGate] ROTATE (after pause)")
                displayCurrentPlayerId = serverCurrentPlayerId
                
                // Phase B: Keep overlay locked during rotation animation
                try await Task.sleep(nanoseconds: rotateAnimNs + postRotatePaddingNs)
                
                // Now unlock + clear reveal + clear score override
                print("🎯 [TurnGate] UNLOCK UI (after rotate)")
                preTurnRevealIsActive = false
                turnTransitionLocked = false
                turnUIGateActive = false
                revealedDartCount = 0
                showRevealTotal = false
                onClearScoreOverride()
                print("🎯 [TurnGate] displayCP=\(displayCurrentPlayerId?.uuidString.prefix(8) ?? "nil") unlocked")
                
                // Wait 0.5s after unlock, then fade in new checkout
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                
                // Update checkout for new current player
                onUpdateCheckout()
                
                // Fade in checkout if available
                withAnimation(.easeInOut(duration: 0.3)) {
                    showCheckout = true
                }
                print("🎯 [Checkout] Fading in for new player")
            } catch {
                print("🎯 [TURN_GATE] cancelled")
                // Clean up on cancellation
                revealedDartCount = 0
                showRevealTotal = false
                showOpponentScoreAnimation = false
                onClearScoreOverride()
            }
        }
    }
}
