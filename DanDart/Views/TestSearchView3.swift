import SwiftUI

/// Test using UIKit UISearchController wrapped in SwiftUI
struct TestSearchView3: View {
    @State private var searchText = ""
    @State private var isSearching = false
    
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
                // Main content - hide when searching
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
            .navigationTitle("UIKit Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        print("🔧 [UIKIT] Search button tapped")
                        withAnimation {
                            isSearching = true
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                }
            }
            .overlay(
                ZStack {
                    // Dim background
                    if isSearching {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .transition(.opacity)
                            .zIndex(0)
                    }
                    
                    // Search overlay on top
                    if isSearching {
                        SearchBarOverlay(
                            searchText: $searchText,
                            isSearching: $isSearching
                        )
                        .transition(.move(edge: .bottom))
                        .zIndex(1)
                    }
                }
            )
        }
    }
}

/// Simple search bar using UITextField (which DOES show keyboard)
struct SearchBarOverlay: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    @State private var textField: UITextField?
    
    let testItems = [
        "Match 1: 301 Game",
        "Match 2: 501 Game",
        "Match 3: Halve It",
        "Match 4: Knockout",
        "Match 5: Sudden Death"
    ]
    
    var filteredItems: [String] {
        if searchText.isEmpty {
            return []
        }
        return testItems.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
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
            } else {
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
            }
            
            // Search bar (pinned to bottom, above keyboard)
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                    
                    // Use UITextField wrapper
                    UITextFieldWrapper(
                        text: $searchText,
                        placeholder: "Search",
                        onCommit: {},
                        textField: $textField
                    )
                    
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
                    textField?.resignFirstResponder()
                    withAnimation {
                        isSearching = false
                    }
                    searchText = ""
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
        .onAppear {
            print("🔧 [UIKIT] Overlay appeared")
            // Delay to let view render
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🔧 [UIKIT] Becoming first responder")
                textField?.becomeFirstResponder()
            }
        }
    }
}

/// UITextField wrapper that actually shows the keyboard
struct UITextFieldWrapper: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onCommit: () -> Void
    @Binding var textField: UITextField?
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.delegate = context.coordinator
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.returnKeyType = .search
        textField.textColor = UIColor(AppColor.textPrimary)
        textField.font = .systemFont(ofSize: 17)
        
        // Store reference
        DispatchQueue.main.async {
            self.textField = textField
        }
        
        print("🔧 [UIKIT] UITextField created")
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        let onCommit: () -> Void
        
        init(text: Binding<String>, onCommit: @escaping () -> Void) {
            _text = text
            self.onCommit = onCommit
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onCommit()
            return true
        }
    }
}

#Preview {
    TestSearchView3()
}
