import SwiftUI

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    // Check if this is a custom asset icon
    private var isCustomIcon: Bool {
        ["none", "rookie", "solid", "club", "pro", "elite", "freak", "games", "wins", "win-rate"].contains(icon)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            if isCustomIcon {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(AppColor.brandPrimary)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(AppColor.brandPrimary)
            }
            VStack {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColor.textPrimary)
                
                Text(title)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.textSecondary)
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

#Preview("Stat Card Examples") {
    HStack(spacing: 12) {
        StatCard(title: "Games", value: "24", icon: "target")
        StatCard(title: "Win %", value: "62%", icon: "medal.fill")
        StatCard(title: "Avg Score", value: "58", icon: "chart.bar.fill")
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
