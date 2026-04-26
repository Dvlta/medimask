import CoreGraphics
import Foundation
#if canImport(ZeticMLange)
import ZeticMLange
#endif

struct PHIDetectionReport {
    let regions: [RedactionRegion]
    let backend: String
}

final class SensitiveTextRegionDetector {
    private let melangeDetector = MelangeTextAnonymizerService()
    private let fallbackDetector = PHIDetector()

    func detectPHI(in observations: [OCRTextObservation]) async -> PHIDetectionReport {
        if let melangeReport = try? await melangeDetector.detectPHI(in: observations) {
            if melangeReport.backend == "melange-text-anonymizer" {
                return melangeReport
            }

            if melangeReport.backend.hasPrefix("melange-text-anonymizer"),
               melangeReport.backend != "melange-text-anonymizer-blocked",
               melangeReport.backend != "melange-text-anonymizer-unavailable",
               melangeReport.backend != "melange-text-anonymizer-unconfigured",
               melangeReport.backend != "melange-text-anonymizer-missing-tokenizer",
               melangeReport.backend != "melange-text-anonymizer-missing-labels" {
                return melangeReport
            }

            let fallbackRegions = fallbackDetector.detectPHI(in: observations)
            return PHIDetectionReport(
                regions: fallbackRegions,
                backend: "phi-regex-fallback<\(melangeReport.backend)>"
            )
        }

        let fallbackRegions = fallbackDetector.detectPHI(in: observations)
        return PHIDetectionReport(
            regions: fallbackRegions,
            backend: "phi-regex-error-fallback"
        )
    }
}

final class MelangeTextAnonymizerService {
    private let modelMaxLength = 128
    private let tokenizer: MelangeTextTokenizer?
    private let idToLabel: [Int: String]

    init(bundle: Bundle = .main) {
        tokenizer = try? MelangeTextTokenizer(bundle: bundle)
        idToLabel = Self.loadLabels(bundle: bundle)
    }

    func detectPHI(in observations: [OCRTextObservation]) async throws -> PHIDetectionReport {
        let configuration = MelangeConfiguration.textAnonymizer
        guard configuration.isConfigured else {
            Logger.app.info("Melange text anonymizer skipped because configuration is missing.")
            return PHIDetectionReport(regions: [], backend: "melange-text-anonymizer-unconfigured")
        }

        guard let tokenizer else {
            Logger.app.error("Melange text anonymizer tokenizer resource is unavailable.")
            return PHIDetectionReport(regions: [], backend: "melange-text-anonymizer-missing-tokenizer")
        }

        guard !idToLabel.isEmpty else {
            Logger.app.error("Melange text anonymizer label resource is unavailable.")
            return PHIDetectionReport(regions: [], backend: "melange-text-anonymizer-missing-labels")
        }

        #if canImport(ZeticMLange)
        let model = try ZeticMLangeModel(
            personalKey: configuration.personalKey,
            name: configuration.modelName,
            version: configuration.modelVersionNumber,
            onDownload: { progress in
                Logger.app.info("Melange text anonymizer download progress: \(progress, privacy: .public)")
            }
        )

        let chunks = makeChunks(from: observations, tokenizer: tokenizer)
        var detectedRegions: [RedactionRegion] = []

        for chunk in chunks {
            let encodedTokens = tokenizer.encodeDetailed(chunk.text)
            let preparedInput = prepareInput(from: encodedTokens, tokenizer: tokenizer)
            let outputs = try model.run(inputs: [
                preparedInput.inputIds,
                preparedInput.attentionMask
            ])

            guard let logitsTensor = outputs.first else {
                Logger.app.error("Melange text anonymizer returned no output tensor.")
                continue
            }

            let entities = decodeEntities(
                from: logitsTensor,
                encodedTokens: preparedInput.encodedTokens,
                attentionMask: preparedInput.attentionMaskValues
            )
            detectedRegions.append(contentsOf: regions(from: entities, in: chunk))
        }

        return PHIDetectionReport(
            regions: deduplicatedRegions(detectedRegions),
            backend: "melange-text-anonymizer"
        )
        #else
        Logger.app.info("Melange text anonymizer configured but ZeticMLange is unavailable in this build.")
        return PHIDetectionReport(regions: [], backend: "melange-text-anonymizer-unavailable")
        #endif
    }

