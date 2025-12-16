import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIImage = NSImage
#else
struct UIImage { }
#endif

@MainActor
final class AvatarGenerationViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case generating
        case preview
        case error(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var selectedStyle: AvatarGenerationStyle?
    @Published private(set) var previewImage: UIImage?

    private let service: AvatarGenerationService
    private var generationTask: Task<Void, Never>?

    init(service: AvatarGenerationService) {
        self.service = service
    }

    func selectStyle(_ style: AvatarGenerationStyle) {
        selectedStyle = style
        regenerate()
    }

    func regenerate() {
        guard let selectedStyle else { return }

        generationTask?.cancel()
        state = .generating
        previewImage = nil

        let style = selectedStyle
        print("✨ Avatar generation started: \(style.rawValue)")

        generationTask = Task {
            do {
                let image = try await generateWithTimeout(style: style, timeoutNanoseconds: 12_000_000_000)
                if Task.isCancelled { return }

                previewImage = image
                state = .preview
                print("✨ Avatar generation succeeded: \(style.rawValue)")
            } catch is CancellationError {
                return
            } catch {
                previewImage = nil
                let message: String
                if error is TimeoutError {
                    message = "Taking too long to generate. Please try again."
                } else {
                    message = "Failed to generate avatar. Please try again."
                }
                state = .error(message)
                print("❌ Avatar generation failed: \(style.rawValue) - \(String(describing: error))")
            }
        }
    }

    private struct TimeoutError: Error { }

    private func generateWithTimeout(
        style: AvatarGenerationStyle,
        timeoutNanoseconds: UInt64
    ) async throws -> UIImage {
        try await withThrowingTaskGroup(of: UIImage.self) { group in
            group.addTask {
                try await self.service.generateAvatar(style: style)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw TimeoutError()
            }

            defer {
                group.cancelAll()
            }

            guard let first = try await group.next() else {
                throw CancellationError()
            }
            return first
        }
    }

    func cancelInFlight() {
        generationTask?.cancel()
        generationTask = nil
    }
}
