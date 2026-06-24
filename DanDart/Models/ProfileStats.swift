//
//  ProfileStats.swift
//  Dart Freak
//
//  Data models for profile statistics
//

import Foundation

struct ThreeDartDataPoint: Identifiable, Hashable, Codable {
    let id: UUID
    let timestamp: Date
    let average: Double
    let matchId: UUID
    
    init(id: UUID = UUID(), timestamp: Date, average: Double, matchId: UUID) {
        self.id = id
        self.timestamp = timestamp
        self.average = average
        self.matchId = matchId
    }
}

struct ScoringDistribution: Hashable, Codable {
    let bucket0_40: BucketData
    let bucket41_99: BucketData
    let bucket100_139: BucketData
    let bucket140_179: BucketData
    let bucket180: BucketData
    
    var totalVisits: Int {
        bucket0_40.count + bucket41_99.count + bucket100_139.count + bucket140_179.count + bucket180.count
    }
    
    var buckets: [BucketData] {
        [bucket0_40, bucket41_99, bucket100_139, bucket140_179, bucket180]
    }
    
    static var empty: ScoringDistribution {
        ScoringDistribution(
            bucket0_40: BucketData(range: "0-40", count: 0, percentage: 0, color: "blue"),
            bucket41_99: BucketData(range: "41-99", count: 0, percentage: 0, color: "green"),
            bucket100_139: BucketData(range: "100-139", count: 0, percentage: 0, color: "yellow"),
            bucket140_179: BucketData(range: "140-179", count: 0, percentage: 0, color: "orange"),
            bucket180: BucketData(range: "180", count: 0, percentage: 0, color: "red")
        )
    }
}

struct BucketData: Identifiable, Hashable, Codable {
    let id: UUID
    let range: String
    let count: Int
    let percentage: Double
    let color: String
    
    init(id: UUID = UUID(), range: String, count: Int, percentage: Double, color: String) {
        self.id = id
        self.range = range
        self.count = count
        self.percentage = percentage
        self.color = color
    }
}

struct FormResult: Identifiable, Hashable, Codable {
    let id: UUID
    let matchId: UUID
    let isWin: Bool
    let timestamp: Date
    
    init(id: UUID = UUID(), matchId: UUID, isWin: Bool, timestamp: Date) {
        self.id = id
        self.matchId = matchId
        self.isWin = isWin
        self.timestamp = timestamp
    }
}
