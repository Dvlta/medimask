import UIKit

final class ImageProcessingPipeline {
    private let imageOrientationFixer = ImageOrientationFixer()
    private let faceDetector = MelangeFaceDetector()
    private let ocrService = VisionOCRService()
    private let phiDetector = PHIDetector()
    private let imageRedactor = ImageRedactor()

    func process(image: UIImage) async throws -> DetectionResult {
        let totalStartedAt = CFAbsoluteTimeGetCurrent()
        let normalizedImage = imageOrientationFixer.normalize(image: image)

        let faceReport: FaceDetectionReport
        do {
            faceReport = try await faceDetector.detectFacesReport(in: normalizedImage)
        } catch {
            Logger.app.error("Face detection failed: \(error.localizedDescription)")
            faceReport = FaceDetectionReport(regions: [], elapsedMs: 0, backend: "failed-fallback-none")
        }

        let ocrStartedAt = CFAbsoluteTimeGetCurrent()
        let textObservations: [OCRTextObservation]
        do {
            textObservations = try await ocrService.recognizeText(in: normalizedImage)
        } catch {
            Logger.app.error("OCR failed: \(error.localizedDescription)")
            textObservations = []
        }
        let ocrMs = Self.elapsedMilliseconds(since: ocrStartedAt)

        let phiStartedAt = CFAbsoluteTimeGetCurrent()
        let phiRegions = phiDetector.detectPHI(in: textObservations)
        let phiDetectionMs = Self.elapsedMilliseconds(since: phiStartedAt)

        let regions = faceReport.regions + phiRegions

        let redactionStartedAt = CFAbsoluteTimeGetCurrent()
        let scrubbedImage = imageRedactor.redact(image: normalizedImage, regions: regions)
        let redactionMs = Self.elapsedMilliseconds(since: redactionStartedAt)

        let timings = ProcessingTimings(
            faceDetectionMs: faceReport.elapsedMs,
            ocrMs: ocrMs,
            phiDetectionMs: phiDetectionMs,
            redactionMs: redactionMs,
            totalMs: Self.elapsedMilliseconds(since: totalStartedAt)
        )

        Logger.app.info(
            "Pipeline face backend: \(faceReport.backend, privacy: .public); timings ms - face: \(timings.faceDetectionMs, privacy: .public), ocr: \(timings.ocrMs, privacy: .public), phi: \(timings.phiDetectionMs, privacy: .public), redaction: \(timings.redactionMs, privacy: .public), total: \(timings.totalMs, privacy: .public)"
        )

        return DetectionResult(
            originalImage: normalizedImage,
            scrubbedImage: scrubbedImage,
            regions: regions,
            timings: timings
        )
    }

    private static func elapsedMilliseconds(since startedAt: CFAbsoluteTime) -> Double {
        (CFAbsoluteTimeGetCurrent() - startedAt) * 1000
    }
}
