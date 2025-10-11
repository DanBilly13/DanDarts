//
//  ContentView.swift
//  DanDart
//
//  Created by Billingham Daniel on 2025-10-10.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "target")
                .imageScale(.large)
                .foregroundColor(Color("AccentPrimary"))
                .font(.system(size: 60))
            
            Text("DanDarts")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color("TextPrimary"))
            
            Text("Ready to play darts!")
                .font(.title2)
                .foregroundColor(Color("TextSecondary"))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("BackgroundPrimary"))
    }
}

#Preview {
    ContentView()
}
