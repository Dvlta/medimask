import UIKit
import Vision

final class VisionOCRService {
    private let requestedLanguages = ["en-US"]
    private let cropUpscaleFactor: CGFloat = 2.0
    private let maxCropCount = 6

    func recognizeText(in image: UIImage, faceRegions: [RedactionRegion] = []) async throws -> [OCRTextObservation] {
        let primaryObservations = try await performRecognition(
            in: image,
            usesLanguageCorrection: true
        )

        let crops = candidateCrops(
            from: primaryObservations,
            faceRegions: faceRegions,
            imageSize: image.size
        )

        guard !crops.isEmpty else {
            return deduplicated(primaryObservations)
        }

        var mergedObservations = primaryObservations
        for crop in crops {
            let cropImage = renderedCropImage(from: image, crop: crop)
            let cropObservations = try await performRecognition(
                in: cropImage.image,
                usesLanguageCorrection: false
            )
            let remapped = cropObservations.map { observation in
                // OCR on crops still maps back into the original image coordinate space.
                let remappedRect = CGRect(
                    x: crop.rect.minX + observation.rect.minX / crop.upscaleFactor,
                    y: crop.rect.minY + observation.rect.minY / crop.upscaleFactor,
                    width: observation.rect.width / crop.upscaleFactor,
                    height: observation.rect.height / crop.upscaleFactor
                )

                return OCRTextObservation(
                    id: observation.id,
                    text: observation.text,
                    rect: remappedRect,
                    confidence: observation.confidence
                )
            }

            mergedObservations = merge(primaryObservations: mergedObservations, additionalObservations: remapped)
        }

        return deduplicated(mergedObservations)
    }

