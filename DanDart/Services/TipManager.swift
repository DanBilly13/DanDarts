//
//  TipManager.swift
//  Dart Freak
//
//  Manages game tips - loads from JSON and tracks which tips have been shown
//

import Foundation

// MARK: - GameTip Model

struct GameTip: Codable {
    let gameTitle: String
    let icon: String
    let title: String
    let message1: String
    let message2: String
}

// MARK: - TipManager

class TipManager {
    static let shared = TipManager()
    
    private var tips: [GameTip] = []
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadTips()
    }
    
    // MARK: - Load Tips from JSON
    
    private func loadTips() {
        guard let url = Bundle.main.url(forResource: "game_tips", withExtension: "json") else {
            print("⚠️ game_tips.json not found in bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            tips = try JSONDecoder().decode([GameTip].self, from: data)
            print("✅ Loaded \(tips.count) game tips")
        } catch {
            print("❌ Failed to decode game_tips.json: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Get the tip for a specific game
    func getTip(for gameTitle: String) -> GameTip? {
        return tips.first { $0.gameTitle == gameTitle }
    }
    
    /// Check if the tip for a game has been seen
    func hasSeenTip(for gameTitle: String) -> Bool {
        let key = "hasSeenTip_\(gameTitle)"
        return userDefaults.bool(forKey: key)
    }
    
    /// Mark the tip for a game as seen
    func markTipAsSeen(for gameTitle: String) {
        let key = "hasSeenTip_\(gameTitle)"
        userDefaults.set(true, forKey: key)
        print("✅ Marked tip as seen for: \(gameTitle)")
    }
    
    /// Check if a tip should be shown for a game
    func shouldShowTip(for gameTitle: String) -> Bool {
        // Only show if we have a tip and it hasn't been seen
        guard getTip(for: gameTitle) != nil else {
            return false
        }
        return !hasSeenTip(for: gameTitle)
    }
    
    /// Reset all tips (for testing/debugging)
    func resetAllTips() {
        for tip in tips {
            let key = "hasSeenTip_\(tip.gameTitle)"
            userDefaults.removeObject(forKey: key)
        }
        print("🔄 Reset all tips")
    }
    
    /// Reset a specific tip (for testing/debugging)
    func resetTip(for gameTitle: String) {
        let key = "hasSeenTip_\(gameTitle)"
        userDefaults.removeObject(forKey: key)
        print("🔄 Reset tip for: \(gameTitle)")
    }
}
