import CoreGraphics
import UIKit
import Vision
#if canImport(ZeticMLange)
import ZeticMLange
#endif

struct FaceDetectionReport {
    let regions: [RedactionRegion]
    let elapsedMs: Double
    let backend: String
}

final class MelangeFaceDetector {
    private let mediaPipeInputSize = 128
    private let mediaPipeScoreThreshold: Float = 0.5
    private let mediaPipeIouThreshold: Float = 0.3

    func detectFaces(in image: UIImage) async throws -> [RedactionRegion] {
        try await detectFacesReport(in: image).regions
    }

    func detectFacesReport(in image: UIImage) async throws -> FaceDetectionReport {
        let startedAt = CFAbsoluteTimeGetCurrent()

        guard image.size.width > 0, image.size.height > 0 else {
            return FaceDetectionReport(regions: [], elapsedMs: 0, backend: "none")
        }

        do {
            let faceRegions = Self.bystanderFaces(from: try detectWithVision(in: image))
            let elapsedMs = Self.elapsedMilliseconds(since: startedAt)

            Logger.app.info("Face detection used default backend: melange-mediapipe-face")

            return FaceDetectionReport(
                regions: faceRegions,
                elapsedMs: elapsedMs,
                backend: "melange-mediapipe-face"
            )
        } catch {
            Logger.app.error("Apple Vision face detection failed; trying Melange fallback. Error: \(error.localizedDescription, privacy: .public)")
        }

        if let melangeReport = try await detectWithMelangeIfAvailable(in: image, startedAt: startedAt) {
            return melangeReport
        }

        return FaceDetectionReport(
            regions: [],
            elapsedMs: Self.elapsedMilliseconds(since: startedAt),
            backend: "face-detection-unavailable"
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

        #if canImport(ZeticMLange)
        let model = try ZeticMLangeModel(
            personalKey: configuration.personalKey,
            name: configuration.modelName,
            version: configuration.modelVersionNumber,
            onDownload: { progress in
                Logger.app.info("Melange face detection download progress: \(progress, privacy: .public)")
            }
        )

        let inputTensor = try makeMediaPipeInputTensor(from: image)
        let outputs = try model.run(inputs: [inputTensor])
        let faceRegions = Self.bystanderFaces(
            from: try decodeMediaPipeFaces(from: outputs, imageSize: image.size)
        )
        let elapsedMs = Self.elapsedMilliseconds(since: startedAt)

        Logger.app.info(
            "Face detection used backend: melange-mediapipe-face; bystander faces: \(faceRegions.count, privacy: .public)"
        )

        return FaceDetectionReport(
            regions: faceRegions,
            elapsedMs: elapsedMs,
            backend: "melange-mediapipe-face"
        )
        #else
        Logger.app.info("Melange face detection configured but ZeticMLange is unavailable in this build. Falling back to Vision.")
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
                source: "melange-mediapipe-face",
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

    private static func bystanderFaces(from faces: [RedactionRegion]) -> [RedactionRegion] {
        guard faces.count > 1,
              let primaryFace = faces.max(by: { faceArea($0) < faceArea($1) }) else {
            return []
        }

        Logger.app.info(
            "Preserving primary face with area \(faceArea(primaryFace), privacy: .public); blurring \(faces.count - 1, privacy: .public) bystander faces."
        )

        return faces.filter { $0.id != primaryFace.id }
    }

    private static func faceArea(_ face: RedactionRegion) -> Double {
        Double(face.rect.width * face.rect.height)
    }

    #if canImport(ZeticMLange)
    private func makeMediaPipeInputTensor(from image: UIImage) throws -> Tensor {
        guard let cgImage = image.cgImage ?? UIGraphicsImageRenderer(size: image.size).image(actions: { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }).cgImage else {
            throw FaceDetectionError.unsupportedImage
        }

        let width = mediaPipeInputSize
        let height = mediaPipeInputSize
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var rgba = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &rgba,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw FaceDetectionError.unsupportedImage
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var floats = [Float32]()
        floats.reserveCapacity(width * height * 3)
        for index in stride(from: 0, to: rgba.count, by: bytesPerPixel) {
            floats.append((Float32(rgba[index]) - 127.5) / 127.5)
            floats.append((Float32(rgba[index + 1]) - 127.5) / 127.5)
            floats.append((Float32(rgba[index + 2]) - 127.5) / 127.5)
        }

        let data = floats.withUnsafeBufferPointer { Data(buffer: $0) }
        return Tensor(data: data, dataType: BuiltinDataType.float32, shape: [1, height, width, 3])
    }

    private func decodeMediaPipeFaces(from outputs: [Tensor], imageSize: CGSize) throws -> [RedactionRegion] {
        let anchors = Self.mediaPipeAnchors()
        guard let boxTensor = outputs.first(where: { $0.count() == anchors.count * 16 }),
              let scoreTensor = outputs.first(where: { $0.count() == anchors.count }) else {
            Logger.app.error("Melange face detection returned unexpected output tensor shapes.")
            return []
        }

        let boxes = floatArray(from: boxTensor)
        let scores = floatArray(from: scoreTensor)

        var candidates: [MediaPipeFaceCandidate] = []
        for index in 0..<anchors.count {
            let score = sigmoid(scores[index])
            guard score >= mediaPipeScoreThreshold else { continue }

            let offset = index * 16
            let anchor = anchors[index]
            let xCenter = boxes[offset] / Float(mediaPipeInputSize) + anchor.xCenter
            let yCenter = boxes[offset + 1] / Float(mediaPipeInputSize) + anchor.yCenter
            let width = boxes[offset + 2] / Float(mediaPipeInputSize)
            let height = boxes[offset + 3] / Float(mediaPipeInputSize)

            let rect = CGRect(
                x: CGFloat(xCenter - width / 2) * imageSize.width,
                y: CGFloat(yCenter - height / 2) * imageSize.height,
                width: CGFloat(width) * imageSize.width,
                height: CGFloat(height) * imageSize.height
            )

            let paddedRect = rect.insetBy(dx: -rect.width * 0.15, dy: -rect.height * 0.18)
            let boundedRect = paddedRect
                .intersection(CGRect(origin: .zero, size: imageSize))
                .integral

            guard !boundedRect.isNull, boundedRect.width > 0, boundedRect.height > 0 else {
                continue
            }

            candidates.append(MediaPipeFaceCandidate(rect: boundedRect, confidence: score))
        }

        return nonMaxSuppressed(candidates)
            .map { candidate in
                RedactionRegion(
                    rect: candidate.rect,
                    type: .face,
                    label: "FACE",
                    confidence: candidate.confidence,
                    source: "melange-mediapipe-face",
                    redactionStyle: .blur
                )
            }
    }

    private func floatArray(from tensor: Tensor) -> [Float32] {
        tensor.data.withUnsafeBytes {
            Array($0.bindMemory(to: Float32.self))
        }
    }

    private func sigmoid(_ value: Float32) -> Float32 {
        if value < -80 { return 0 }
        if value > 80 { return 1 }
        return 1 / (1 + exp(-value))
    }

    private func nonMaxSuppressed(_ candidates: [MediaPipeFaceCandidate]) -> [MediaPipeFaceCandidate] {
        let sorted = candidates.sorted { $0.confidence > $1.confidence }
        var selected: [MediaPipeFaceCandidate] = []

        for candidate in sorted {
            let overlapsSelected = selected.contains { existing in
                iou(candidate.rect, existing.rect) > CGFloat(mediaPipeIouThreshold)
            }
            if !overlapsSelected {
                selected.append(candidate)
            }
        }

        return selected
    }

    private func iou(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }

        let intersectionArea = intersection.width * intersection.height
        let unionArea = lhs.width * lhs.height + rhs.width * rhs.height - intersectionArea
        return unionArea > 0 ? intersectionArea / unionArea : 0
    }

    private static func mediaPipeAnchors() -> [MediaPipeAnchor] {
        let strides = [8, 16, 16, 16]
        let minScale: Float = 0.1484375
        let maxScale: Float = 0.75
        var anchors: [MediaPipeAnchor] = []
        var layerID = 0

        while layerID < strides.count {
            var anchorScales: [Float] = []
            var lastSameStrideLayer = layerID

            while lastSameStrideLayer < strides.count,
                  strides[lastSameStrideLayer] == strides[layerID] {
                let scale = calculateScale(
                    minScale: minScale,
                    maxScale: maxScale,
                    strideIndex: lastSameStrideLayer,
                    strideCount: strides.count
                )
                anchorScales.append(scale)

                let nextScale = lastSameStrideLayer == strides.count - 1
                    ? 1.0
                    : calculateScale(
                        minScale: minScale,
                        maxScale: maxScale,
                        strideIndex: lastSameStrideLayer + 1,
                        strideCount: strides.count
                    )
                anchorScales.append(sqrt(scale * nextScale))
                lastSameStrideLayer += 1
            }

            let featureMapHeight = Int(ceil(Float(128) / Float(strides[layerID])))
            let featureMapWidth = Int(ceil(Float(128) / Float(strides[layerID])))

            for y in 0..<featureMapHeight {
                for x in 0..<featureMapWidth {
                    for _ in anchorScales {
                        anchors.append(
                            MediaPipeAnchor(
                                xCenter: (Float(x) + 0.5) / Float(featureMapWidth),
                                yCenter: (Float(y) + 0.5) / Float(featureMapHeight)
                            )
                        )
                    }
                }
            }

            layerID = lastSameStrideLayer
        }

        return anchors
    }

    private static func calculateScale(
        minScale: Float,
        maxScale: Float,
        strideIndex: Int,
        strideCount: Int
    ) -> Float {
        guard strideCount > 1 else { return (minScale + maxScale) * 0.5 }
        return minScale + (maxScale - minScale) * Float(strideIndex) / Float(strideCount - 1)
    }
    #endif
}

enum FaceDetectionError: Error {
    case unsupportedImage
}

#if canImport(ZeticMLange)
private struct MediaPipeAnchor {
    let xCenter: Float32
    let yCenter: Float32
}

private struct MediaPipeFaceCandidate {
    let rect: CGRect
    let confidence: Float32
}
#endif
