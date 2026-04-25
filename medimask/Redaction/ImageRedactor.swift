import CoreImage
import UIKit

final class ImageRedactor {
    private let ciContext = CIContext(options: nil)

    func redact(image: UIImage, regions: [RedactionRegion]) -> UIImage {
        let sanitizedRegions = regions.compactMap { sanitize(region: $0, imageSize: image.size) }
        let effectsImage = applyEffects(image: image, regions: sanitizedRegions)

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
                    continue
                }
            }
        }
    }

    private func applyEffects(image: UIImage, regions: [RedactionRegion]) -> UIImage {
        guard let sourceCGImage = sourceCGImage(for: image) else {
            return image
        }

        let sourceImage = CIImage(cgImage: sourceCGImage)
        var outputImage = sourceImage

        for region in regions {
            switch region.redactionStyle {
            case .blur:
                if let blurred = applyGaussianBlur(to: outputImage, in: region.rect) {
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

    private func applyGaussianBlur(to image: CIImage, in rect: CGRect) -> CIImage? {
        let cropRect = ciRect(for: rect, imageExtent: image.extent)
        let cropped = image.cropped(to: cropRect)

        guard let blur = CIFilter(name: "CIGaussianBlur") else {
            return nil
        }
        blur.setValue(cropped, forKey: kCIInputImageKey)
        blur.setValue(10.0, forKey: kCIInputRadiusKey)

        guard let blurred = blur.outputImage?.cropped(to: cropRect) else {
            return nil
        }
        return blurred.composited(over: image)
    }

    private func applyPixellate(to image: CIImage, in rect: CGRect) -> CIImage? {
        let cropRect = ciRect(for: rect, imageExtent: image.extent)
        let cropped = image.cropped(to: cropRect)

        guard let pixellate = CIFilter(name: "CIPixellate") else {
            return nil
        }
        pixellate.setValue(cropped, forKey: kCIInputImageKey)
        pixellate.setValue(20.0, forKey: kCIInputScaleKey)
        pixellate.setValue(CIVector(x: cropRect.midX, y: cropRect.midY), forKey: kCIInputCenterKey)

        guard let pixelated = pixellate.outputImage?.cropped(to: cropRect) else {
            return nil
        }
        return pixelated.composited(over: image)
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

        let padded = clamped.insetBy(dx: -4, dy: -4).intersection(imageBounds)
        return RedactionRegion(
            id: region.id,
            rect: padded,
            type: region.type,
            label: region.label,
            confidence: region.confidence,
            source: region.source,
            redactionStyle: region.redactionStyle
        )
    }

    private func sourceCGImage(for image: UIImage) -> CGImage? {
        if let cgImage = image.cgImage {
            return cgImage
        }

        if let ciImage = image.ciImage {
            return ciContext.createCGImage(ciImage, from: ciImage.extent)
        }

        let renderedImage = UIGraphicsImageRenderer(size: image.size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return renderedImage.cgImage
    }
}
