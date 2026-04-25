import CoreGraphics
import UIKit
import Vision
#if canImport(ZeticMLange)
import ZeticMLange
#endif
#if canImport(ext)
import ext
#endif

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
        let configuration = MelangeConfiguration.faceDetection
        guard configuration.isConfigured else {
            Logger.app.info("Melange face detection skipped because configuration is missing.")
            return nil
        }

        #if canImport(ZeticMLange) && canImport(ext)
        return try detectWithMelange(
            in: image,
            configuration: configuration,
            startedAt: startedAt
        )
        #else
        Logger.app.info(
            "Melange face detection configured but SDK/wrapper is unavailable in this build. Falling back to Vision."
        )
        return nil
        #endif
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

#if canImport(ZeticMLange) && canImport(ext)
private extension MelangeFaceDetector {
    func detectWithMelange(
        in image: UIImage,
        configuration: MelangeConfiguration,
        startedAt: CFAbsoluteTime
    ) throws -> FaceDetectionReport {
        // ZETIC's face detection tutorial uses `google/MediaPipe-Face-Detection` together with
        // `FaceDetectionWrapper`, which owns model-specific preprocessing/postprocessing.
        // That keeps us from guessing Melange's raw output tensor layout in app code.
        let model = try makeMelangeModel(configuration: configuration)
        let wrapper = FaceDetectionWrapper()
        let inputs = wrapper.preprocess(image)
        var outputs = try model.run(inputs: inputs)
        let postprocessed = wrapper.postprocess(&outputs)

        let faceRegions = Self.makeMelangeRegions(
            from: postprocessed,
            imageSize: image.size
        )

        return FaceDetectionReport(
            regions: faceRegions,
            elapsedMs: Self.elapsedMilliseconds(since: startedAt),
            backend: "melange-face"
        )
    }

    func makeMelangeModel(configuration: MelangeConfiguration) throws -> ZeticMLangeModel {
        if let version = configuration.modelVersion, !version.isEmpty {
            return try ZeticMLangeModel(
                personalKey: configuration.personalKey,
                name: configuration.modelName,
                version: version
            )
        }

        return try ZeticMLangeModel(
            personalKey: configuration.personalKey,
            name: configuration.modelName
        )
    }

    static func makeMelangeRegions(
        from postprocessed: Any,
        imageSize: CGSize
    ) -> [RedactionRegion] {
        let imageBounds = CGRect(origin: .zero, size: imageSize)

        return extractRects(from: postprocessed).compactMap { candidate in
            let rect = candidate.rect.intersection(imageBounds)
            guard !rect.isNull, rect.width > 0, rect.height > 0 else {
                return nil
            }

            return RedactionRegion(
                rect: rect.integral,
                type: .face,
                label: "FACE",
                confidence: candidate.confidence,
                source: "melange-face",
                redactionStyle: .blur
            )
        }
    }

    static func extractRects(from value: Any) -> [(rect: CGRect, confidence: Float)] {
        if let regions = value as? [CGRect] {
            return regions.map { ($0, 1.0) }
        }

        if let dicts = value as? [[String: Any]] {
            return dicts.compactMap(extractRect(from:))
        }

        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .collection {
            return mirror.children.compactMap { child in
                if let rect = child.value as? CGRect {
                    return (rect, 1.0)
                }

                return extractRect(from: child.value)
            }
        }

        return extractRect(from: value).map { [$0] } ?? []
    }

    static func extractRect(from value: Any) -> (rect: CGRect, confidence: Float)? {
        if let rect = value as? CGRect {
            return (rect, 1.0)
        }

        if let dict = value as? [String: Any] {
            if let rect = dict["rect"] as? CGRect {
                return (rect, dict["confidence"] as? Float ?? 1.0)
            }

            if
                let x = number(from: dict["x"]),
                let y = number(from: dict["y"]),
                let width = number(from: dict["width"]),
                let height = number(from: dict["height"])
            {
                let confidence = Float(number(from: dict["confidence"]) ?? 1.0)
                return (CGRect(x: x, y: y, width: width, height: height), confidence)
            }
        }

        let mirror = Mirror(reflecting: value)
        var x: CGFloat?
        var y: CGFloat?
        var width: CGFloat?
        var height: CGFloat?
        var confidence = Float(1.0)

        for child in mirror.children {
            switch child.label {
            case "rect":
                if let rect = child.value as? CGRect {
                    return (rect, confidence)
                }
            case "x", "originX", "left":
                x = number(from: child.value)
            case "y", "originY", "top":
                y = number(from: child.value)
            case "width", "w":
                width = number(from: child.value)
            case "height", "h":
                height = number(from: child.value)
            case "confidence", "score":
                confidence = Float(number(from: child.value) ?? 1.0)
            default:
                continue
            }
        }

        if let x, let y, let width, let height {
            return (CGRect(x: x, y: y, width: width, height: height), confidence)
        }

        return nil
    }

    static func number(from value: Any?) -> CGFloat? {
        switch value {
        case let number as CGFloat:
            return number
        case let number as Double:
            return CGFloat(number)
        case let number as Float:
            return CGFloat(number)
        case let number as Int:
            return CGFloat(number)
        case let number as NSNumber:
            return CGFloat(number.doubleValue)
        default:
            return nil
        }
    }
}
#endif
