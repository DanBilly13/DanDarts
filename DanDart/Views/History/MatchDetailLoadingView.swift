//
//  MatchDetailLoadingView.swift
//  Dart Freak
//
//  Wrapper view for lazy loading match details
//

import SwiftUI

struct MatchDetailLoadingView: View {
    let matchId: UUID
    @EnvironmentObject private var historyService: MatchHistoryService
    @State private var match: MatchResult?
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading match details...")
                        .font(.subheadline)
                        .foregroundColor(AppColor.textSecondary)
                }
            } else if let match = match {
                MatchDetailView(match: match, isSheet: false)
            } else if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(AppColor.textSecondary)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(AppColor.textSecondary)
                }
            }
        }
        .task {
            await loadMatch()
        }
    }
    
    private func loadMatch() async {
        do {
            match = try await historyService.loadFullDetail(matchId: matchId)
            isLoading = false
        } catch {
            self.error = "Failed to load match details"
            isLoading = false
        }
    }
}
