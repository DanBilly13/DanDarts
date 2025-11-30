import SwiftUI

struct TestSearchView: View {
    @State private var isSearching = false
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    
    let testItems = [
        "Match 1: 301 Game",
        "Match 2: 501 Game",
        "Match 3: Halve It",
        "Match 4: Knockout",
        "Match 5: Sudden Death"
    ]
    
    var filteredItems: [String] {
        if isSearching && searchText.isEmpty {
            return []
        }
        
        if searchText.isEmpty {
            return testItems
        }
        
        return testItems.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main content
                if !isSearching {
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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.backgroundPrimary)
            .navigationTitle("Test Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isSearching {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            print("🔍 [TEST] Search button tapped")
                            startSearch()
                        }) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(AppColor.interactivePrimaryBackground)
                        }
                    }
                }
            }
            .overlay(
                ZStack {
                    // Dim background
                    Color.black.opacity(isSearching ? 0.4 : 0)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .animation(.easeInOut(duration: 0.2), value: isSearching)
                        .zIndex(0)
                    
                    // Search overlay
                    if isSearching {
                        searchOverlay
                            .transition(.move(edge: .bottom))
                            .zIndex(1)
                    }
                }
            )
        }
    }
    
    // MARK: - Search Overlay
    
    private var searchOverlay: some View {
        VStack(spacing: 0) {
            // Results area
            if !searchText.isEmpty {
                if filteredItems.isEmpty {
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
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredItems, id: \.self) { item in
                                Button(action: {
                                    print("🔍 [TEST] Item tapped: \(item)")
                                    stopSearch()
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
            } else {
                Spacer()
            }
            
            // Search bar
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
                        .frame(maxWidth: .infinity)
                        .onAppear {
                            print("🔍 [TEST] TextField.onAppear - requesting focus")
                            // Request focus from within the TextField's lifecycle
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isSearchFieldFocused = true
                                print("🔍 [TEST] TextField focus requested: \(isSearchFieldFocused)")
                            }
                        }
                    
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
                    stopSearch()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColor.textPrimary)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColor.backgroundPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.backgroundPrimary)
    }
    
    // MARK: - Helper Methods
    
    private func startSearch() {
        print("🔍 [TEST] Starting search")
        withAnimation(.easeInOut(duration: 0.25)) {
            isSearching = true
        }
        searchText = ""
    }
    
    private func stopSearch() {
        print("🔍 [TEST] Stopping search")
        isSearchFieldFocused = false
        withAnimation(.easeInOut(duration: 0.25)) {
            isSearching = false
        }
        searchText = ""
    }
}

#Preview {
    TestSearchView()
}
