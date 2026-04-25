import UIKit

final class ImageProcessingPipeline {
    private let imageOrientationFixer = ImageOrientationFixer()
    private let faceDetector = MelangeFaceDetector()
    private let ocrService = VisionOCRService()
    private let phiDetector = PHIDetector()
    private let imageRedactor = ImageRedactor()

    func process(image: UIImage) async throws -> DetectionResult {
        let totalStart = Date()
        let normalizedImage = imageOrientationFixer.normalize(image: image)

        let faceStart = Date()
        let faceRegions = try await faceDetector.detectFaces(in: normalizedImage)
        let faceMs = Date().timeIntervalSince(faceStart) * 1000

        let ocrStart = Date()
        let textObservations = try await ocrService.recognizeText(in: normalizedImage)
        let ocrMs = Date().timeIntervalSince(ocrStart) * 1000

        let phiStart = Date()
        let phiRegions = phiDetector.detectPHI(in: textObservations)
        let phiMs = Date().timeIntervalSince(phiStart) * 1000

        let regions = faceRegions + phiRegions

        let redactStart = Date()
        let scrubbedImage = imageRedactor.redact(image: normalizedImage, regions: regions)
        let redactMs = Date().timeIntervalSince(redactStart) * 1000

        let timings = ProcessingTimings(
            faceDetectionMs: faceMs,
            ocrMs: ocrMs,
            phiDetectionMs: phiMs,
            redactionMs: redactMs,
            totalMs: Date().timeIntervalSince(totalStart) * 1000
        )

        return DetectionResult(
            originalImage: normalizedImage,
            scrubbedImage: scrubbedImage,
            regions: regions,
            timings: timings
        )
    }
}
