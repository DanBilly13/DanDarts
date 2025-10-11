//
//  ColorTestView.swift
//  DanDart
//
//  Created for testing color assets
//

import SwiftUI

struct ColorTestView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("DanDart Color Test")
                .font(.largeTitle)
                .foregroundColor(Color("TextPrimary"))
            
            VStack(spacing: 12) {
                ColorSwatch(name: "AccentPrimary", color: Color("AccentPrimary"))
                ColorSwatch(name: "AccentSecondary", color: Color("AccentSecondary"))
                ColorSwatch(name: "BackgroundPrimary", color: Color("BackgroundPrimary"))
                ColorSwatch(name: "SurfacePrimary", color: Color("SurfacePrimary"))
                ColorSwatch(name: "TextPrimary", color: Color("TextPrimary"))
                ColorSwatch(name: "TextSecondary", color: Color("TextSecondary"))
            }
        }
        .padding()
        .background(Color("BackgroundPrimary"))
    }
}

struct ColorSwatch: View {
    let name: String
    let color: Color
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(color)
                .frame(width: 50, height: 30)
                .cornerRadius(8)
            
            Text(name)
                .foregroundColor(Color("TextPrimary"))
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

#Preview {
    ColorTestView()
}
