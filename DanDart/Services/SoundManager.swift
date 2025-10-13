//
//  SoundManager.swift
//  DanDart
//
//  Sound management service for game audio effects
//

import Foundation
import AVFoundation
import AudioToolbox

class SoundManager: ObservableObject {
    static let shared = SoundManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var isInitialized = false
    private var consecutiveMisses = 0
    
    private init() {
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            isInitialized = true
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Bell Sound Methods
    
    /// Play bell sound effect (currently uses system sound as placeholder)
    func playBell() {
        // Option 1: System Sound (immediate, no file needed)
        playSystemBell()
        
        // Option 2: Custom bell.mp3 (ready for when file is added)
        // playCustomBell()
    }
    
    /// Play system bell sound as placeholder
    private func playSystemBell() {
        // Use system sound ID 1013 (Classic system bell/ding sound)
        AudioServicesPlaySystemSound(1013)
    }
    
    /// Play custom bell.mp3 file (ready for implementation)
    private func playCustomBell() {
        guard isInitialized else {
            print("Audio session not initialized")
            return
        }
        
        guard let bellURL = Bundle.main.url(forResource: "bell", withExtension: "mp3") else {
            print("Bell sound file not found - using system sound fallback")
            playSystemBell()
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: bellURL)
            audioPlayer?.volume = 0.7 // Appropriate volume
            audioPlayer?.play()
        } catch {
            print("Failed to play bell sound: \(error)")
            // Fallback to system sound
            playSystemBell()
        }
    }
    
    // MARK: - Volume Control
    
    /// Set volume for custom sounds (0.0 to 1.0)
    func setVolume(_ volume: Float) {
        audioPlayer?.volume = min(max(volume, 0.0), 1.0)
    }
    
    // MARK: - Game Sound Effects
    
    /// Play miss sound based on consecutive misses
    func playMissSound() {
        consecutiveMisses += 1
        
        let soundName: String
        switch consecutiveMisses {
        case 1:
            soundName = "brokenglass"
        case 2:
            soundName = "cat"
        case 3:
            soundName = "horse"
        default:
            soundName = "horse" // Continue with horse sound for 4+ misses
        }
        
        playSound(named: soundName)
    }
    
    /// Reset miss counter (call when player scores)
    func resetMissCounter() {
        consecutiveMisses = 0
    }
    
    /// Play scoring sound
    func playScoreSound() {
        resetMissCounter() // Reset miss counter when scoring
        playSound(named: "thud")
    }
    
    /// Play boxing sound for pre-game hype
    func playBoxingSound() {
        playSound(named: "boxing")
    }
    
    /// Generic method to play any sound file
    private func playSound(named soundName: String) {
        guard isInitialized else {
            print("Audio session not initialized")
            return
        }
        
        guard let soundURL = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            print("Sound file '\(soundName).mp3' not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.volume = 0.7
            audioPlayer?.play()
        } catch {
            print("Failed to play sound '\(soundName)': \(error)")
        }
    }
    
    // MARK: - Legacy Sound Effects
    
    /// Play dart throw sound (placeholder for future implementation)
    func playDartThrow() {
        // TODO: Implement dart throw sound
        AudioServicesPlaySystemSound(1104) // Camera shutter as placeholder
    }
    
    /// Play game win sound (placeholder for future implementation)
    func playGameWin() {
        // TODO: Implement win sound
        AudioServicesPlaySystemSound(1025) // New mail sound as placeholder
    }
    
    /// Play button tap sound (placeholder for future implementation)
    func playButtonTap() {
        // TODO: Implement button tap sound
        AudioServicesPlaySystemSound(1104) // Keyboard click as placeholder
    }
}

// MARK: - Preview Helper
#if DEBUG
extension SoundManager {
    /// Test all sound effects (for debugging)
    func testAllSounds() {
        print("Testing bell sound...")
        playBell()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("Testing dart throw sound...")
            self.playDartThrow()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("Testing game win sound...")
            self.playGameWin()
        }
    }
}
#endif
