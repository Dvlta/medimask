import CoreImage
import UIKit

final class ImageRedactor {
    private let ciContext = CIContext(options: nil)

    func redact(image: UIImage, regions: [RedactionRegion]) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let imageRect = CGRect(origin: .zero, size: image.size)

        let blurredImage = filteredImage(
            from: image,
            filterName: "CIGaussianBlur",
            parameters: [kCIInputRadiusKey: 18]
        )
        let pixelatedImage = filteredImage(
            from: image,
            filterName: "CIPixellate",
            parameters: [kCIInputScaleKey: 24]
        )

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            image.draw(in: imageRect)

            for region in regions {
                switch region.redactionStyle {
                case .blackBox:
                    UIColor.black.setFill()
                    context.fill(region.rect)
                case .blur:
                    guard let blurredImage else {
                        UIColor.black.withAlphaComponent(0.72).setFill()
                        context.fill(region.rect)
                        continue
                    }

                    context.cgContext.saveGState()
                    context.cgContext.clip(to: region.rect)
                    blurredImage.draw(in: imageRect)
                    context.cgContext.restoreGState()
                case .pixelate:
                    guard let pixelatedImage else {
                        UIColor.black.withAlphaComponent(0.72).setFill()
                        context.fill(region.rect)
                        continue
                    }

                    context.cgContext.saveGState()
                    context.cgContext.clip(to: region.rect)
                    pixelatedImage.draw(in: imageRect)
                    context.cgContext.restoreGState()
                }
            }
        }
    }

    private func filteredImage(
        from image: UIImage,
        filterName: String,
        parameters: [String: Any]
    ) -> UIImage? {
        guard let inputCGImage = image.cgImage else {
            return nil
        }

        let inputImage = CIImage(cgImage: inputCGImage)
        guard let filter = CIFilter(name: filterName) else {
            return nil
        }

        filter.setValue(inputImage, forKey: kCIInputImageKey)
        for (key, value) in parameters {
            filter.setValue(value, forKey: key)
        }

        guard let outputImage = filter.outputImage?.cropped(to: inputImage.extent),
              let outputCGImage = ciContext.createCGImage(outputImage, from: inputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: .up)
    }
}
