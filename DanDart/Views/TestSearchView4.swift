import SwiftUI
import Combine
import UIKit

/// Test using the Liquid Glass / Apple Mail search pattern
/// Based on: https://www.createwithswift.com/adapting-search-to-the-liquid-glass-design-system/
struct TestSearchView4: View {
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @FocusState private var isSearchFieldFocused: Bool

    private func debug(_ message: String) {
        let ts = Date().formatted(date: .omitted, time: .standard)
        print("🪵 [SearchDebug @\(ts)] \(message)")
    }
    
    let testItems = [
        "Match 1: 301 Game",
        "Match 2: 501 Game",
        "Match 3: Halve It",
        "Match 4: Knockout",
        "Match 5: Sudden Death"
    ]
    
    var filteredItems: [String] {
        if searchText.isEmpty {
            return testItems
        }
        return testItems.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(testItems, id: \.self) { item in
                            Text(item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(AppColor.surfacePrimary)
                                .cornerRadius(12)
                        }
                    }
                    .padding(16)
                }
                .opacity(isSearchPresented ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: isSearchPresented)
                
                // Search overlay
                if isSearchPresented {
                    searchOverlay
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.backgroundPrimary)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                debug("keyboardWillShowNotification")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                debug("keyboardWillHideNotification")
            }
            .navigationTitle("Liquid Glass Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        debug("Search button tapped")
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSearchPresented = true
                        }
                        debug("isSearchPresented set true, scheduling focus")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            debug("Focus attempt fired (after 0.35s)")
                            isSearchFieldFocused = true
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                    .opacity(isSearchPresented ? 0 : 1)
                }
            }
        }
    }
    
    // MARK: - Search Overlay
    
    private var searchOverlay: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissSearch()
                }
            
            VStack(spacing: 0) {
                // Results area
                if searchText.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(AppColor.textSecondary)
                        
                        Text("Start typing to search")
                            .font(.headline)
                            .foregroundColor(AppColor.textPrimary)
                        
                        Spacer()
                    }
                } else {
                    if filteredItems.isEmpty {
                        // No results
                        VStack(spacing: 16) {
                            Spacer()
                            
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(AppColor.textSecondary)
                            
                            Text("No results found")
                                .font(.headline)
                                .foregroundColor(AppColor.textPrimary)
                            
                            Spacer()
                        }
                    } else {
                        // Results list
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredItems, id: \.self) { item in
                                    Button(action: {
                                        print("💧 [LIQUID] Selected: \(item)")
                                        dismissSearch()
                                    }) {
                                        Text(item)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding()
                                            .background(AppColor.surfacePrimary)
                                            .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
                
                // Search bar (pinned to bottom)
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                        
                        TextField("Search", text: $searchText)
                            .font(.system(size: 17))
                            .foregroundColor(AppColor.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($isSearchFieldFocused)
                            .submitLabel(.search)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColor.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppColor.inputBackground)
                    .cornerRadius(10)
                    
                    Button(action: {
                        dismissSearch()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 17))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppColor.backgroundPrimary)
            }
        }
        .onAppear {
            debug("Overlay onAppear")
            // Extra focus poke one tick later, purely for debugging.
            DispatchQueue.main.async {
                debug("Overlay async focus poke")
                isSearchFieldFocused = true
            }
        }
        .onChange(of: isSearchFieldFocused) { oldValue, newValue in
            debug("Focus changed: \(oldValue) -> \(newValue)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func dismissSearch() {
        debug("dismissSearch() called")
        isSearchFieldFocused = false
        withAnimation(.easeInOut(duration: 0.3)) {
            isSearchPresented = false
        }
        searchText = ""
        debug("dismissSearch() completed")
    }
}

#Preview {
    TestSearchView4()
}
