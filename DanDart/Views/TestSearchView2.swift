import SwiftUI

/// Test using Apple's native .searchable() modifier with Mail-style presentation
struct TestSearchView2: View {
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @Environment(\.isSearching) private var isSearching
    
    let testItems = [
        "Match 1: 301 Game",
        "Match 2: 501 Game",
        "Match 3: Halve It",
        "Match 4: Knockout",
        "Match 5: Sudden Death"
    ]
    
    var filteredItems: [String] {
        // Show empty when search is active but no query
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
            ScrollView {
                LazyVStack(spacing: 12) {
                    if filteredItems.isEmpty && isSearching {
                        // Empty search state
                        VStack(spacing: 16) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(AppColor.textSecondary)
                            
                            Text(searchText.isEmpty ? "Start typing to search" : "No results found")
                                .font(.headline)
                                .foregroundColor(AppColor.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else {
                        ForEach(filteredItems, id: \.self) { item in
                            Text(item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(AppColor.surfacePrimary)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.backgroundPrimary)
            .navigationTitle("Mail-Style Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        print("🍎 [NATIVE] Search button tapped")
                        isSearchPresented = true
                    }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                }
            }
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                placement: .toolbar,
                prompt: "Search matches"
            )
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .onChange(of: isSearching) { oldValue, newValue in
                print("🍎 [NATIVE] isSearching changed: \(oldValue) -> \(newValue)")
            }
            .onChange(of: isSearchPresented) { oldValue, newValue in
                print("🍎 [NATIVE] isSearchPresented changed: \(oldValue) -> \(newValue)")
            }
        }
    }
}

#Preview {
    TestSearchView2()
}