    private func prepareInput(
        from encodedTokens: [MelangeEncodedToken],
        tokenizer: MelangeTextTokenizer
    ) -> PreparedAnonymizerInput {
        var paddedTokens = encodedTokens
        if paddedTokens.count > modelMaxLength {
            paddedTokens = Array(paddedTokens.prefix(modelMaxLength))
            if let lastToken = paddedTokens.last, lastToken.id != tokenizer.eosId {
                paddedTokens[paddedTokens.count - 1] = MelangeEncodedToken(
                    id: tokenizer.eosId,
                    rawToken: nil,
                    characterRange: nil
                )
            }
        } else if paddedTokens.count < modelMaxLength {
            paddedTokens.append(contentsOf: Array(repeating: MelangeEncodedToken(
                id: tokenizer.padId,
                rawToken: nil,
                characterRange: nil
            ), count: modelMaxLength - paddedTokens.count))
        }

        let inputIds = paddedTokens.map(\.id)
        let attentionMaskValues = paddedTokens.map { token in
            token.id == tokenizer.padId ? 0 : 1
        }

        return PreparedAnonymizerInput(
            encodedTokens: paddedTokens,
            inputIds: createTensor(from: inputIds),
            attentionMask: createTensor(from: attentionMaskValues),
            attentionMaskValues: attentionMaskValues
        )
    }

    private func createTensor(from values: [Int]) -> Tensor {
        let int64Values = values.map(Int64.init)
        let data = int64Values.withUnsafeBufferPointer { Data(buffer: $0) }
        return Tensor(data: data, dataType: BuiltinDataType.int64, shape: [1, modelMaxLength])
    }

    private func decodeEntities(
        from logitsTensor: Tensor,
        encodedTokens: [MelangeEncodedToken],
        attentionMask: [Int]
    ) -> [DetectedEntity] {
        let classCount = idToLabel.count
        guard classCount > 0 else { return [] }

        let floatValues = logitsTensor.data.withUnsafeBytes {
            Array($0.bindMemory(to: Float32.self))
        }

        let sequenceLength = min(floatValues.count / classCount, encodedTokens.count)
        var entities: [DetectedEntity] = []
        var activeEntity: ActiveEntity?

        for tokenIndex in 0..<sequenceLength {
            guard tokenIndex < attentionMask.count, attentionMask[tokenIndex] != 0 else {
                continue
            }

            let token = encodedTokens[tokenIndex]
            guard let tokenRange = token.characterRange else {
                continue
            }

            let offset = tokenIndex * classCount
            let scores = floatValues[offset..<(offset + classCount)]
            guard let best = scores.enumerated().max(by: { $0.element < $1.element }) else {
                continue
            }

            let label = idToLabel[best.offset] ?? "O"
            if label == "O" {
                if let activeEntity {
                    entities.append(activeEntity.finalize())
                }
                activeEntity = nil
                continue
            }

            let entityLabel = normalizedEntityLabel(for: label)
            if label.hasPrefix("B-") || activeEntity?.label != entityLabel {
                if let activeEntity {
                    entities.append(activeEntity.finalize())
                }
                activeEntity = ActiveEntity(
                    label: entityLabel,
                    range: tokenRange,
                    accumulatedScore: best.element,
                    tokenCount: 1
                )
            } else if var current = activeEntity {
                current.range = min(current.range.lowerBound, tokenRange.lowerBound)..<max(current.range.upperBound, tokenRange.upperBound)
                current.accumulatedScore += best.element
                current.tokenCount += 1
                activeEntity = current
            }
        }

        if let activeEntity {
            entities.append(activeEntity.finalize())
        }

        return entities
    }

    private func regions(from entities: [DetectedEntity], in chunk: OCRChunk) -> [RedactionRegion] {
        entities.compactMap { entity in
            let matchingObservations = chunk.observations.filter { observation in
                rangesOverlap(lhs: observation.characterRange, rhs: entity.range)
            }

            guard !matchingObservations.isEmpty else {
                return nil
            }

            let mergedRect = matchingObservations
                .map(\.observation.rect)
                .reduce(CGRect.null) { partial, rect in
                    partial.isNull ? rect : partial.union(rect)
                }

            let boundedRect = mergedRect.insetBy(dx: -8, dy: -6)
            let averageOCRConfidence = matchingObservations.map(\.observation.confidence).reduce(0, +) / Float(matchingObservations.count)

            return RedactionRegion(
                rect: boundedRect,
                type: .phiText,
                label: displayLabel(for: entity.label),
                confidence: max(entity.confidence, averageOCRConfidence),
                source: "melange-text-anonymizer",
                redactionStyle: .blur
            )
        }
    }

