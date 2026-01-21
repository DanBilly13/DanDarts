//
//  MatchHistoryService.swift
//  Dart Freak
//
//  Centralized match history management with smart preloading and background updates
//

import Foundation
import Combine

@MainActor
class MatchHistoryService: ObservableObject {
    static let shared = MatchHistoryService()
    
    // MARK: - Published Properties
    
    @Published var matches: [MatchResult] = []
    @Published var isLoading: Bool = false
    @Published var lastLoadedTime: Date?
    @Published var loadError: String?
    
    // MARK: - Private Properties
    
    private let matchesService = MatchesService()
    private let storageManager = MatchStorageManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Check if cached data is stale (older than 30 seconds)
    var isStale: Bool {
        guard let lastLoaded = lastLoadedTime else { return true }
        return Date().timeIntervalSince(lastLoaded) > 30
    }
    
    // MARK: - Initialization
    
    private init() {
        setupNotificationListeners()
    }
    
    // MARK: - Setup
    
    private func setupNotificationListeners() {
        // Listen for match completed notifications
        NotificationCenter.default.publisher(for: NSNotification.Name("MatchCompleted"))
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.refreshMatchesInBackground()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Preload last 20 matches in background (called on sign-in)
    func preloadMatches(userId: UUID) async {
        print("📥 Preloading match history in background...")
        
        // Don't show loading indicator for background preload
        do {
            // Load from Supabase
            let supabaseMatches = try await matchesService.loadMatches(userId: userId)
            
            // Load local matches
            let localMatches = storageManager.loadMatches()
            
            // Merge and deduplicate
            let allMatches = mergeMatches(local: localMatches, supabase: supabaseMatches)
            
            // Update state
            matches = allMatches.sorted { $0.timestamp > $1.timestamp }
            lastLoadedTime = Date()
            
            print("✅ Preloaded \(matches.count) matches in background")
        } catch {
            print("⚠️ Background preload failed: \(error)")
            // Don't show error for background preload, just use local data
            let localMatches = storageManager.loadMatches()
            matches = localMatches.sorted { $0.timestamp > $1.timestamp }
        }
    }
    
    /// Refresh matches from Supabase (called on pull-to-refresh or when stale)
    func refreshMatches(userId: UUID) async {
        isLoading = true
        loadError = nil
        
        do {
            // Load from Supabase
            let supabaseMatches = try await matchesService.loadMatches(userId: userId)
            
            // Load local matches
            let localMatches = storageManager.loadMatches()
            
            // Merge and deduplicate
            let allMatches = mergeMatches(local: localMatches, supabase: supabaseMatches)
            
            // Update state
            matches = allMatches.sorted { $0.timestamp > $1.timestamp }
            lastLoadedTime = Date()
            isLoading = false
            
            print("✅ Refreshed \(matches.count) matches")
        } catch {
            isLoading = false
            loadError = "Couldn't sync with cloud"
            print("❌ Refresh error: \(error)")
            
            // Fall back to local matches on error
            let localMatches = storageManager.loadMatches()
            matches = localMatches.sorted { $0.timestamp > $1.timestamp }
        }
    }
    
    /// Refresh matches in background (called on match completed notification)
    private func refreshMatchesInBackground() async {
        guard !isLoading else {
            print("⏭️ Skipping background refresh - already loading")
            return
        }
        
        print("🔔 Match completed - refreshing history in background")
        
        // Get current user ID from AuthService
        guard let userId = AuthService.shared.currentUser?.id else {
            print("⚠️ No current user for background refresh")
            return
        }
        
        // Refresh without showing loading indicator
        do {
            let supabaseMatches = try await matchesService.loadMatches(userId: userId)
            let localMatches = storageManager.loadMatches()
            let allMatches = mergeMatches(local: localMatches, supabase: supabaseMatches)
            
            matches = allMatches.sorted { $0.timestamp > $1.timestamp }
            lastLoadedTime = Date()
            
            print("✅ Background refresh complete: \(matches.count) matches")
        } catch {
            print("⚠️ Background refresh failed: \(error)")
        }
    }
    
    /// Load matches from local storage only (instant, for initial display)
    func loadLocalMatches() {
        let localMatches = storageManager.loadMatches()
        matches = localMatches.sorted { $0.timestamp > $1.timestamp }
        print("📱 Loaded \(matches.count) matches from local storage")
    }
    
    // MARK: - Private Methods
    
    /// Merge local and Supabase matches, removing duplicates
    private func mergeMatches(local: [MatchResult], supabase: [MatchResult]) -> [MatchResult] {
        var matchesById: [UUID: MatchResult] = [:]
        
        // Add local matches first
        for match in local {
            matchesById[match.id] = match
        }
        
        // Add Supabase matches (will overwrite local if same ID)
        for match in supabase {
            matchesById[match.id] = match
        }
        
        return Array(matchesById.values)
    }
}
