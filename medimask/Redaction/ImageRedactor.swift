import CoreImage
import UIKit

enum RedactionIntensityMode: String, CaseIterable, Identifiable {
    case balanced = "Balanced"
    case highPrivacy = "High Privacy"

    var id: String { rawValue }
}

final class ImageRedactor {
    private let ciContext = CIContext(options: nil)

    func redact(
        image: UIImage,
        regions: [RedactionRegion],
        intensityMode: RedactionIntensityMode = .balanced
    ) -> UIImage {
        let sanitizedRegions = regions.compactMap { sanitize(region: $0, imageSize: image.size) }
        let effectsImage = applyEffects(image: image, regions: sanitizedRegions, intensityMode: intensityMode)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            effectsImage.draw(in: CGRect(origin: .zero, size: image.size))

            for region in sanitizedRegions {
                switch region.redactionStyle {
                case .blackBox:
                    UIColor.black.setFill()
                    context.fill(region.rect)
                case .blur, .pixelate:
                    // Keep the original color profile visible after blur.
                    continue
                }
            }
        }
    }

    private func applyEffects(
        image: UIImage,
        regions: [RedactionRegion],
        intensityMode: RedactionIntensityMode
    ) -> UIImage {
        guard let cgImage = image.cgImage else {
            return image
        }

        let sourceImage = CIImage(cgImage: sourceCGImage)
        var outputImage = sourceImage

        for region in regions {
            switch region.redactionStyle {
            case .blur:
                if let blurred = applyBlurStack(
                    to: outputImage,
                    in: region.rect,
                    region: region,
                    intensityMode: intensityMode
                ) {
                    outputImage = blurred
                }
            case .pixelate:
                if let pixelated = applyPixellate(to: outputImage, in: region.rect) {
                    outputImage = pixelated
                }
            case .blackBox:
                continue
            }
        }

        guard let filteredCGImage = ciContext.createCGImage(outputImage, from: sourceImage.extent) else {
            return image
        }
        return UIImage(cgImage: filteredCGImage, scale: image.scale, orientation: .up)
    }

    private func applyBlurStack(
        to image: CIImage,
        in rect: CGRect,
        region: RedactionRegion,
        intensityMode: RedactionIntensityMode
    ) -> CIImage? {
        let radius = blurRadius(for: region, intensityMode: intensityMode)
        guard let gaussian = applyGaussianBlur(to: image, in: rect, radius: radius) else {
            return nil
        }

        if intensityMode == .highPrivacy {
            let pixelScale = pixelScale(for: region)
            let directionalAngle = directionAngle(for: region)
            let afterPixelate = applyPixellate(to: gaussian, in: rect, scale: pixelScale) ?? gaussian
            let afterDirectional = applyMotionBlur(to: afterPixelate, in: rect, radius: radius * 0.82, angle: directionalAngle)
            return afterDirectional ?? afterPixelate
        }

        return gaussian
    }

    private func applyGaussianBlur(to image: CIImage, in rect: CGRect, radius: Double) -> CIImage? {
        let cropRect = ciRect(for: rect, imageExtent: image.extent)
        let cropped = image.cropped(to: cropRect)

        guard let blur = CIFilter(name: "CIGaussianBlur") else {
            return nil
        }
        blur.setValue(cropped, forKey: kCIInputImageKey)
        blur.setValue(radius, forKey: kCIInputRadiusKey)

        guard let blurred = blur.outputImage?.cropped(to: cropRect) else {
            return nil
        }
        return blurred.composited(over: image)
    }

    private func applyPixellate(to image: CIImage, in rect: CGRect, scale: Double = 20.0) -> CIImage? {
        let cropRect = ciRect(for: rect, imageExtent: image.extent)
        let cropped = image.cropped(to: cropRect)

        guard let pixellate = CIFilter(name: "CIPixellate") else {
            return nil
        }
        pixellate.setValue(cropped, forKey: kCIInputImageKey)
        pixellate.setValue(scale, forKey: kCIInputScaleKey)
        pixellate.setValue(CIVector(x: cropRect.midX, y: cropRect.midY), forKey: kCIInputCenterKey)

        guard let pixelated = pixellate.outputImage?.cropped(to: cropRect) else {
            return nil
        }
        return pixelated.composited(over: image)
    }

    private func applyMotionBlur(to image: CIImage, in rect: CGRect, radius: Double, angle: Double) -> CIImage? {
        let cropRect = ciRect(for: rect, imageExtent: image.extent)
        let cropped = image.cropped(to: cropRect)

        guard let motionBlur = CIFilter(name: "CIMotionBlur") else {
            return nil
        }
        motionBlur.setValue(cropped, forKey: kCIInputImageKey)
        motionBlur.setValue(radius, forKey: kCIInputRadiusKey)
        motionBlur.setValue(angle, forKey: kCIInputAngleKey)

        guard let blurred = motionBlur.outputImage?.cropped(to: cropRect) else {
            return nil
        }
        return blurred.composited(over: image)
    }

    private func ciRect(for imageRect: CGRect, imageExtent: CGRect) -> CGRect {
        let flippedY = imageExtent.height - imageRect.maxY
        let ciRect = CGRect(x: imageRect.minX, y: flippedY, width: imageRect.width, height: imageRect.height)
        return ciRect.intersection(imageExtent)
    }

    private func sanitize(region: RedactionRegion, imageSize: CGSize) -> RedactionRegion? {
        let imageBounds = CGRect(origin: .zero, size: imageSize)
        let clamped = region.rect.intersection(imageBounds)
        guard !clamped.isNull, clamped.width >= 2, clamped.height >= 2 else {
            return nil
        }

        let pad = sanitizePadding(for: region)
        let padded = clamped.insetBy(dx: -pad.horizontal, dy: -pad.vertical).intersection(imageBounds)
        let effectiveStyle: RedactionStyle = region.redactionStyle == .blackBox ? .blur : region.redactionStyle

        return RedactionRegion(
            id: region.id,
            rect: padded,
            type: region.type,
            label: region.label,
            confidence: region.confidence,
            source: region.source,
            redactionStyle: effectiveStyle
        )
    }

    private func blurRadius(for region: RedactionRegion, intensityMode: RedactionIntensityMode) -> Double {
        let multiplier: Double = intensityMode == .highPrivacy ? 2.35 : 1.0
        let label = region.label.uppercased()
        if label.contains("BADGE PHOTO") {
            return 24 * multiplier
        }
        if label.contains("BARCODE") || label.contains("DRIVER LICENSE") {
            return 20 * multiplier
        }
        if region.type == .face {
            return 16 * multiplier
        }
        return 14 * multiplier
    }

    private func pixelScale(for region: RedactionRegion) -> Double {
        let label = region.label.uppercased()
        if label.contains("BADGE PHOTO") || label.contains("FACE") {
            return 28
        }
        if label.contains("BARCODE") || label.contains("ID") {
            return 24
        }
        return 18
    }

    private func directionAngle(for region: RedactionRegion) -> Double {
        // Slight angle helps hide directional text features better than axis-aligned blur.
        return region.rect.width > region.rect.height ? 0.17 : 1.22
    }

    private func sanitizePadding(for region: RedactionRegion) -> (horizontal: CGFloat, vertical: CGFloat) {
        let label = region.label.uppercased()
        if label.contains("BARCODE") {
            return (12, 8)
        }
        if label.contains("BADGE PHOTO") {
            return (8, 8)
        }
        if region.type == .face {
            return (10, 10)
        }
        return (6, 6)
    }
}
