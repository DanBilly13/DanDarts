//
//  TestSearchView5.swift
//  DanDart
//
//  Simple keyboard test - just get the keyboard to appear
//

import SwiftUI

struct TestSearchView5: View {
    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    @State private var isWarmedUp: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Tap the field below")
                    .font(.headline)
                
                TextField("Type here", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .padding()
                
                Text("Text: '\(text)'")
                    .foregroundColor(.secondary)
                
                Button("Focus Programmatically") {
                    isFocused = true
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Keyboard Test")
            .onAppear {
                // Hack: Pre-warm the text input system
                // Focus and immediately unfocus to initialize the session
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isFocused = false
                        isWarmedUp = true
                        print("✅ Text input system warmed up")
                    }
                }
            }
        }
    }
}

#Preview {
    TestSearchView5()
}
