import CoreGraphics
import UIKit
import Vision

struct FaceDetectionReport {
    let regions: [RedactionRegion]
    let elapsedMs: Double
    let backend: String
}

final class MelangeFaceDetector {
    func detectFaces(in image: UIImage) async throws -> [RedactionRegion] {
        try await detectFacesReport(in: image).regions
    }

    func detectFacesReport(in image: UIImage) async throws -> FaceDetectionReport {
        let startedAt = CFAbsoluteTimeGetCurrent()

        guard image.size.width > 0, image.size.height > 0 else {
            return FaceDetectionReport(regions: [], elapsedMs: 0, backend: "none")
        }

        if let melangeReport = try await detectWithMelangeIfAvailable(in: image, startedAt: startedAt) {
            return melangeReport
        }

        let faceRegions = try detectWithVision(in: image)
        let elapsedMs = Self.elapsedMilliseconds(since: startedAt)

        Logger.app.info("Face detection used fallback backend: apple-vision-face")

        return FaceDetectionReport(
            regions: faceRegions,
            elapsedMs: elapsedMs,
            backend: "apple-vision-face"
        )
    }

    private func detectWithMelangeIfAvailable(
        in image: UIImage,
        startedAt: CFAbsoluteTime
    ) async throws -> FaceDetectionReport? {
        _ = image
        _ = startedAt

        // Melange is the preferred on-device detector for the hackathon track, but this
        // repository does not currently include the SDK or a linked model wrapper. Keep the
        // integration seam here so the pipeline API stays stable and the fallback path remains
        // honest: if no real Melange implementation is present, we immediately use Vision.
        return nil
    }

    private func detectWithVision(in image: UIImage) throws -> [RedactionRegion] {
        let request = VNDetectFaceRectanglesRequest()
        let handler = try Self.makeImageRequestHandler(for: image)
        try handler.perform([request])

        let imageSize = image.size
        let imageBounds = CGRect(origin: .zero, size: imageSize)

        return (request.results ?? []).compactMap { observation in
            let rect = Self.imageRect(fromVisionBoundingBox: observation.boundingBox, imageSize: imageSize)
                .intersection(imageBounds)

            guard !rect.isNull, rect.width > 0, rect.height > 0 else {
                return nil
            }

            return RedactionRegion(
                rect: rect,
                type: .face,
                label: "FACE",
                confidence: observation.confidence,
                source: "apple-vision-face",
                redactionStyle: .blur
            )
        }
    }

    private static func makeImageRequestHandler(for image: UIImage) throws -> VNImageRequestHandler {
        if let cgImage = image.cgImage {
            return VNImageRequestHandler(cgImage: cgImage, options: [:])
        }

        if let ciImage = image.ciImage {
            return VNImageRequestHandler(ciImage: ciImage, options: [:])
        }

        guard let fallbackCGImage = UIGraphicsImageRenderer(size: image.size).image(actions: { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }).cgImage else {
            throw FaceDetectionError.unsupportedImage
        }

        return VNImageRequestHandler(cgImage: fallbackCGImage, options: [:])
    }

    private static func imageRect(fromVisionBoundingBox boundingBox: CGRect, imageSize: CGSize) -> CGRect {
        // Vision face observations are normalized to [0, 1] with an origin at the bottom-left.
        // The rest of the app expects raw image-space rectangles in pixels/points relative to
        // the normalized UIImage, with an origin at the top-left because that matches UIKit
        // drawing, redaction rendering, and overlay mapping.
        let width = boundingBox.width * imageSize.width
        let height = boundingBox.height * imageSize.height
        let x = boundingBox.minX * imageSize.width
        let y = (1 - boundingBox.maxY) * imageSize.height

        return CGRect(x: x, y: y, width: width, height: height).integral
    }

    private static func elapsedMilliseconds(since startedAt: CFAbsoluteTime) -> Double {
        (CFAbsoluteTimeGetCurrent() - startedAt) * 1000
    }
}

enum FaceDetectionError: Error {
    case unsupportedImage
}
