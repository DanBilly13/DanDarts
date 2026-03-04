//
//  CheckoutCalculator.swift
//  DanDart
//
//  Shared checkout calculation logic for Countdown games (301/501)
//  Provides optimal checkout suggestions based on remaining score and darts
//

import Foundation

enum CheckoutCalculator {
    
    /// Calculate checkout suggestion for current game state
    /// - Parameters:
    ///   - currentScore: Player's current score
    ///   - currentThrowTotal: Total of darts thrown this turn
    ///   - dartsThrown: Number of darts thrown (0-3)
    ///   - turnStartedWithCheckout: Whether turn began with checkout available
    /// - Returns: Checkout suggestion string or nil
    static func suggestCheckout(
        currentScore: Int,
        currentThrowTotal: Int,
        dartsThrown: Int,
        turnStartedWithCheckout: Bool
    ) -> String? {
        let remainingAfterThrow = currentScore - currentThrowTotal
        let dartsLeft = 3 - dartsThrown
        
        // Only suggest checkouts for scores 2-170 with darts remaining
        guard remainingAfterThrow >= 2 && remainingAfterThrow <= 170 && dartsLeft > 0 else {
            // If turn started with checkout but now unavailable, show "Not Available" message
            if turnStartedWithCheckout && dartsThrown > 0 && remainingAfterThrow > 1 {
                return "Not Available \(remainingAfterThrow)pts left"
            }
            return nil
        }
        
        // Calculate checkout based on darts remaining
        if let checkout = calculateCheckout(score: remainingAfterThrow, dartsAvailable: dartsLeft) {
            return checkout
        } else {
            // Checkout not possible with remaining darts
            if turnStartedWithCheckout && dartsThrown > 0 {
                return "Not Available \(remainingAfterThrow)pts left"
            }
            return nil
        }
    }
    
    /// Check if checkout is available for given score
    static func isCheckoutAvailable(score: Int) -> Bool {
        return score >= 2 && score <= 170
    }
    
    /// Calculate the optimal checkout for a given score
    private static func calculateCheckout(score: Int, dartsAvailable: Int) -> String? {
        // Can't checkout on 1 or above 170
        guard score >= 2 && score <= 170 else { return nil }
        
        // Check if we have a pre-calculated checkout
        if let checkout = checkouts[score] {
            // Verify we have enough darts for this checkout
            let dartsNeeded = checkout.components(separatedBy: " → ").count
            if dartsNeeded <= dartsAvailable {
                return checkout
            }
        }
        
        return nil
    }
    
    // MARK: - Checkout Chart
    
