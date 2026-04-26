import UIKit

final class ImageProcessingPipeline {
    private let imageOrientationFixer = ImageOrientationFixer()
    private let faceDetector = MelangeFaceDetector()
    private let ocrService = VisionOCRService()
    private let phiDetector = SensitiveTextRegionDetector()
    private let imageRedactor = ImageRedactor()

    func analyze(image: UIImage) async -> (image: UIImage, regions: [RedactionRegion], timings: ProcessingTimings) {
        let totalStartedAt = CFAbsoluteTimeGetCurrent()
        let normalizedImage = imageOrientationFixer.normalize(image: image)

        let faceReport: FaceDetectionReport
        do {
            faceReport = try await faceDetector.detectFacesReport(in: normalizedImage)
        } catch {
            Logger.app.error("Face detection failed during analysis: \(error.localizedDescription)")
            faceReport = FaceDetectionReport(regions: [], elapsedMs: 0, backend: "failed-fallback-none")
        }

        let ocrStartedAt = CFAbsoluteTimeGetCurrent()
        let textObservations: [OCRTextObservation]
        do {
            textObservations = try await ocrService.recognizeText(
                in: normalizedImage,
                faceRegions: faceReport.regions
            )
        } catch {
            Logger.app.error("OCR failed during analysis: \(error.localizedDescription)")
            textObservations = []
        }
        let ocrMs = Self.elapsedMilliseconds(since: ocrStartedAt)

        let phiStartedAt = CFAbsoluteTimeGetCurrent()
        let phiReport = await phiDetector.detectPHI(in: textObservations)
        let phiDetectionMs = Self.elapsedMilliseconds(since: phiStartedAt)

        let timings = ProcessingTimings(
            faceDetectionMs: faceReport.elapsedMs,
            ocrMs: ocrMs,
            phiDetectionMs: phiDetectionMs,
            redactionMs: 0,
            totalMs: Self.elapsedMilliseconds(since: totalStartedAt)
        )

        return (normalizedImage, faceReport.regions + phiReport.regions, timings)
    }

    func process(image: UIImage) async throws -> DetectionResult {
        let analysis = await analyze(image: image)
        let normalizedImage = analysis.image
        let regions = analysis.regions

        let redactionStartedAt = CFAbsoluteTimeGetCurrent()
        let scrubbedImage = imageRedactor.redact(image: normalizedImage, regions: regions)
        let redactionMs = Self.elapsedMilliseconds(since: redactionStartedAt)

        let timings = ProcessingTimings(
            faceDetectionMs: analysis.timings.faceDetectionMs,
            ocrMs: analysis.timings.ocrMs,
            phiDetectionMs: analysis.timings.phiDetectionMs,
            redactionMs: redactionMs,
            totalMs: analysis.timings.totalMs + redactionMs
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
