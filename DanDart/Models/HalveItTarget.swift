//
//  HalveItTarget.swift
//  DanDart
//
//  Target types for Halve It game
//

import Foundation

enum HalveItTarget: Equatable, Codable {
    case single(Int)      // 1-20
    case double(Int)      // D1-D20
    case triple(Int)      // T1-T20
    case bull
    
    // MARK: - Display
    
    var displayText: String {
        switch self {
        case .single(let num): return "\(num)"
        case .double(let num): return "D\(num)"
        case .triple(let num): return "T\(num)"
        case .bull: return "BULL"
        }
    }
    
    // MARK: - Scoring
    
    /// Check if a dart hits this target
    func isHit(by dart: ScoredThrow) -> Bool {
        switch self {
        case .single(let targetNum):
            // Singles are flexible: any multiplier of the target number counts
            return dart.baseValue == targetNum
            
        case .double(let targetNum):
            // Doubles are strict: must hit exactly double
            return dart.baseValue == targetNum && dart.scoreType == .double
            
        case .triple(let targetNum):
            // Triples are strict: must hit exactly triple
            return dart.baseValue == targetNum && dart.scoreType == .triple
            
        case .bull:
            // Accept both 25 (single bull) and 50 (double bull/Bull button)
            return dart.baseValue == 25 || dart.baseValue == 50
        }
    }
    
    /// Get points for hitting this target with a specific dart
    func points(for dart: ScoredThrow) -> Int {
        guard isHit(by: dart) else { return 0 }
        return dart.totalValue
    }
}

// MARK: - Difficulty

enum HalveItDifficulty: String, CaseIterable, Codable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case pro = "Pro"
    
    /// Generate 6 random targets based on difficulty (5 random + Bull)
    func generateTargets() -> [HalveItTarget] {
        var targets: [HalveItTarget] = []
        
        // Generate 5 random targets based on difficulty
        for _ in 0..<5 {
            let target = generateRandomTarget()
            // Avoid duplicates
            if !targets.contains(target) {
                targets.append(target)
            } else {
                // Try again if duplicate
                let retry = generateRandomTarget()
                targets.append(retry)
            }
        }
        
        // Always add Bull as final target
        targets.append(.bull)
        
        return targets
    }
    
    private func generateRandomTarget() -> HalveItTarget {
        let number = Int.random(in: 1...20)
        
        switch self {
        case .easy:
            // Only singles
            return .single(number)
            
        case .medium:
            // Singles (60%) or Doubles (40%)
            let roll = Int.random(in: 1...10)
            return roll <= 6 ? .single(number) : .double(number)
            
        case .hard:
            // Singles (40%), Doubles (30%), Triples (30%)
            let roll = Int.random(in: 1...10)
            if roll <= 4 {
                return .single(number)
            } else if roll <= 7 {
                return .double(number)
            } else {
                return .triple(number)
            }
            
        case .pro:
            // Singles (20%), Doubles (40%), Triples (40%)
            let roll = Int.random(in: 1...10)
            if roll <= 2 {
                return .single(number)
            } else if roll <= 6 {
                return .double(number)
            } else {
                return .triple(number)
            }
        }
    }
}