    /// Standard dart checkout chart (2-170)
    /// Format: "D20" = Double 20, "T20" = Triple 20, "Bull" = Bullseye (50)
    private static let checkouts: [Int: String] = [
        // 2-40: Single dart checkouts (doubles only)
        2: "D1", 4: "D2", 6: "D3", 8: "D4", 10: "D5",
        12: "D6", 14: "D7", 16: "D8", 18: "D9", 20: "D10",
        22: "D11", 24: "D12", 26: "D13", 28: "D14", 30: "D15",
        32: "D16", 34: "D17", 36: "D18", 38: "D19", 40: "D20",
        
        // Odd numbers 3-39: Two dart checkouts (single + double)
        3: "1 → D1", 5: "1 → D2", 7: "3 → D2", 9: "1 → D4", 11: "3 → D4",
        13: "5 → D4", 15: "7 → D4", 17: "9 → D4", 19: "3 → D8", 21: "5 → D8",
        23: "7 → D8", 25: "9 → D8", 27: "11 → D8", 29: "13 → D8", 31: "15 → D8",
        33: "17 → D8", 35: "3 → D16", 37: "5 → D16", 39: "7 → D16",
        
        // 41-60: Two dart checkouts
        41: "9 → D16", 42: "10 → D16", 43: "11 → D16", 44: "12 → D16", 45: "13 → D16",
        46: "6 → D20", 47: "15 → D16", 48: "16 → D16", 49: "17 → D16", 50: "Bull",
        51: "19 → D16", 52: "20 → D16", 53: "13 → D20", 54: "14 → D20", 55: "15 → D20",
        56: "16 → D20", 57: "17 → D20", 58: "18 → D20", 59: "19 → D20", 60: "20 → D20",
        
        // 61-80: Two dart checkouts
        61: "T15 → D8", 62: "T10 → D16", 63: "T13 → D12", 64: "T16 → D8", 65: "T11 → D16",
        66: "T10 → D18", 67: "T17 → D8", 68: "T20 → D4", 69: "T19 → D6", 70: "T18 → D8",
        71: "T13 → D16", 72: "T16 → D12", 73: "T19 → D8", 74: "T14 → D16", 75: "T17 → D12",
        76: "T20 → D8", 77: "T15 → D16", 78: "T18 → D12", 79: "T13 → D20", 80: "T20 → D10",
        
        // 81-100: Two dart checkouts
        81: "T19 → D12", 82: "Bull → D16", 83: "T17 → D16", 84: "T20 → D12", 85: "T15 → D20",
        86: "T18 → D16", 87: "T17 → D18", 88: "T16 → D20", 89: "T19 → D16", 90: "T18 → D18",
        91: "T17 → D20", 92: "T20 → D16", 93: "T19 → D18", 94: "T18 → D20", 95: "T19 → D19",
        96: "T20 → D18", 97: "T19 → D20", 98: "T20 → D19", 99: "T19 → 10 → D16", 100: "T20 → D20",
        
        // 101-120: Three dart checkouts
        101: "T17 → 10 → D20", 102: "T20 → 10 → D16", 103: "T19 → 10 → D18", 104: "T18 → 10 → D20",
        105: "T20 → 13 → D16", 106: "T20 → 14 → D16", 107: "T19 → Bull", 108: "T20 → 16 → D16",
        109: "T20 → 17 → D16", 110: "T20 → Bull", 111: "T20 → 19 → D16", 112: "T20 → 20 → D16",
        113: "T20 → 13 → D20", 114: "T20 → 14 → D20", 115: "T20 → 15 → D20", 116: "T20 → 16 → D20",
        117: "T20 → 17 → D20", 118: "T20 → 18 → D20", 119: "T20 → 19 → D20", 120: "T20 → 20 → D20",
        
        // 121-140: Three dart checkouts
        121: "T20 → T11 → D14", 122: "T18 → T18 → D7", 123: "T19 → T16 → D9", 124: "T20 → T16 → D8",
        125: "T20 → T15 → D10", 126: "T19 → T19 → D6", 127: "T20 → T17 → D8", 128: "T18 → T14 → D16",
        129: "T19 → T16 → D12", 130: "T20 → T18 → D8", 131: "T20 → T13 → D16", 132: "T20 → T16 → D12",
        133: "T20 → T19 → D8", 134: "T20 → T14 → D16", 135: "T20 → T17 → D12", 136: "T20 → T20 → D8",
        137: "T20 → T15 → D16", 138: "T20 → T18 → D12", 139: "T20 → T13 → D20", 140: "T20 → T20 → D10",
        
        // 141-160: Three dart checkouts
        141: "T20 → T19 → D12", 142: "T20 → T14 → D20", 143: "T20 → T17 → D16", 144: "T20 → T20 → D12",
        145: "T20 → T15 → D20", 146: "T20 → T18 → D16", 147: "T20 → T17 → D18", 148: "T20 → T16 → D20",
        149: "T20 → T19 → D16", 150: "T20 → T18 → D18", 151: "T20 → T17 → D20", 152: "T20 → T20 → D16",
        153: "T20 → T19 → D18", 154: "T20 → T18 → D20", 155: "T20 → T19 → D19", 156: "T20 → T20 → D18",
        157: "T20 → T19 → D20", 158: "T20 → T20 → D19", 160: "T20 → T20 → D20",
        
        // 161-170: Three dart checkouts
        161: "T20 → T17 → Bull", 162: "T20 → T18 → Bull", 163: "T20 → T19 → Bull", 164: "T20 → T18 → Bull",
        165: "T20 → T19 → Bull", 166: "T20 → T18 → Bull", 167: "T20 → T19 → Bull", 168: "T20 → T20 → Bull",
        169: "T20 → T19 → Bull", 170: "T20 → T20 → Bull"
    ]
}
