import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIImage = NSImage
typealias UIColor = NSColor
#else
struct UIImage { }
#endif

enum AvatarGenerationStyle: String, CaseIterable, Identifiable {
    case animatedMascotHuman = "Animated Mascot – Human"
    case animatedMascotFeminine = "Animated Mascot – Feminine"
    case animatedMascotAnimal = "Animated Mascot – Animal"

    var id: String { rawValue }

    var iconSystemName: String {
        switch self {
        case .animatedMascotHuman:
            return "target"
        case .animatedMascotFeminine:
            return "paintpalette"
        case .animatedMascotAnimal:
            return "bolt"
        }
    }
}

enum AvatarGenerationError: Error {
    case generationFailed
}

protocol AvatarGenerationService {
    func generateAvatar(style: AvatarGenerationStyle) async throws -> UIImage
}

final class MockAvatarGenerationService: AvatarGenerationService {
    func generateAvatar(style: AvatarGenerationStyle) async throws -> UIImage {
        try await Task.sleep(nanoseconds: 900_000_000)
        if Task.isCancelled {
            throw CancellationError()
        }

        #if canImport(UIKit)
        return makeMockAvatarImage(seed: "\(style.rawValue)_\(UUID().uuidString)")
        #else
        throw AvatarGenerationError.generationFailed
        #endif
    }

    private func makeMockAvatarImage(seed: String) -> UIImage {
        #if canImport(UIKit)
        let colors: [UIColor] = [
            UIColor.systemBlue,
            UIColor.systemOrange,
            UIColor.systemPink,
            UIColor.systemGreen,
            UIColor.systemPurple
        ]

        let index = abs(seed.hashValue) % colors.count
        let color = colors[index]

        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))

            let overlayColor = UIColor.white.withAlphaComponent(0.25)
            overlayColor.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 70, y: 70, width: 240, height: 240))

            let overlayColor2 = UIColor.black.withAlphaComponent(0.15)
            overlayColor2.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 220, y: 240, width: 260, height: 260))
        }
        #else
        return UIImage()
        #endif
    }
}
