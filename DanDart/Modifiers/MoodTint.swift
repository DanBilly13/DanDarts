import SwiftUI

enum MoodTint { case green, red, yellow, grey }

extension View {
    /// Rounded, dark card background with a muted hue gradient.
    func moodCard(_ tint: MoodTint, radius: CGFloat = 20) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius)
                .fill(Color.black) // base
                .overlay(
                    // gradient painted within the shape but behind content
                    LinearGradient.cardGradient(tint)
                        .clipShape(RoundedRectangle(cornerRadius: radius))
                )
        }
    }
}

private extension LinearGradient {
    static func cardGradient(_ tint: MoodTint) -> LinearGradient {
        switch tint {
        case .green:
            // from deep emerald to bright green
            return LinearGradient(
                colors: [
                    Color(red: 0.047, green: 0.243, blue: 0.176).opacity(0.4),  // #0C3E2D
                    Color(red: 0.118, green: 0.494, blue: 0.325).opacity(0.35)   // #1E7E53
                ],
                startPoint: .top, endPoint: .bottomTrailing
            )

        case .red:
            // from warm dark red to glowing coral
            return LinearGradient(
                colors: [
                    Color(red: 0.235, green: 0.047, blue: 0.031).opacity(0.4),  // #3C0C08
                    Color(red: 0.651, green: 0.235, blue: 0.169).opacity(0.35)   // #A63C2B
                ],
                startPoint: .top, endPoint: .bottomTrailing
            )

        case .yellow:
            // from deep golden brown to warm amber
            return LinearGradient(
                colors: [
                    Color(red: 0.227, green: 0.165, blue: 0.027).opacity(0.4), // #3A2A07
                    Color(red: 0.773, green: 0.537, blue: 0.102).opacity(0.35)   // #C5891A
                ],
                startPoint: .top, endPoint: .bottomTrailing
            )
            
        case .grey:
            // from deep golden brown to warm amber
            return LinearGradient(
                colors: [
                    Color(red: 0.227, green: 0.165, blue: 0.027).opacity(0.4), // #3A2A07
                    Color(red: 0.773, green: 0.537, blue: 0.102).opacity(0.35)   // #C5891A
                ],
                startPoint: .top, endPoint: .bottomTrailing
            )
        }
    }
}

#if DEBUG
struct MoodTint_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Page/background
            Color("BackgroundPrimary").ignoresSafeArea()

            // Stack of big sample cards
            VStack(spacing: 20) {
                cardSample(title: "Red Mood Card", tint: .red)
                cardSample(title: "Green Mood Card", tint: .green)
                cardSample(title: "Yellow Mood Card", tint: .yellow)
                cardSample(title: "Yellow Mood Card", tint: .grey)
            }
            .padding(20)
        }
        .previewDisplayName("Mood Cards on BackgroundPrimary")
        .preferredColorScheme(.dark) // remove if you want to test light mode
    }

    // A helper to show a typical card layout
    private static func cardSample(title: String, tint: MoodTint) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text("Example subtitle")
                .font(.subheadline)
                .opacity(0.7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .frame(height: 120)          // bigger cards
        .moodCard(tint, radius: 24)  // uses your component
    }
}
#endif
