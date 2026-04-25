import UIKit

final class ImageOrientationFixer {
    private let maxProcessingDimension: CGFloat = 2048

    func normalize(image: UIImage) -> UIImage {
        let targetSize = scaledSize(for: image.size)
        let needsRedraw = image.imageOrientation != .up || targetSize != image.size

        guard needsRedraw else {
            return image
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func scaledSize(for size: CGSize) -> CGSize {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxProcessingDimension, longestSide > 0 else {
            return size
        }

        let scale = maxProcessingDimension / longestSide
        return CGSize(
            width: floor(size.width * scale),
            height: floor(size.height * scale)
        )
    }
}
