//
//  HeadToHeadCache.swift
//  Dart Freak
//
//  Singleton cache for head-to-head match data
//

import Foundation

class HeadToHeadCache {
    static let shared = HeadToHeadCache()
    
    private var cache: [UUID: CachedMatches] = [:]
    
    private init() {}
    
    struct CachedMatches {
        let matches: [MatchResult]
        let loadTime: Date
    }
    
    func getMatches(for friendId: UUID) -> [MatchResult]? {
        guard let cached = cache[friendId] else {
            return nil
        }
        
        // Check if cache is still valid (5 minutes)
        let cacheAge = Date().timeIntervalSince(cached.loadTime)
        if cacheAge > 300 {
            // Cache expired
            cache.removeValue(forKey: friendId)
            return nil
        }
        
        return cached.matches
    }
    
    func setMatches(_ matches: [MatchResult], for friendId: UUID) {
        cache[friendId] = CachedMatches(matches: matches, loadTime: Date())
    }
    
    func invalidate(for friendId: UUID? = nil) {
        if let friendId = friendId {
            cache.removeValue(forKey: friendId)
        } else {
            cache.removeAll()
        }
    }
}
