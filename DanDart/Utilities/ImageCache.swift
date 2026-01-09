//
//  ImageCache.swift
//  Dart Freak
//
//  Image caching utility for faster avatar loading
//

import SwiftUI

/// Simple in-memory image cache
class ImageCache {
    static let shared = ImageCache()
    
    private var cache = NSCache<NSString, UIImage>()
    
    private init() {
        // Configure cache limits
        cache.countLimit = 100 // Max 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}

/// Cached async image loader
@MainActor
class CachedImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    
    private let url: URL
    private let cache = ImageCache.shared
    
    init(url: URL) {
        self.url = url
    }
    
    func load() {
        let urlString = url.absoluteString
        
        // Check cache first
        if let cachedImage = cache.get(forKey: urlString) {
            self.image = cachedImage
            return
        }
        
        // Not in cache - download
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                if let downloadedImage = UIImage(data: data) {
                    // Cache the image
                    cache.set(downloadedImage, forKey: urlString)
                    
                    // Update UI
                    await MainActor.run {
                        self.image = downloadedImage
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                print("❌ Failed to load image: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

/// Cached async image view
struct CachedAsyncImage: View {
    @StateObject private var loader: CachedImageLoader
    let placeholder: () -> AnyView
    
    init(url: URL, @ViewBuilder placeholder: @escaping () -> some View) {
        _loader = StateObject(wrappedValue: CachedImageLoader(url: url))
        self.placeholder = { AnyView(placeholder()) }
    }
    
    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
            } else if loader.isLoading {
                placeholder()
            } else {
                placeholder()
            }
        }
        .onAppear {
            loader.load()
        }
    }
}
