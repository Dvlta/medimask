import CoreGraphics

enum CoordinateMapper {
    static func mapImageRect(
        _ rect: CGRect,
        imageSize: CGSize,
        containerSize: CGSize,
        padding: CGFloat = 0
    ) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return .zero
        }

        let imageBounds = CGRect(origin: .zero, size: imageSize)
        let clampedRect = rect.intersection(imageBounds)
        guard !clampedRect.isNull, clampedRect.width > 0, clampedRect.height > 0 else {
            return .zero
        }

        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let offsetX = (containerSize.width - scaledImageSize.width) / 2
        let offsetY = (containerSize.height - scaledImageSize.height) / 2

        let mappedRect = CGRect(
            x: clampedRect.minX * scale + offsetX,
            y: clampedRect.minY * scale + offsetY,
            width: clampedRect.width * scale,
            height: clampedRect.height * scale
        )

        let paddedRect = mappedRect.insetBy(dx: -padding, dy: -padding)
        let containerBounds = CGRect(origin: .zero, size: containerSize)
        let safeRect = paddedRect.intersection(containerBounds)
        if safeRect.isNull {
            return .zero
        }
        return safeRect
    }
}