    private func performRecognition(
        in image: UIImage,
        usesLanguageCorrection: Bool
    ) async throws -> [OCRTextObservation] {
        guard let requestHandler = makeImageRequestHandler(for: image) else { return [] }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let width = image.size.width
                let height = image.size.height

                let result: [OCRTextObservation] = observations.compactMap { obs in
                    guard let candidate = obs.topCandidates(1).first else { return nil }
                    let box = obs.boundingBox
                    // Vision reports normalized bottom-left rectangles; convert to top-left image space.
                    let rect = CGRect(
                        x: box.minX * width,
                        y: (1 - box.maxY) * height,
                        width: box.width * width,
                        height: box.height * height
                    )
                    return OCRTextObservation(
                        text: candidate.string,
                        rect: rect,
                        confidence: candidate.confidence
                    )
                }

                continuation.resume(returning: result)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = requestedLanguages
            request.usesLanguageCorrection = usesLanguageCorrection

            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func makeImageRequestHandler(for image: UIImage) -> VNImageRequestHandler? {
        if let cgImage = image.cgImage {
            return VNImageRequestHandler(cgImage: cgImage, options: [:])
        }

        if let ciImage = image.ciImage {
            return VNImageRequestHandler(ciImage: ciImage, options: [:])
        }

        let renderedImage = UIGraphicsImageRenderer(size: image.size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }

        guard let fallbackCGImage = renderedImage.cgImage else {
            return nil
        }

        return VNImageRequestHandler(cgImage: fallbackCGImage, options: [:])
    }

    private func candidateCrops(
        from observations: [OCRTextObservation],
        faceRegions: [RedactionRegion],
        imageSize: CGSize
    ) -> [OCRCrop] {
        let imageBounds = CGRect(origin: .zero, size: imageSize)
        var candidates = clusteredTextCrops(from: observations, imageBounds: imageBounds)
        candidates.append(contentsOf: faceAdjacentBadgeCrops(from: faceRegions, imageBounds: imageBounds))
        candidates.append(contentsOf: heuristicDocumentCrops(imageBounds: imageBounds))

        let merged = mergeOverlappingCrops(candidates, imageBounds: imageBounds)
        return Array(merged.prefix(maxCropCount))
    }

    private func clusteredTextCrops(from observations: [OCRTextObservation], imageBounds: CGRect) -> [OCRCrop] {
        guard !observations.isEmpty else { return [] }

        let sortedObservations = observations.sorted {
            if abs($0.rect.minY - $1.rect.minY) < 18 {
                return $0.rect.minX < $1.rect.minX
            }
            return $0.rect.minY < $1.rect.minY
        }

        var clusterRects: [CGRect] = []
        for observation in sortedObservations {
            let expandedRect = observation.rect.insetBy(dx: -28, dy: -18)

            if let index = clusterRects.firstIndex(where: { $0.insetBy(dx: -18, dy: -16).intersects(expandedRect) }) {
                clusterRects[index] = clusterRects[index].union(expandedRect)
            } else {
                clusterRects.append(expandedRect)
            }
        }

        return clusterRects
            .map { OCRCrop(rect: $0.intersection(imageBounds), upscaleFactor: cropUpscaleFactor, priority: 3) }
            .filter { !$0.rect.isNull && $0.rect.width >= 48 && $0.rect.height >= 20 }
    }

    private func faceAdjacentBadgeCrops(from faceRegions: [RedactionRegion], imageBounds: CGRect) -> [OCRCrop] {
        faceRegions.compactMap { faceRegion in
            guard faceRegion.type == .face else { return nil }

            let width = min(imageBounds.width * 0.74, max(faceRegion.rect.width * 2.8, 220))
            let height = min(imageBounds.height * 0.38, max(faceRegion.rect.height * 2.5, 170))
            let x = max(imageBounds.minX, min(faceRegion.rect.midX - width / 2, imageBounds.maxX - width))
            let y = max(imageBounds.minY, min(faceRegion.rect.maxY + faceRegion.rect.height * 0.12, imageBounds.maxY - height))
            let cropRect = CGRect(x: x, y: y, width: width, height: height)

            guard cropRect.intersects(imageBounds), cropRect.maxY > faceRegion.rect.maxY else {
                return nil
            }

            return OCRCrop(rect: cropRect.intersection(imageBounds), upscaleFactor: cropUpscaleFactor, priority: 2)
        }
    }

    private func heuristicDocumentCrops(imageBounds: CGRect) -> [OCRCrop] {
        let lowerThird = CGRect(
            x: imageBounds.width * 0.08,
            y: imageBounds.height * 0.52,
            width: imageBounds.width * 0.84,
            height: imageBounds.height * 0.36
        )

        let centerBand = CGRect(
            x: imageBounds.width * 0.12,
            y: imageBounds.height * 0.28,
            width: imageBounds.width * 0.76,
            height: imageBounds.height * 0.28
        )

        return [
            OCRCrop(rect: lowerThird.intersection(imageBounds), upscaleFactor: cropUpscaleFactor, priority: 1),
            OCRCrop(rect: centerBand.intersection(imageBounds), upscaleFactor: cropUpscaleFactor, priority: 0)
        ]
    }

    private func mergeOverlappingCrops(_ crops: [OCRCrop], imageBounds: CGRect) -> [OCRCrop] {
        let sorted = crops.sorted {
            if $0.priority == $1.priority {
                return ($0.rect.width * $0.rect.height) > ($1.rect.width * $1.rect.height)
            }
            return $0.priority > $1.priority
        }

        var merged: [OCRCrop] = []
        for crop in sorted {
            guard !crop.rect.isNull else { continue }

            if let index = merged.firstIndex(where: { overlapRatio(lhs: $0.rect, rhs: crop.rect) > 0.45 }) {
                let unionRect = merged[index].rect.union(crop.rect).intersection(imageBounds)
                merged[index] = OCRCrop(
                    rect: unionRect,
                    upscaleFactor: max(merged[index].upscaleFactor, crop.upscaleFactor),
                    priority: max(merged[index].priority, crop.priority)
                )
            } else {
                merged.append(crop)
            }
        }

        return merged
    }

    private func renderedCropImage(from image: UIImage, crop: OCRCrop) -> RenderedCropImage {
        let targetSize = CGSize(
            width: max(1, floor(crop.rect.width * crop.upscaleFactor)),
            height: max(1, floor(crop.rect.height * crop.upscaleFactor))
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderedImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(
                in: CGRect(
                    x: -crop.rect.minX * crop.upscaleFactor,
                    y: -crop.rect.minY * crop.upscaleFactor,
                    width: image.size.width * crop.upscaleFactor,
                    height: image.size.height * crop.upscaleFactor
                )
            )
        }

        return RenderedCropImage(image: renderedImage)
    }

    private func merge(
        primaryObservations: [OCRTextObservation],
        additionalObservations: [OCRTextObservation]
    ) -> [OCRTextObservation] {
        var merged = primaryObservations

        for candidate in additionalObservations {
            if let index = merged.firstIndex(where: { isLikelySameObservation($0, candidate) }) {
                let existing = merged[index]
                let existingScore = existing.confidence + Float(existing.text.count) * 0.01
                let candidateScore = candidate.confidence + Float(candidate.text.count) * 0.01
                if candidateScore > existingScore {
                    merged[index] = candidate
                }
            } else {
                merged.append(candidate)
            }
        }

        return merged
    }

    private func deduplicated(_ observations: [OCRTextObservation]) -> [OCRTextObservation] {
        merge(primaryObservations: [], additionalObservations: observations)
            .sorted {
                if abs($0.rect.minY - $1.rect.minY) < 6 {
                    return $0.rect.minX < $1.rect.minX
                }
                return $0.rect.minY < $1.rect.minY
            }
    }

    private func isLikelySameObservation(_ lhs: OCRTextObservation, _ rhs: OCRTextObservation) -> Bool {
        let overlap = overlapRatio(lhs: lhs.rect, rhs: rhs.rect)
        let leftText = normalizedText(lhs.text)
        let rightText = normalizedText(rhs.text)

        if overlap > 0.68 {
            return true
        }

        if leftText == rightText && overlap > 0.28 {
            return true
        }

        return false
    }

    private func normalizedText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func overlapRatio(lhs: CGRect, rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let minArea = min(lhs.width * lhs.height, rhs.width * rhs.height)
        guard minArea > 0 else { return 0 }
        return intersectionArea / minArea
    }
}

private struct OCRCrop {
    let rect: CGRect
    let upscaleFactor: CGFloat
    let priority: Int
}

private struct RenderedCropImage {
    let image: UIImage
}