    private func makeChunks(
        from observations: [OCRTextObservation],
        tokenizer: MelangeTextTokenizer
    ) -> [OCRChunk] {
        let lines = groupedLines(from: observations)
        var chunks: [OCRChunk] = []
        var currentText = ""
        var currentObservations: [ChunkObservation] = []

        func appendCurrentChunk() {
            let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty, !currentObservations.isEmpty else { return }
            chunks.append(OCRChunk(text: trimmedText, observations: currentObservations))
            currentText = ""
            currentObservations = []
        }

        for line in lines {
            let lineText = line.map(\.text).joined(separator: " ")
            guard !lineText.isEmpty else { continue }

            let candidateText = currentText.isEmpty ? lineText : currentText + "\n" + lineText
            if tokenizer.encodeDetailed(candidateText).count > modelMaxLength, !currentText.isEmpty {
                appendCurrentChunk()
            }

            let lineStart = currentText.isEmpty ? 0 : currentText.count + 1
            if !currentText.isEmpty {
                currentText += "\n"
            }
            currentText += lineText

            var cursor = lineStart
            for (index, observation) in line.enumerated() {
                let start = cursor
                let end = start + observation.text.count
                currentObservations.append(
                    ChunkObservation(
                        observation: observation,
                        characterRange: start..<end
                    )
                )
                cursor = end
                if index < line.count - 1 {
                    cursor += 1
                }
            }
        }

        appendCurrentChunk()
        return chunks
    }

    private func groupedLines(from observations: [OCRTextObservation]) -> [[OCRTextObservation]] {
        let sorted = observations
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                if abs($0.rect.minY - $1.rect.minY) < 14 {
                    return $0.rect.minX < $1.rect.minX
                }
                return $0.rect.minY < $1.rect.minY
            }

        var lines: [[OCRTextObservation]] = []
        for observation in sorted {
            if var lastLine = lines.last,
               let reference = lastLine.first,
               abs(reference.rect.midY - observation.rect.midY) <= max(reference.rect.height, observation.rect.height) * 0.7 {
                lastLine.append(observation)
                lastLine.sort { $0.rect.minX < $1.rect.minX }
                lines[lines.count - 1] = lastLine
            } else {
                lines.append([observation])
            }
        }

        return lines
    }

    private func deduplicatedRegions(_ regions: [RedactionRegion]) -> [RedactionRegion] {
        var deduplicated: [RedactionRegion] = []

        for region in regions.sorted(by: { $0.rect.width * $0.rect.height > $1.rect.width * $1.rect.height }) {
            let overlapsExisting = deduplicated.contains { existing in
                existing.label == region.label && overlapRatio(lhs: existing.rect, rhs: region.rect) > 0.5
            }

            if !overlapsExisting {
                deduplicated.append(region)
            }
        }

        return deduplicated
    }

    private func normalizedEntityLabel(for label: String) -> String {
        if label.hasPrefix("B-") || label.hasPrefix("I-") {
            return String(label.dropFirst(2))
        }
        return label
    }

    private func displayLabel(for entityLabel: String) -> String {
        switch entityLabel {
        case "PERSON":
            return "PERSON NAME"
        case "LOCATION":
            return "LOCATION"
        case "ADDRESS":
            return "ADDRESS"
        case "EMAIL":
            return "EMAIL ADDRESS"
        case "PHONE_NUMBER":
            return "PHONE NUMBER"
        case "DATE":
            return "DATE"
        case "CREDIT_CARD_NUMBER":
            return "CREDIT CARD NUMBER"
        case "SSN":
            return "SOCIAL SECURITY NUMBER"
        default:
            return entityLabel.replacingOccurrences(of: "_", with: " ").uppercased()
        }
    }

    private func rangesOverlap(lhs: Range<Int>, rhs: Range<Int>) -> Bool {
        lhs.overlaps(rhs)
    }

    private func overlapRatio(lhs: CGRect, rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let minArea = min(lhs.width * lhs.height, rhs.width * rhs.height)
        guard minArea > 0 else { return 0 }
        return intersectionArea / minArea
    }

    private static func loadLabels(
        resourceName: String = "ResourcesTextAnonymizer_labels",
        bundle: Bundle = .main
    ) -> [Int: String] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }

        var labels: [Int: String] = [:]
        for (key, value) in json {
            if let integerKey = Int(key) {
                labels[integerKey] = value
            }
        }
        return labels
    }
}

private struct PreparedAnonymizerInput {
    let encodedTokens: [MelangeEncodedToken]
    let inputIds: Tensor
    let attentionMask: Tensor
    let attentionMaskValues: [Int]
}

private struct OCRChunk {
    let text: String
    let observations: [ChunkObservation]
}

private struct ChunkObservation {
    let observation: OCRTextObservation
    let characterRange: Range<Int>
}

private struct ActiveEntity {
    let label: String
    var range: Range<Int>
    var accumulatedScore: Float32
    var tokenCount: Int

    func finalize() -> DetectedEntity {
        let averageScore = accumulatedScore / Float32(max(tokenCount, 1))
        let confidence = Float(max(0.45, min(0.99, (averageScore + 4) / 8)))
        return DetectedEntity(label: label, range: range, confidence: confidence)
    }
}

private struct DetectedEntity {
    let label: String
    let range: Range<Int>
    let confidence: Float
}
