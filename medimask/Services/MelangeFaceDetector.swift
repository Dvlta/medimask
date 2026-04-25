import UIKit

final class MelangeFaceDetector {
    func detectFaces(in image: UIImage) async throws -> [RedactionRegion] {
        let width = image.size.width
        let height = image.size.height

        guard width > 0, height > 0 else {
            return []
        }

        // Placeholder face box until Melange or Vision is integrated.
        let faceRect = CGRect(
            x: width * 0.62,
            y: height * 0.14,
            width: width * 0.18,
            height: height * 0.2
        )

        return [
            RedactionRegion(
                rect: faceRect,
                type: .face,
                label: "FACE",
                confidence: 0.9,
                source: "melange-face-placeholder",
                redactionStyle: .blur
            )
        ]
    }
}
