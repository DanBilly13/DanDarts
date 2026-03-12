//
//  H2HDebugService.swift
//  DanDart
//
//  Service for collecting comprehensive H2H debug data
//

import Foundation

#if DEBUG

class H2HDebugService: ObservableObject {
    private let supabaseService = SupabaseService.shared
    
    // MARK: - Main Collection Method
    
    func collectDebugData(
        currentUserId: UUID,
        currentUserName: String,
        friendId: UUID,
        friendName: String
    ) async -> H2HDebugData {
        print("🔍 [H2H Debug] Starting debug data collection")
        print("   Current User: \(currentUserId)")
        print("   Friend: \(friendId)")
        
        // 1. Get player stats from users table
        let (currentUserWins, currentUserLosses) = await getUserStats(userId: currentUserId)
        let (friendWins, friendLosses) = await getUserStats(userId: friendId)
        
        // 2. Query raw matches from Supabase
        let supabaseMatches = await queryRawSupabaseMatches(userId: currentUserId, friendId: friendId)
        print("   Found \(supabaseMatches.count) Supabase matches")
        
        // 3. Query local matches
        let localMatches = await queryLocalMatches(userId: currentUserId, friendId: friendId)
        print("   Found \(localMatches.count) local matches")
        
        // 4. Build match debug details
        var allMatchDetails: [MatchDebugDetail] = []
        var processedIds = Set<UUID>()
        
        // Add Supabase matches
        for match in supabaseMatches {
            let detail = buildMatchDebugDetail(
                from: match,
                source: .supabase,
                currentUserId: currentUserId,
                friendId: friendId
            )
            allMatchDetails.append(detail)
            processedIds.insert(match.matchId)
        }
        
        // Add local-only matches
        for match in localMatches {
            if !processedIds.contains(match.id) {
                let detail = buildMatchDebugDetailFromLocal(
                    match: match,
                    currentUserId: currentUserId,
                    friendId: friendId
                )
                allMatchDetails.append(detail)
                processedIds.insert(match.id)
            }
        }
        
        // 5. Categorize matches
        let (local301, remote301, combined301) = categorizeMatches(
            allMatchDetails,
            currentUserId: currentUserId,
            friendId: friendId
        )
        
        // 6. Find excluded matches
        let includedIds = Set(allMatchDetails.filter { $0.includedInH2H }.map { $0.matchId })
        let excludedMatches = allMatchDetails
            .filter { !$0.includedInH2H }
            .map { detail in
                ExcludedMatchDetail(
                    matchId: detail.matchId,
                    reason: detail.exclusionReason ?? "Unknown",
                    gameType: detail.gameType,
                    gameName: detail.gameName,
                    createdAt: detail.createdAt,
                    source: detail.source
                )
            }
        
        // 7. Calculate displayed H2H summary (from included matches only)
        let includedMatches = allMatchDetails.filter { $0.includedInH2H }
        let displayedCurrentUserWins = includedMatches.filter { $0.winnerId == currentUserId }.count
        let displayedFriendWins = includedMatches.filter { $0.winnerId == friendId }.count
        
        print("✅ [H2H Debug] Collection complete")
        print("   Total matches: \(allMatchDetails.count)")
        print("   Included: \(includedMatches.count)")
        print("   Excluded: \(excludedMatches.count)")
        
        return H2HDebugData(
            currentUserWins: currentUserWins,
            currentUserLosses: currentUserLosses,
            friendWins: friendWins,
            friendLosses: friendLosses,
            displayedCurrentUserWins: displayedCurrentUserWins,
            displayedFriendWins: displayedFriendWins,
            displayedTotalMatches: includedMatches.count,
            allMatchDetails: allMatchDetails.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) },
            local301Only: local301,
            remote301Only: remote301,
            combined301: combined301,
            excludedMatches: excludedMatches
        )
    }
    
    // MARK: - User Stats
    
    private func getUserStats(userId: UUID) async -> (wins: Int, losses: Int) {
        do {
            let response = try await supabaseService.client
                .from("users")
                .select("total_wins, total_losses")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
            
            guard let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] else {
                return (0, 0)
            }
            
            let wins = json["total_wins"] as? Int ?? 0
            let losses = json["total_losses"] as? Int ?? 0
            return (wins, losses)
        } catch {
            print("❌ [H2H Debug] Failed to get user stats: \(error)")
            return (0, 0)
        }
    }
    
    // MARK: - Raw Supabase Query
    
    private func queryRawSupabaseMatches(userId: UUID, friendId: UUID) async -> [RawMatchData] {
        do {
            // Step 1: Find match IDs where both participated
            let userResponse = try await supabaseService.client
                .from("match_participants")
                .select("match_id")
                .eq("user_id", value: userId.uuidString)
                .eq("is_guest", value: false)
                .execute()
            
            let friendResponse = try await supabaseService.client
                .from("match_participants")
                .select("match_id")
                .eq("user_id", value: friendId.uuidString)
                .eq("is_guest", value: false)
                .execute()
            
            guard let userJson = try? JSONSerialization.jsonObject(with: userResponse.data) as? [[String: Any]],
                  let friendJson = try? JSONSerialization.jsonObject(with: friendResponse.data) as? [[String: Any]] else {
                return []
            }
            
            let userMatchIds = Set(userJson.compactMap { ($0["match_id"] as? String).flatMap(UUID.init) })
            let friendMatchIds = Set(friendJson.compactMap { ($0["match_id"] as? String).flatMap(UUID.init) })
            let commonMatchIds = Array(userMatchIds.intersection(friendMatchIds))
            
            guard !commonMatchIds.isEmpty else { return [] }
            
            // Step 2: Query raw match data with ALL fields
            let matchIdsStrings = commonMatchIds.map { $0.uuidString }
            let matchesResponse = try await supabaseService.client
                .from("matches")
                .select("id, game_type, game_name, match_mode, remote_status, winner_id, duration, timestamp, created_at")
                .in("id", values: matchIdsStrings)
                .execute()
            
            guard let matchesJson = try? JSONSerialization.jsonObject(with: matchesResponse.data) as? [[String: Any]] else {
                return []
            }
            
            // Step 3: Get participants for each match
            let participantsResponse = try await supabaseService.client
                .from("match_participants")
                .select("match_id, user_id, display_name")
                .in("match_id", values: matchIdsStrings)
                .execute()
            
            guard let participantsJson = try? JSONSerialization.jsonObject(with: participantsResponse.data) as? [[String: Any]] else {
                return []
            }
            
            // Group participants by match_id
            var participantsByMatch: [UUID: [(UUID, String)]] = [:]
            for pJson in participantsJson {
                guard let matchIdStr = pJson["match_id"] as? String,
                      let matchId = UUID(uuidString: matchIdStr),
                      let userIdStr = pJson["user_id"] as? String,
                      let userId = UUID(uuidString: userIdStr),
                      let displayName = pJson["display_name"] as? String else {
                    continue
                }
                
                if participantsByMatch[matchId] == nil {
                    participantsByMatch[matchId] = []
                }
                participantsByMatch[matchId]?.append((userId, displayName))
            }
            
            // Build RawMatchData objects
            return matchesJson.compactMap { json in
                guard let idStr = json["id"] as? String,
                      let matchId = UUID(uuidString: idStr),
                      let gameType = json["game_type"] as? String,
                      let gameName = json["game_name"] as? String else {
                    return nil
                }
                
                let participants = participantsByMatch[matchId] ?? []
                
                return RawMatchData(
                    matchId: matchId,
                    gameType: gameType,
                    gameName: gameName,
                    matchMode: json["match_mode"] as? String,
                    remoteStatus: json["remote_status"] as? String,
                    winnerId: (json["winner_id"] as? String).flatMap(UUID.init),
                    duration: json["duration"] as? Int,
                    timestamp: (json["timestamp"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) },
                    createdAt: (json["created_at"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) },
                    participantIds: participants.map { $0.0 },
                    participantNames: participants.map { $0.1 }
                )
            }
        } catch {
            print("❌ [H2H Debug] Failed to query Supabase: \(error)")
            return []
        }
    }
    
    // MARK: - Local Storage Query
    
    @MainActor
    private func queryLocalMatches(userId: UUID, friendId: UUID) -> [MatchResult] {
        let allMatches = MatchStorageManager.shared.loadMatches()
        
        // Filter for matches where both users participated
        // Note: MatchPlayer.id is the user ID (not a separate userId property)
        return allMatches.filter { match in
            let playerIds = match.players.filter { !$0.isGuest }.map { $0.id }
            return playerIds.contains(userId) && playerIds.contains(friendId)
        }
    }
    
    // MARK: - Build Debug Details
    
    private func buildMatchDebugDetail(
        from raw: RawMatchData,
        source: DataSource,
        currentUserId: UUID,
        friendId: UUID
    ) -> MatchDebugDetail {
        // Determine if included in H2H and why
        var includedInH2H = true
        var exclusionReason: String?
        
        // Check all the filtering conditions from loadMatchesByIds
        if raw.duration == nil {
            includedInH2H = false
            exclusionReason = "Missing duration"
        } else if raw.winnerId == nil {
            includedInH2H = false
            exclusionReason = "Missing winner_id"
        } else if raw.participantIds.count < 2 {
            includedInH2H = false
            exclusionReason = "Missing participants (count: \(raw.participantIds.count))"
        } else if !raw.participantIds.contains(currentUserId) || !raw.participantIds.contains(friendId) {
            includedInH2H = false
            exclusionReason = "Not both participants"
        }
        
        return MatchDebugDetail(
            matchId: raw.matchId,
            createdAt: raw.createdAt ?? raw.timestamp,
            gameType: raw.gameType,
            gameName: raw.gameName,
            matchMode: raw.matchMode,
            remoteStatus: raw.remoteStatus,
            winnerId: raw.winnerId,
            duration: raw.duration,
            participantIds: raw.participantIds,
            participantNames: raw.participantNames,
            source: source,
            includedInH2H: includedInH2H,
            exclusionReason: exclusionReason
        )
    }
    
    private func buildMatchDebugDetailFromLocal(
        match: MatchResult,
        currentUserId: UUID,
        friendId: UUID
    ) -> MatchDebugDetail {
        // Note: MatchPlayer.id is the user ID (not a separate userId property)
        let participantIds = match.players.filter { !$0.isGuest }.map { $0.id }
        let participantNames = match.players.map { $0.displayName }
        
        var includedInH2H = true
        var exclusionReason: String?
        
        if match.duration == 0 {
            includedInH2H = false
            exclusionReason = "Duration is 0"
        } else if !participantIds.contains(currentUserId) || !participantIds.contains(friendId) {
            includedInH2H = false
            exclusionReason = "Not both participants"
        }
        
        return MatchDebugDetail(
            matchId: match.id,
            createdAt: match.timestamp,
            gameType: match.gameType,
            gameName: match.gameName,
            matchMode: "local",
            remoteStatus: nil,
            winnerId: match.winnerId,
            duration: Int(match.duration),
            participantIds: participantIds,
            participantNames: participantNames,
            source: .local,
            includedInH2H: includedInH2H,
            exclusionReason: exclusionReason
        )
    }
    
    // MARK: - Categorization
    
    private func categorizeMatches(
        _ matches: [MatchDebugDetail],
        currentUserId: UUID,
        friendId: UUID
    ) -> (local301: CategoryStats, remote301: CategoryStats, combined301: CategoryStats) {
        let game301Matches = matches.filter { $0.gameType == "301" || $0.gameName.contains("301") }
        
        let local301 = game301Matches.filter { $0.matchMode == "local" }
        let remote301 = game301Matches.filter { $0.matchMode == "remote" }
        
        let local301Stats = buildCategoryStats(from: local301, currentUserId: currentUserId, friendId: friendId)
        let remote301Stats = buildCategoryStats(from: remote301, currentUserId: currentUserId, friendId: friendId)
        let combined301Stats = buildCategoryStats(from: game301Matches, currentUserId: currentUserId, friendId: friendId)
        
        return (local301Stats, remote301Stats, combined301Stats)
    }
    
    private func buildCategoryStats(
        from matches: [MatchDebugDetail],
        currentUserId: UUID,
        friendId: UUID
    ) -> CategoryStats {
        let includedMatches = matches.filter { $0.includedInH2H }
        let currentUserWins = includedMatches.filter { $0.winnerId == currentUserId }.count
        let friendWins = includedMatches.filter { $0.winnerId == friendId }.count
        let matchIds = includedMatches.map { $0.matchId }
        
        return CategoryStats(
            currentUserWins: currentUserWins,
            friendWins: friendWins,
            totalMatches: includedMatches.count,
            matchIds: matchIds
        )
    }
}

// MARK: - Raw Match Data

private struct RawMatchData {
    let matchId: UUID
    let gameType: String
    let gameName: String
    let matchMode: String?
    let remoteStatus: String?
    let winnerId: UUID?
    let duration: Int?
    let timestamp: Date?
    let createdAt: Date?
    let participantIds: [UUID]
    let participantNames: [String]
}

#endif
