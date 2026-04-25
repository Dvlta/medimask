import UIKit

final class ImageRedactor {
    func redact(image: UIImage, regions: [RedactionRegion]) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: image.size))

            for region in regions {
                switch region.redactionStyle {
                case .blackBox:
                    UIColor.black.setFill()
                    context.fill(region.rect)
                case .blur, .pixelate:
                    UIColor.black.withAlphaComponent(0.72).setFill()
                    context.fill(region.rect)
                }
            }
        }
    }
}
