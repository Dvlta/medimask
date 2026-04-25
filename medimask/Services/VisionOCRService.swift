import UIKit

final class VisionOCRService {
    func recognizeText(in image: UIImage) async throws -> [OCRTextObservation] {
        let width = image.size.width
        let height = image.size.height

        guard width > 0, height > 0 else {
            return []
        }

        // Placeholder OCR output so the review/redaction flow is already wired.
        return [
            OCRTextObservation(
                text: "Patient: Jane Smith",
                rect: CGRect(x: width * 0.08, y: height * 0.18, width: width * 0.52, height: height * 0.06),
                confidence: 0.98
            ),
            OCRTextObservation(
                text: "DOB: 03/14/1982",
                rect: CGRect(x: width * 0.08, y: height * 0.27, width: width * 0.42, height: height * 0.06),
                confidence: 0.96
            ),
            OCRTextObservation(
                text: "MRN: A9283910",
                rect: CGRect(x: width * 0.08, y: height * 0.36, width: width * 0.36, height: height * 0.06),
                confidence: 0.95
            )
        ]
    }
}
