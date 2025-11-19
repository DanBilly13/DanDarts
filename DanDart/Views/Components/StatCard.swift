import SwiftUI

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(Color("AccentPrimary"))
            VStack {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color("TextPrimary"))
                
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(Color("TextSecondary"))
            }
        }
        // Forward the baseline of the card to the title text
        .alignmentGuide(.lastTextBaseline) { d in
            d[.lastTextBaseline]
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .cornerRadius(12)
    }
}
