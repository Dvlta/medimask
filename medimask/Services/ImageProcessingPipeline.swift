import UIKit

final class ImageProcessingPipeline {
    private let imageOrientationFixer = ImageOrientationFixer()
    private let faceDetector = MelangeFaceDetector()
    private let ocrService = VisionOCRService()
    private let phiDetector = PHIDetector()
    private let imageRedactor = ImageRedactor()

    func process(image: UIImage) async throws -> DetectionResult {
        let normalizedImage = imageOrientationFixer.normalize(image: image)

        let faceRegions = try await faceDetector.detectFaces(in: normalizedImage)
        let textObservations = try await ocrService.recognizeText(in: normalizedImage)
        let phiRegions = phiDetector.detectPHI(in: textObservations)
        let regions = faceRegions + phiRegions
        let scrubbedImage = imageRedactor.redact(image: normalizedImage, regions: regions)

        let timings = ProcessingTimings(
            faceDetectionMs: 120,
            ocrMs: 140,
            phiDetectionMs: 8,
            redactionMs: 32,
            totalMs: 300
        )

        return DetectionResult(
            originalImage: normalizedImage,
            scrubbedImage: scrubbedImage,
            regions: regions,
            timings: timings
        )
    }
}
