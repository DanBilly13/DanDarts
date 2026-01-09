//
//  UIImage+Resize.swift
//  Dart Freak
//
//  Extension for resizing UIImage to reduce file size before upload
//

import UIKit

extension UIImage {
    /// Resize image to fit within a maximum dimension while maintaining aspect ratio
    /// - Parameter maxDimension: Maximum width or height in points
    /// - Returns: Resized UIImage
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        // If image is already smaller than max, return original
        let currentMaxDimension = max(size.width, size.height)
        if currentMaxDimension <= maxDimension {
            return self
        }
        
        // Calculate new size maintaining aspect ratio
        let scale = maxDimension / currentMaxDimension
        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        
        // Render resized image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Resize image to exact dimensions (may distort aspect ratio)
    /// - Parameters:
    ///   - width: Target width in points
    ///   - height: Target height in points
    /// - Returns: Resized UIImage
    func resized(toWidth width: CGFloat, height: CGFloat) -> UIImage {
        let newSize = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Resize image to fit within a square while maintaining aspect ratio
    /// - Parameter size: Square dimension in points
    /// - Returns: Resized UIImage
    func resizedToSquare(size: CGFloat) -> UIImage {
        return resized(toMaxDimension: size)
    }
}
