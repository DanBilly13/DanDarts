import SwiftUI

#if canImport(ImagePlayground)
import ImagePlayground
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIImage = NSImage
#else
struct UIImage { }
#endif

struct ImagePlaygroundAvatarSheet: View {
    @Binding var isPresented: Bool
    let concept: String
    let onImagePicked: (UIImage) -> Void
    let onCancelled: (() -> Void)?

    var body: some View {
        Group {
            if #available(iOS 18.1, *) {
                Color.clear
                    .imagePlaygroundSheet(
                        isPresented: $isPresented,
                        concept: concept,
                        sourceImage: nil,
                        onCompletion: { url in
                            Task {
                                guard let data = try? Data(contentsOf: url),
                                      let image = UIImage(data: data) else {
                                    await MainActor.run {
                                        isPresented = false
                                        onCancelled?()
                                    }
                                    return
                                }

                                await MainActor.run {
                                    isPresented = false
                                    onImagePicked(image)
                                }
                            }
                        },
                        onCancellation: {
                            isPresented = false
                            onCancelled?()
                        }
                    )
            } else {
                EmptyView()
            }
        }
    }
}
