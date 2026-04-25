import UIKit
import Vision

final class VisionOCRService {
    func recognizeText(in image: UIImage) async throws -> [OCRTextObservation] {
        guard let cgImage = image.cgImage else { return [] }

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
                    // Vision uses normalized coords with origin at bottom-left; convert to image space.
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
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
