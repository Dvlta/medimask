import CoreGraphics

enum CoordinateMapper {
    static func mapImageRect(_ rect: CGRect, imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return .zero
        }

        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let offsetX = (containerSize.width - scaledImageSize.width) / 2
        let offsetY = (containerSize.height - scaledImageSize.height) / 2

        return CGRect(
            x: rect.minX * scale + offsetX,
            y: rect.minY * scale + offsetY,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }
}
